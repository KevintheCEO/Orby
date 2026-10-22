param($Shared,[string]$BaseDirectory,[string]$DataDirectory)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Runtime.WindowsRuntime,System.Windows.Forms,UIAutomationClient,UIAutomationTypes,System.Net.Http
function Await-WinRt {
    param($Operation,[type]$Type)
    $method=[System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {$_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'} | Select-Object -First 1
    $task=$method.MakeGenericMethod($Type).Invoke($null,@($Operation))
    if(-not $task.Wait(2500)){throw 'Connection timed out'}
    return $task.Result
}
. (Join-Path $BaseDirectory 'Media-Stream.ps1')
. (Join-Path $BaseDirectory 'Spotify-Control.ps1')
. (Join-Path $BaseDirectory 'Media-Sources.ps1')
$manager=$null;$notificationListener=$null
try {
    [void][Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager,Windows.Media.Control,ContentType=WindowsRuntime]
    $manager=Await-WinRt ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]::RequestAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager])
} catch {$Shared.MediaError='Media connection: '+$_.Exception.GetBaseException().Message}
$artKey='';$artBytes=$null;$artAt=[datetime]::MinValue;$trackAt=[datetime]::MinValue
$previousApp='';$lastManager=[datetime]::MinValue;$lastMedia=[datetime]::MinValue
while(-not $Shared.Stop){
 $now=[datetime]::UtcNow;$settings=$Shared.Settings
    if($settings.Music -and ($now-$lastMedia).TotalSeconds -ge 0.35){
        $lastMedia=$now
        if(-not $manager -and ($now-$lastManager).TotalSeconds -ge 15){
            $lastManager=$now
            try{$manager=Await-WinRt ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]::RequestAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager])}
            catch{$Shared.MediaError='Media connection: '+$_.Exception.GetBaseException().Message}
        }
        try{
            if($manager){
                $sessions=@($manager.GetSessions());$Shared.MediaApps=@($sessions | ForEach-Object {$_.SourceAppUserModelId});$Shared.MediaCheckedAt=$now
                $Shared.MusicSources=@(Get-OrbyMediaSourceList $sessions)
                $preference=[string]$settings.MediaApp
                $selectedSession=Select-OrbyMediaSession $sessions $preference ($manager.GetCurrentSession()) $previousApp
                if($selectedSession){
                    $metadata=Await-WinRt ($selectedSession.TryGetMediaPropertiesAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties])
                    $key=$selectedSession.SourceAppUserModelId+'|'+$metadata.Title+'|'+$metadata.Artist
                    if($key -ne $artKey -or ($now-$artAt).TotalSeconds -ge $(if(($now-$trackAt).TotalSeconds -lt 4){0.7}elseif($artBytes){30}else{1})){
                        if($key -ne $artKey){$trackAt=$now}
                        $artKey=$key;$artAt=$now;$artBytes=$null
                        $stream=$null;$managed=$null;$buffer=$null
                        try{
                            if(-not $metadata.Thumbnail){throw 'Player supplied no cover for this track'}
                            [void][Windows.Storage.Streams.IRandomAccessStreamWithContentType,Windows.Storage.Streams,ContentType=WindowsRuntime]
                            $stream=Await-WinRt ($metadata.Thumbnail.OpenReadAsync()) ([Windows.Storage.Streams.IRandomAccessStreamWithContentType])
                            # Use the .NET stream bridge; do not depend on WinRT Size or DataReader projection.
                            $managed=Open-OrbyThumbnailStream $stream
                            $buffer=New-Object IO.MemoryStream
                            $chunk=New-Object byte[] 16384
                            while($true){
                                $readTask=$managed.ReadAsync($chunk,0,$chunk.Length)
                                if(-not $readTask.Wait(2500)){throw 'Player thumbnail read timed out'}
                                $read=$readTask.Result
                                if($read -eq 0){break}
                                if($buffer.Length+$read -gt 8388608){throw 'Player thumbnail exceeds 8 MB'}
                                $buffer.Write($chunk,0,$read)
                            }
                            if($buffer.Length -eq 0){throw 'Player thumbnail stream was empty'}
                            $artBytes=$buffer.ToArray();$Shared.ArtworkError=''
                        }catch{$Shared.ArtworkError='Album cover: '+$_.Exception.GetBaseException().Message}
                        finally{
                            # Cleanup failures must not discard successfully read metadata/artwork.
                            if($buffer){try{$buffer.Dispose()}catch{}}
                            if($managed){try{$managed.Dispose()}catch{}}
                            elseif($stream){try{$stream.Dispose()}catch{}}
                        }
                    }
                    $snapshot=New-OrbyMediaSnapshot $selectedSession $metadata $artBytes $artAt ([datetime]::UtcNow)
                    if(Test-OrbyMediaSelectionCurrent $Shared $preference){$Shared.SelectedMusic=$snapshot;$Shared.Media=$snapshot;$Shared.MediaError='';$previousApp=$snapshot.App}
                }else{
                    $Shared.SelectedMusic=$null;$Shared.Media=$null;$artKey='';$artBytes=$null;$previousApp=''
                    $Shared.ArtworkError=if($preference){'Waiting for '+(Get-OrbyMediaSourceName $preference)+'. Open the app and play music.'}else{'Open your music app or browser and play a song.'}
                    $Shared.MediaError=$Shared.ArtworkError
                }

            }
        }catch{$Shared.SelectedMusic=$null;$Shared.Media=$null;$Shared.ArtworkError='Media read: '+$_.Exception.GetBaseException().Message;$Shared.MediaError='Could not read this player. Reopen the music app and try again.';$manager=$null}
    }
 if(-not $settings.Music){$Shared.SelectedMusic=$null;$Shared.Media=$null}
 Start-Sleep -Milliseconds 150
}
