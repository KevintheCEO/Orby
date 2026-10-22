function Get-OrbyMediaTimeline {
 param($Timeline,$Playback,[datetime]$Now=[datetime]::UtcNow)
 $start=[math]::Max(0.0,$Timeline.StartTime.TotalSeconds);$end=$Timeline.EndTime.TotalSeconds
 $min=[math]::Max($start,$Timeline.MinSeekTime.TotalSeconds);$max=[math]::Min($end,$Timeline.MaxSeekTime.TotalSeconds)
 $position=$Timeline.Position.TotalSeconds
 $playing=$Playback.PlaybackStatus.ToString() -eq 'Playing'
 if($playing){
  $updated=([datetimeoffset]$Timeline.LastUpdatedTime).UtcDateTime
  $age=($Now-$updated).TotalSeconds
  if($age -ge 0 -and $age -lt 86400){$position+=$age}
 }
 $duration=[math]::Max(0.0,$end-$start)
 $position=[math]::Max($start,[math]::Min($end,$position))
 return @{Position=$position;Start=$start;Duration=$duration;SeekMin=$min;SeekMax=$max;CanSeek=($Playback.Controls.IsPlaybackPositionEnabled -and $duration -gt 0 -and $max -gt $min)}
}
function Invoke-OrbyMediaControl {
 param($Manager,$Command,$Shared=$null)
 if(-not $Manager){throw 'Music player is not connected'}
 if(-not $Command.App -or -not $Command.TrackKey){throw 'Playback target is missing'}
 $matches=@(foreach($candidate in $Manager.GetSessions()){
  if($candidate.SourceAppUserModelId -ne $Command.App){continue}
  try{
   $metadata=Await-WinRt ($candidate.TryGetMediaPropertiesAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties])
   $key=$candidate.SourceAppUserModelId+'|'+$metadata.Title+'|'+$metadata.Artist
   if($key -eq $Command.TrackKey){$candidate}
  }catch{continue} # A closing sibling browser tab must not poison the live target.
 })
 if($matches.Count -eq 0){throw 'Track or player changed. Try the control again.'}
 if($matches.Count -gt 1){throw 'Multiple identical browser sessions. Pause or close the other player first.'}
 $session=$matches[0]
 if($Shared -and -not (Test-OrbyMusicCommandCurrent $Shared $Command)){throw 'Music app or track changed. Try again.'}
 $info=$session.GetPlaybackInfo();$controls=$info.Controls;$operation=$null
 switch($Command.Action){
  play {if(-not $controls.IsPlayEnabled){throw 'Play is unavailable'};$operation=$session.TryPlayAsync()}
  pause {if(-not $controls.IsPauseEnabled){throw 'Pause is unavailable'};$operation=$session.TryPauseAsync()}
  next {if(-not $controls.IsNextEnabled){throw 'Next track is unavailable'};$operation=$session.TrySkipNextAsync()}
  previous {if(-not $controls.IsPreviousEnabled){throw 'Previous track is unavailable'};$operation=$session.TrySkipPreviousAsync()}
  shuffle {if(-not $controls.IsShuffleEnabled){throw 'Shuffle is unavailable'};$operation=$session.TryChangeShuffleActiveAsync([bool]$Command.Value)}
  repeat {
   if(-not $controls.IsRepeatEnabled){throw 'Repeat is unavailable'}
   if($Command.Value -notin @('None','List','Track')){throw 'Invalid repeat mode'}
   [void][Windows.Media.MediaPlaybackAutoRepeatMode,Windows.Media,ContentType=WindowsRuntime]
   $mode=[Enum]::Parse([Windows.Media.MediaPlaybackAutoRepeatMode],$Command.Value)
   $operation=$session.TryChangeAutoRepeatModeAsync($mode)
  }
  seek {
   $metadata=Await-WinRt ($session.TryGetMediaPropertiesAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties])
   $key=$session.SourceAppUserModelId+'|'+$metadata.Title+'|'+$metadata.Artist
   if($key -ne $Command.TrackKey){throw 'Song changed. Try seeking on the new track.'}
   $timeline=Get-OrbyMediaTimeline ($session.GetTimelineProperties()) $info
   if(-not $timeline.CanSeek){throw 'This player has not enabled seeking for this track'}
   $seconds=[double]$Command.Value
   if([double]::IsNaN($seconds) -or [double]::IsInfinity($seconds)){throw 'Invalid playback position'}
   $seconds=[math]::Max($timeline.SeekMin,[math]::Min($timeline.SeekMax,$seconds))
   $operation=$session.TryChangePlaybackPositionAsync([long][math]::Round($seconds*10000000))
  }
  default {throw 'Unknown music control'}
 }
 if(-not (Await-WinRt $operation ([bool]))){throw 'The player declined this control'}
}
