function Get-OrbySpotifyTimeline {
 param($Timeline,$Playback,[datetime]$Now=[datetime]::UtcNow)
 $start=[math]::Max(0,$Timeline.StartTime.TotalSeconds);$end=$Timeline.EndTime.TotalSeconds
 $min=[math]::Max($start,$Timeline.MinSeekTime.TotalSeconds);$max=[math]::Min($end,$Timeline.MaxSeekTime.TotalSeconds)
 $position=$Timeline.Position.TotalSeconds
 $playing=$Playback.PlaybackStatus.ToString() -eq 'Playing'
 if($playing){
  $updated=([datetimeoffset]$Timeline.LastUpdatedTime).UtcDateTime
  $age=($Now-$updated).TotalSeconds
  if($age -ge 0 -and $age -lt 86400){$position+=$age}
 }
 $duration=[math]::Max(0,$end-$start)
 $position=[math]::Max($start,[math]::Min($end,$position))
 return @{Position=$position;Start=$start;Duration=$duration;SeekMin=$min;SeekMax=$max;CanSeek=($Playback.Controls.IsPlaybackPositionEnabled -and $duration -gt 0 -and $max -gt $min)}
}
function Invoke-OrbySpotifyControl {
 param($Manager,$Command)
 if(-not $Manager){throw 'Spotify is not connected'}
 $session=@($Manager.GetSessions() | Where-Object {$_.SourceAppUserModelId -eq $Command.App -and $_.SourceAppUserModelId -match '(?i)spotify'}) | Select-Object -First 1
 if(-not $session){throw 'Spotify session closed. Open Spotify and play a track.'}
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
   $timeline=Get-OrbySpotifyTimeline ($session.GetTimelineProperties()) $info
   if(-not $timeline.CanSeek){throw 'Spotify has not enabled seeking for this track'}
   $seconds=[double]$Command.Value
   if([double]::IsNaN($seconds) -or [double]::IsInfinity($seconds)){throw 'Invalid playback position'}
   $seconds=[math]::Max($timeline.SeekMin,[math]::Min($timeline.SeekMax,$seconds))
   $operation=$session.TryChangePlaybackPositionAsync([long][math]::Round($seconds*10000000))
  }
  default {throw 'Unknown Spotify control'}
 }
 if(-not (Await-WinRt $operation ([bool]))){throw 'Spotify declined this control'}
}
