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
$manager=$null;$notificationListener=$null
try {
    [void][Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager,Windows.Media.Control,ContentType=WindowsRuntime]
    $manager=Await-WinRt ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]::RequestAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager])
} catch {$Shared.MediaError='Media connection: '+$_.Exception.GetBaseException().Message}
$artKey='';$artBytes=$null;$artAt=[datetime]::MinValue;$trackAt=[datetime]::MinValue
$lastManager=[datetime]::MinValue;$lastMedia=[datetime]::MinValue
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
                $session=$null
                if($settings.MediaApp){$session=@($sessions | Where-Object {$_.SourceAppUserModelId -eq $settings.MediaApp}) | Select-Object -First 1}
                if(-not $session){$session=$manager.GetCurrentSession()}
                if($session){
                    $properties=Await-WinRt ($session.TryGetMediaPropertiesAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties])
                    $Shared.Media=[pscustomobject]@{Title=$properties.Title;Artist=$properties.Artist;App=$session.SourceAppUserModelId;Playing=($session.GetPlaybackInfo().PlaybackStatus.ToString() -eq 'Playing');At=$now}
                    $Shared.MediaError=''
                }else{$Shared.Media=$null;$Shared.MediaError='No media session'}
                # Read Spotify separately so another foreground player cannot supply its cover.
                $spotify=@($sessions | Where-Object {$_.SourceAppUserModelId -match '(?i)spotify'} | Sort-Object {if($_.GetPlaybackInfo().PlaybackStatus.ToString() -eq 'Playing'){0}else{1}}) | Select-Object -First 1
                if($spotify){
                    $sp=Await-WinRt ($spotify.TryGetMediaPropertiesAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties])
                    $key=$spotify.SourceAppUserModelId+'|'+$sp.Title+'|'+$sp.Artist
                    if($key -ne $artKey -or ($now-$artAt).TotalSeconds -ge $(if(($now-$trackAt).TotalSeconds -lt 4){0.7}elseif($artBytes){30}else{1})){
                        if($key -ne $artKey){$trackAt=$now}
                        $artKey=$key;$artAt=$now;$artBytes=$null
                        $stream=$null;$managed=$null;$buffer=$null
                        try{
                            if(-not $sp.Thumbnail){throw 'Spotify supplied no thumbnail for this track'}
                            [void][Windows.Storage.Streams.IRandomAccessStreamWithContentType,Windows.Storage.Streams,ContentType=WindowsRuntime]
                            $stream=Await-WinRt ($sp.Thumbnail.OpenReadAsync()) ([Windows.Storage.Streams.IRandomAccessStreamWithContentType])
                            # Use the .NET stream bridge; do not depend on WinRT Size or DataReader projection.
                            $managed=Open-OrbyThumbnailStream $stream
                            $buffer=New-Object IO.MemoryStream
                            $chunk=New-Object byte[] 16384
                            while($true){
                                $readTask=$managed.ReadAsync($chunk,0,$chunk.Length)
                                if(-not $readTask.Wait(2500)){throw 'Spotify thumbnail read timed out'}
                                $read=$readTask.Result
                                if($read -eq 0){break}
                                if($buffer.Length+$read -gt 8388608){throw 'Spotify thumbnail exceeds 8 MB'}
                                $buffer.Write($chunk,0,$read)
                            }
                            if($buffer.Length -eq 0){throw 'Spotify thumbnail stream was empty'}
                            $artBytes=$buffer.ToArray();$Shared.ArtworkError=''
                        }catch{$Shared.ArtworkError='Spotify cover: '+$_.Exception.GetBaseException().Message}
                        finally{
                            # Cleanup failures must not discard successfully read metadata/artwork.
                            if($buffer){try{$buffer.Dispose()}catch{}}
                            if($managed){try{$managed.Dispose()}catch{}}
                            elseif($stream){try{$stream.Dispose()}catch{}}
                        }
                    }
                    $playback=$spotify.GetPlaybackInfo();$controls=$playback.Controls
                    $timeline=@{Position=0;Start=0;Duration=0;SeekMin=0;SeekMax=0;CanSeek=$false}
                    $sampleAt=[datetime]::UtcNow
                    try{$timeline=Get-OrbySpotifyTimeline ($spotify.GetTimelineProperties()) $playback $sampleAt}catch{}
                    $Shared.SpotifyMedia=[pscustomobject]@{
                        Title=$sp.Title;Artist=$sp.Artist;App=$spotify.SourceAppUserModelId;TrackKey=$key
                        ArtworkBytes=$artBytes;ArtworkKey=($key+'|'+$artAt.Ticks);Playing=($playback.PlaybackStatus.ToString() -eq 'Playing');At=$sampleAt
                        Position=$timeline.Position;Start=$timeline.Start;Duration=$timeline.Duration;SeekMin=$timeline.SeekMin;SeekMax=$timeline.SeekMax;CanSeek=$timeline.CanSeek
                        CanPlay=$controls.IsPlayEnabled;CanPause=$controls.IsPauseEnabled;CanNext=$controls.IsNextEnabled;CanPrevious=$controls.IsPreviousEnabled
                        CanShuffle=$controls.IsShuffleEnabled;Shuffle=[bool]$playback.IsShuffleActive;CanRepeat=$controls.IsRepeatEnabled;Repeat=[string]$playback.AutoRepeatMode
                    }
                }else{$Shared.SpotifyMedia=$null;$artKey='';$artBytes=$null;$Shared.ArtworkError='No Spotify media session. Open Spotify and play a song.'}

            }
        }catch{$Shared.SpotifyMedia=$null;$Shared.ArtworkError='Media read: '+$_.Exception.GetBaseException().Message}
    }
 Start-Sleep -Milliseconds 150
}
