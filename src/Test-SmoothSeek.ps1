$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Music-Player.ps1')
$script:orbySettings=@{Music=$true}
$now=[datetime]::UtcNow
$m=[pscustomobject]@{TrackKey='song';Position=20;Start=0;Duration=200;SeekMin=0;SeekMax=200;Playing=$true;At=$now}
$script:orbyShared=@{SelectedMusic=$m;MusicCommands=[Collections.Concurrent.ConcurrentQueue[object]]::new()}
Send-OrbyMusicControl seek 100 'song'
$p=Get-OrbySmoothMusicPosition $m $now.AddMilliseconds(100)
if($p -lt 99 -or $p -gt 101){throw 'Old sample snapped slider back'}
$pending=$script:pendingMusicSeek
$m.Position=100;$m.At=$now.AddMilliseconds(200)
$p=Get-OrbySmoothMusicPosition $m $now.AddMilliseconds(300)
if($script:pendingMusicSeek){throw 'Confirmation not cleared'}
Send-OrbyMusicControl seek 160 'song';$id=$script:pendingMusicSeek.Id
$script:orbyShared.MusicControlReply=[pscustomobject]@{Id=$id;Ok=$false}
$p=Get-OrbySmoothMusicPosition $m
if($script:pendingMusicSeek){throw 'Failure remained optimistic'}
Send-OrbyMusicControl seek 160 'song';$m.TrackKey='other';$p=Get-OrbySmoothMusicPosition $m
if($script:pendingMusicSeek){throw 'Seek crossed track change'}
$m.TrackKey='song';Send-OrbyMusicControl seek 160 'song';$p=Get-OrbySmoothMusicPosition $m ([datetime]::UtcNow.AddSeconds(4))
if($script:pendingMusicSeek){throw 'Pending did not expire'}
'PASS: immediate seek, stale-sample suppression, confirmation, failure, track change, bounded timeout.'
