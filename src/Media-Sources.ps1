# Shared selection policy for the reader, controls and source picker.
function Get-OrbyMediaSourceName {
 param([string]$App)
 switch -Regex ($App){
  '(?i)spotify' {'Spotify';return}
  '(?i)apple[. _-]?music' {'Apple Music';return}
  '(?i)amazon[. _-]?music' {'Amazon Music';return}
  '(?i)(youtube[. _-]?music|ytmusic)' {'YouTube Music';return}
  '(?i)chrome' {'Chrome · browser media';return}
  '(?i)msedge|microsoftedge' {'Edge · browser media';return}
  '(?i)brave' {'Brave · browser media';return}
  '(?i)firefox' {'Firefox · browser media';return}
  '(?i)opera' {'Opera · browser media';return}
  default {if($App){((($App -split '!')[0] -split '[\\/]') | Select-Object -Last 1) -replace '(?i)\.exe$',''}else{'Music player'}}
 }
}
function Select-OrbyMediaSession {
 param([object[]]$Sessions,[string]$Preferred='',$Current=$null,[string]$PreviousApp='')
 $available=@(foreach($session in $Sessions){
  try{if($session -and $session.SourceAppUserModelId){$info=$session.GetPlaybackInfo();if([string]$info.PlaybackStatus -ne 'Closed'){[pscustomobject]@{Session=$session;App=[string]$session.SourceAppUserModelId;Playing=([string]$info.PlaybackStatus -eq 'Playing')}}}}catch{}
 })
 if($Preferred){
  $available=@($available | Where-Object {$_.App -eq $Preferred})
  # A pinned app never falls back to an unrelated player when it closes.
  if(-not $available.Count){return $null}
 }else{
  $sticky=$available | Where-Object {$_.App -eq $PreviousApp -and $_.Playing} | Select-Object -First 1
  if($sticky){return $sticky.Session}
 }
 $currentPlaying=$available | Where-Object {$_.Playing -and $Current -and $_.Session -eq $Current} | Select-Object -First 1
 if($currentPlaying){return $currentPlaying.Session}
 $playing=$available | Where-Object Playing | Select-Object -First 1
 if($playing){return $playing.Session}
 $previous=$available | Where-Object {$_.App -eq $PreviousApp} | Select-Object -First 1
 if($previous){return $previous.Session}
 $currentItem=$available | Where-Object {$Current -and $_.Session -eq $Current} | Select-Object -First 1
 if($currentItem){return $currentItem.Session}
 if($available.Count){return $available[0].Session}
 return $null
}
function Get-OrbyMediaSourceList {
 param([object[]]$Sessions)
 @($Sessions | Where-Object {$_ -and $_.SourceAppUserModelId} | Group-Object SourceAppUserModelId | ForEach-Object {
  [pscustomobject]@{Id=[string]$_.Name;Name=(Get-OrbyMediaSourceName $_.Name);Count=$_.Count}
 } | Sort-Object Name)
}
function Test-OrbyMediaSelectionCurrent {
 param($Shared,[string]$Preference)
 return $Shared.Settings.Music -and [string]$Shared.Settings.MediaApp -eq $Preference
}
function Test-OrbyMusicCommandCurrent {
 param($Shared,$Command)
 $m=$Shared.SelectedMusic
 return $Shared.Settings.Music -and $m -and $m.App -eq $Command.App -and $m.TrackKey -eq $Command.TrackKey -and (([datetime]::UtcNow-$m.At).TotalSeconds -lt 8) -and (-not $Shared.Settings.MediaApp -or $Shared.Settings.MediaApp -eq $Command.App)
}
function Get-OrbyMusicSourceOptions {
 param([object[]]$Sources,[string]$Preferred='')
 [pscustomobject]@{Id='';Name='Automatic · follow playing app'}
 foreach($source in $Sources){if($source.Id){[pscustomobject]@{Id=$source.Id;Name=$source.Name+$(if($source.Count -gt 1){' · multiple sessions'}else{''})}}}
 if($Preferred -and $Preferred -notin @($Sources | ForEach-Object {$_.Id})){
  [pscustomobject]@{Id=$Preferred;Name=(Get-OrbyMediaSourceName $Preferred)+' · waiting for app'}
 }
}
function New-OrbyMediaSnapshot {
 param($Session,$Properties,[byte[]]$ArtworkBytes,[datetime]$ArtworkAt,[datetime]$Now=[datetime]::UtcNow)
 $playback=$Session.GetPlaybackInfo();$controls=$playback.Controls
 $timeline=@{Position=0;Start=0;Duration=0;SeekMin=0;SeekMax=0;CanSeek=$false}
 try{$timeline=Get-OrbyMediaTimeline ($Session.GetTimelineProperties()) $playback $Now}catch{}
 $key=$Session.SourceAppUserModelId+'|'+$Properties.Title+'|'+$Properties.Artist
 [pscustomobject]@{
  Title=$Properties.Title;Artist=$Properties.Artist;App=$Session.SourceAppUserModelId;Name=(Get-OrbyMediaSourceName $Session.SourceAppUserModelId);TrackKey=$key
  ArtworkBytes=$ArtworkBytes;ArtworkKey=($key+'|'+$ArtworkAt.Ticks);Playing=([string]$playback.PlaybackStatus -eq 'Playing');At=$Now
  Position=$timeline.Position;Start=$timeline.Start;Duration=$timeline.Duration;SeekMin=$timeline.SeekMin;SeekMax=$timeline.SeekMax;CanSeek=$timeline.CanSeek
  CanPlay=$controls.IsPlayEnabled;CanPause=$controls.IsPauseEnabled;CanNext=$controls.IsNextEnabled;CanPrevious=$controls.IsPreviousEnabled
  CanShuffle=$controls.IsShuffleEnabled;Shuffle=[bool]$playback.IsShuffleActive;CanRepeat=$controls.IsRepeatEnabled;Repeat=[string]$playback.AutoRepeatMode
 }
}
