$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Runtime.WindowsRuntime,PresentationFramework
[void][Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager,Windows.Media.Control,ContentType=WindowsRuntime]
. (Join-Path $PSScriptRoot 'Media-Sources.ps1')
. (Join-Path $PSScriptRoot 'Music-Source-UI.ps1')
. (Join-Path $PSScriptRoot 'Spotify-Control.ps1')
. (Join-Path $PSScriptRoot 'Music-Player.ps1')
Add-Type -Path (Join-Path $PSScriptRoot 'Output-Volume.cs')
function Assert($ok,$why){if(-not $ok){throw $why};$script:assertions++}
function Await-WinRt($Operation,[type]$Type){return $Operation}
function New-Session($App,$State='Playing',$Title='Sample song'){
 $s=[pscustomobject]@{SourceAppUserModelId=$App;Info=[pscustomobject]@{PlaybackStatus=$State;IsShuffleActive=$false;AutoRepeatMode='None';Controls=[pscustomobject]@{IsPlayEnabled=$true;IsPauseEnabled=$true;IsNextEnabled=$true;IsPreviousEnabled=$true;IsShuffleEnabled=$false;IsRepeatEnabled=$false;IsPlaybackPositionEnabled=$true}};Metadata=[pscustomobject]@{Title=$Title;Artist='Example artist'};Timeline=[pscustomobject]@{StartTime=[timespan]::Zero;EndTime=[timespan]::FromSeconds(240);MinSeekTime=[timespan]::Zero;MaxSeekTime=[timespan]::FromSeconds(240);Position=[timespan]::FromSeconds(64);LastUpdatedTime=[DateTimeOffset]::UtcNow};Calls=[Collections.Generic.List[string]]::new();SeekTicks=0}
 $s | Add-Member ScriptMethod GetPlaybackInfo {return $this.Info}
 $s | Add-Member ScriptMethod GetTimelineProperties {return $this.Timeline}
 $s | Add-Member ScriptMethod TryGetMediaPropertiesAsync {return $this.Metadata}
 $s | Add-Member ScriptMethod TryPlayAsync {$this.Calls.Add('play');return $true}
 $s | Add-Member ScriptMethod TryPauseAsync {$this.Calls.Add('pause');return $true}
 $s | Add-Member ScriptMethod TrySkipNextAsync {$this.Calls.Add('next');return $true}
 $s | Add-Member ScriptMethod TrySkipPreviousAsync {$this.Calls.Add('previous');return $true}
 $s | Add-Member ScriptMethod TryChangePlaybackPositionAsync {param($ticks)$this.SeekTicks=$ticks;$this.Calls.Add('seek');return $true}
 return $s
}
$spotify=New-Session 'Spotify.exe';$apple=New-Session 'AppleInc.AppleMusic_nzyj5cx40ttqa!App' 'Paused';$amazon=New-Session 'AmazonMusic.exe';$browser=New-Session 'chrome.exe'
$sessions=@($spotify,$apple,$amazon,$browser)
Assert ((Select-OrbyMediaSession $sessions '' $apple '').SourceAppUserModelId -eq 'Spotify.exe') 'Auto failed to find a playing app'
Assert ((Select-OrbyMediaSession $sessions '' $amazon 'Spotify.exe') -eq $spotify) 'Auto unexpectedly jumped away from a playing source'
Assert ((Select-OrbyMediaSession $sessions $apple.SourceAppUserModelId $spotify '').SourceAppUserModelId -eq $apple.SourceAppUserModelId) 'Pinned paused Apple Music was ignored'
Assert ($null -eq (Select-OrbyMediaSession @($spotify) 'AmazonMusic.exe' $spotify '')) 'Missing pinned player fell back to Spotify'
$spotify.Info.PlaybackStatus='Paused'
Assert ((Select-OrbyMediaSession $sessions '' $amazon 'Spotify.exe') -eq $amazon) 'Auto did not follow the next playing app'
Assert ($null -eq (Select-OrbyMediaSession @() '' $null 'Spotify.exe')) 'No sessions produced a phantom player'
$spotify.Info.PlaybackStatus='Playing'
$names=@(Get-OrbyMediaSourceList $sessions)
Assert (@($names | Where-Object Name -eq 'Apple Music').Count -eq 1) 'Apple app ID was not named'
Assert (@($names | Where-Object Name -eq 'Amazon Music').Count -eq 1) 'Amazon app ID was not named'
Assert (@($names | Where-Object Name -eq 'Chrome · browser media').Count -eq 1) 'Browser was falsely branded as a particular service'
$options=@(Get-OrbyMusicSourceOptions $names 'MissingPlayer.exe')
Assert ($options[0].Id -eq '' -and $options[-1].Id -eq 'MissingPlayer.exe') 'Auto or unavailable pinned source choice was lost'
foreach($s in $sessions){
 $m=New-OrbyMediaSnapshot $s $s.Metadata ([byte[]]@(1,2,3)) ([datetime]::UtcNow)
 Assert ($m.App -eq $s.SourceAppUserModelId -and $m.Title -eq 'Sample song' -and $m.Duration -eq 240 -and $m.CanSeek -and $m.CanPause) 'A non-Spotify snapshot lost metadata, timeline or controls'
 Assert ($m.ArtworkBytes.Length -eq 3 -and -not $m.CanShuffle) 'Artwork or control capability did not follow the app'
}
$browser.Timeline.EndTime=[timespan]::Zero;$browser.Timeline.MaxSeekTime=[timespan]::Zero
$m=New-OrbyMediaSnapshot $browser $browser.Metadata $null ([datetime]::UtcNow)
Assert (-not $m.CanSeek -and $m.Duration -eq 0 -and $m.CanPause) 'Missing browser timeline disabled valid playback or invented a seek bar'
$browser.Timeline.EndTime=[timespan]::FromSeconds(240);$browser.Timeline.MaxSeekTime=[timespan]::FromSeconds(240)
$manager=[pscustomobject]@{Sessions=$sessions};$manager | Add-Member ScriptMethod GetSessions {return $this.Sessions}
$key=$apple.SourceAppUserModelId+'|Sample song|Example artist'
foreach($action in @('play','pause','next','previous','seek')){
 Invoke-OrbyMediaControl $manager ([pscustomobject]@{App=$apple.SourceAppUserModelId;TrackKey=$key;Action=$action;Value=120})
}
Assert ($apple.Calls.Count -eq 5 -and $spotify.Calls.Count -eq 0 -and $amazon.Calls.Count -eq 0) 'Controls crossed application boundaries'
Assert ($apple.SeekTicks -eq 1200000000) 'Seeking did not convert seconds to Windows ticks'
$caught=$false;try{Invoke-OrbyMediaControl $manager ([pscustomobject]@{App=$apple.SourceAppUserModelId;TrackKey='old song';Action='next'})}catch{$caught=$true}
Assert ($caught -and $apple.Calls.Count -eq 5) 'A stale queued control affected the new song'
$duplicate=New-Session 'chrome.exe';$manager.Sessions=@($browser,$duplicate)
$caught=$false;try{Invoke-OrbyMediaControl $manager ([pscustomobject]@{App='chrome.exe';TrackKey='chrome.exe|Sample song|Example artist';Action='pause'})}catch{$caught=$true}
Assert ($caught -and $browser.Calls.Count -eq 0 -and $duplicate.Calls.Count -eq 0) 'Ambiguous identical browser tabs were controlled blindly'
$closing=New-Session $apple.SourceAppUserModelId
$closing | Add-Member ScriptMethod TryGetMediaPropertiesAsync {throw 'Session closed'} -Force
$manager.Sessions=@($closing,$apple);$before=$apple.Calls.Count
Invoke-OrbyMediaControl $manager ([pscustomobject]@{App=$apple.SourceAppUserModelId;TrackKey=$key;Action='play'})
Assert ($apple.Calls.Count -eq $before+1) 'A closing sibling session blocked the selected player'
$m=New-OrbyMediaSnapshot $apple $apple.Metadata $null ([datetime]::UtcNow)
$shared=@{Settings=@{Music=$true;MediaApp=''};SelectedMusic=$m};$cmd=@{App=$m.App;TrackKey=$m.TrackKey}
Assert (Test-OrbyMusicCommandCurrent $shared $cmd) 'Current command rejected'
$shared.Settings.MediaApp='Spotify.exe'
Assert (-not (Test-OrbyMusicCommandCurrent $shared $cmd)) 'An old command survived a preference change'
Assert (-not (Test-OrbyMediaSelectionCurrent $shared '')) 'An in-flight reader could publish after preference changed'
foreach($id in @('Spotify.exe','SpotifyAB.SpotifyMusic_zpdnekdrzrea0!Spotify','AppleInc.AppleMusic_nzyj5cx40ttqa!App','AmazonMusic.exe')){Assert ([OrbyOutputVolume]::ProcessForSource($id)) 'Known desktop player has no isolated volume mapping'}
foreach($id in @('chrome.exe','msedge.exe','brave.exe','YouTubeMusic','NotSpotify.exe','https://music.amazon.com','UnknownPlayer')){Assert ($null -eq [OrbyOutputVolume]::ProcessForSource($id)) 'Browser or unknown app could alter another process volume'}
$sc=[OrbyVolumeWorker]::ForSource('Spotify.exe');$ac=[OrbyVolumeWorker]::ForSource($apple.SourceAppUserModelId)
Assert (-not [object]::ReferenceEquals($sc,$ac)) 'Volume channel identity changed with selected app'
Assert ([object]::ReferenceEquals($sc,[OrbyVolumeWorker]::ForSource('SpotifyAB.SpotifyMusic_zpdnekdrzrea0!Spotify'))) 'Same desktop app created competing volume channels'
$unsupported=[OrbyVolumeWorker]::ForSource('chrome.exe');$unsupported.Refresh();$watch=[Diagnostics.Stopwatch]::StartNew();while($unsupported.Busy -and $watch.ElapsedMilliseconds -lt 1000){Start-Sleep -Milliseconds 10}
Assert ($unsupported.Snapshot.Error -like '*own volume*') 'Browser volume failed to explain the safe fallback'
$script:orbySettings=@{MediaApp='';Music=$true};$script:orbyShared=@{SelectedMusic=$m;Media=$m;MusicCommands=[Collections.Concurrent.ConcurrentQueue[object]]::new()}
function Save-OrbySettings {$script:saved=$true}
Set-OrbyPreferredMusicSource 'AmazonMusic.exe'
Assert ($script:saved -and $script:orbySettings.MediaApp -eq 'AmazonMusic.exe' -and $null -eq $script:orbyShared.SelectedMusic) 'Source selection did not save or clear old artwork/media'
$script:orbySettings.MediaApp=$m.App;$m.Playing=$true
$script:orbyShared.SelectedMusic=$m;Send-OrbyMusicControl 'seek' 100 $m.TrackKey
$pending=$script:pendingMusicSeek
$position=Get-OrbySmoothMusicPosition $m $pending.At.AddMilliseconds(125)
Assert ([math]::Abs($position-100.125) -lt .01) 'Timeline interpolation lost sub-second precision'
$script:orbyShared.SelectedMusic=$null;Send-OrbyMusicControl 'next'
Assert ($script:orbyShared.MusicCommands.Count -eq 1) 'A disconnected player still accepted commands'
[xml]$settingsXaml=Get-Content (Join-Path $PSScriptRoot 'Settings.xaml') -Raw
$settingsView=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($settingsXaml))
$picker=$settingsView.FindName('MediaApp');$picker.ItemsSource=@(Get-OrbyMusicSourceOptions $names 'AmazonMusic.exe');$picker.SelectedValue='AmazonMusic.exe'
Assert ($picker -is [Windows.Controls.ComboBox] -and $picker.SelectedValue -eq 'AmazonMusic.exe' -and $picker.SelectedItem.Name -eq 'Amazon Music') 'Full settings lost the friendly app picker or saved ID'
"PASS: $script:assertions multi-music assertions; selection, generic metadata/art/timeline, app/track isolation, browser ambiguity, safe volume channels, persistence and smooth seeking"
