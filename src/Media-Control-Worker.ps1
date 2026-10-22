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
while(-not $Shared.Stop){
 $batch=New-Object 'System.Collections.Generic.List[object]';$item=$null
 while($Shared.MusicCommands.TryDequeue([ref]$item)){
  if($batch.Count -gt 0 -and $item.Action -eq 'seek' -and $batch[$batch.Count-1].Action -eq 'seek' -and $item.TrackKey -eq $batch[$batch.Count-1].TrackKey){$batch[$batch.Count-1]=$item}else{$batch.Add($item)}
 }
 foreach($command in $batch){
  try{
   if(-not $Shared.Settings.Music){throw 'Music connection is off'}
   if(-not $manager){$manager=Await-WinRt ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]::RequestAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager])}
   if(-not (Test-OrbyMusicCommandCurrent $Shared $command)){throw 'Music app or track changed. Try again.'}
   Invoke-OrbyMediaControl $manager $command $Shared
   $Shared.MusicControlReply=[pscustomobject]@{Id=$command.Id;Ok=$true;At=[datetime]::UtcNow}
   if(Test-OrbyMusicCommandCurrent $Shared $command){$Shared.MusicResult=''}
  }catch{if(Test-OrbyMusicCommandCurrent $Shared $command){$Shared.MusicResult=$_.Exception.GetBaseException().Message};$Shared.MusicControlReply=[pscustomobject]@{Id=$command.Id;Ok=$false;At=[datetime]::UtcNow}}
 }
 Start-Sleep -Milliseconds 20
}
