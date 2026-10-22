function Format-OrbyMusicTime {
 param([double]$Seconds)
 $n=[int][math]::Floor([math]::Max(0.0,$Seconds))
 return ('{0}:{1:00}' -f [int][math]::Floor($n/60),($n%60))
}
function Send-OrbyMusicControl {
 param([string]$Action,$Value=$null,[string]$TrackKey='')
 $m=$script:orbyShared.SelectedMusic
 if(-not $m -or -not $script:orbySettings.Music -or ([datetime]::UtcNow-$m.At).TotalSeconds -gt 8){return}
 if($script:orbySettings.MediaApp -and $script:orbySettings.MediaApp -ne $m.App){return}
 if(-not $TrackKey){$TrackKey=$m.TrackKey}
 $script:orbyShared.MusicResult=''
 $id=[guid]::NewGuid().ToString()
 if($Action -eq 'seek'){
  $value=[math]::Max($m.SeekMin,[math]::Min($m.SeekMax,[double]$Value))
  $script:pendingMusicSeek=[pscustomobject]@{Id=$id;TrackKey=$TrackKey;Position=$value;At=[datetime]::UtcNow}
 }
 $script:orbyShared.MusicCommands.Enqueue([pscustomobject]@{Id=$id;Action=$Action;Value=$Value;App=$m.App;TrackKey=$TrackKey})
}
function New-OrbyMusicPlayer {
 Add-Type -Path (Join-Path $PSScriptRoot 'Output-Volume.cs')
 [xml]$xml=Get-Content (Join-Path $PSScriptRoot 'Music-Player.xaml') -Raw
 $script:musicCard=[Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader $xml))
 $script:musicControls=@{}
 foreach($name in @('MusicClose','MusicCover','PlayerTitle','PlayerArtist','PlayerSeek','PlayerPosition','PlayerDuration','PlayerShuffle','PlayerPrevious','PlayerPlay','PlayerPlayIcon','PlayerNext','PlayerRepeat','PlayerVolumeDown','PlayerVolumeUp','PlayerMute','PlayerNotice')){$script:musicControls[$name]=$script:musicCard.FindName($name)}
 $script:musicPlayIcon=[Windows.Media.Geometry]::Parse('M 0,0 L 14,8 0,16 Z');$script:musicPlayIcon.Freeze()
 $script:musicPauseIcon=[Windows.Media.Geometry]::Parse('M 0,0 L 4,0 4,16 0,16 Z M 9,0 L 13,0 13,16 9,16 Z');$script:musicPauseIcon.Freeze()
 $script:musicPopup=New-Object Windows.Controls.Primitives.Popup
 $script:musicPopup.Child=$script:musicCard;$script:musicPopup.AllowsTransparency=$true;$script:musicPopup.StaysOpen=$false
 $script:musicPopup.Placement='AbsolutePoint'
 $script:musicPopup.Add_Closed({$script:musicDragging=$false;if(Test-Path function:Test-OrbyPointerInside){if(-not (Test-OrbyPointerInside)){Set-OrbitExpanded $false}}})
 $c=$script:musicControls
 $c.MusicClose.Add_Click({$script:musicPopup.IsOpen=$false})
 $c.PlayerPlay.Add_Click({Send-OrbyMusicControl $(if($script:orbyShared.SelectedMusic.Playing){'pause'}else{'play'})})
 $c.PlayerNext.Add_Click({Send-OrbyMusicControl 'next'})
 $c.PlayerPrevious.Add_Click({Send-OrbyMusicControl 'previous'})
 $c.PlayerShuffle.Add_Click({Send-OrbyMusicControl 'shuffle' (-not $script:orbyShared.SelectedMusic.Shuffle)})
 $c.PlayerRepeat.Add_Click({$next=switch($script:orbyShared.SelectedMusic.Repeat){List{'Track'}Track{'None'}default{'List'}};Send-OrbyMusicControl 'repeat' $next})
 $c.PlayerVolumeDown.Add_Click({Adjust-OrbyMusicVolume -Delta -5})
 $c.PlayerVolumeUp.Add_Click({Adjust-OrbyMusicVolume -Delta 5})
 $c.PlayerMute.Add_Click({Adjust-OrbyMusicVolume -Mute})
 $c.PlayerSeek.Add_PreviewMouseLeftButtonDown({$script:musicDragging=$true;$script:musicSeekTrack=$script:orbyShared.SelectedMusic.TrackKey})
 $c.PlayerSeek.AddHandler([Windows.Input.Mouse]::PreviewMouseUpEvent,[Windows.Input.MouseButtonEventHandler]{
  if($script:musicDragging){$script:musicDragging=$false;Send-OrbyMusicControl 'seek' $script:musicControls.PlayerSeek.Value $script:musicSeekTrack}
 },$true)
 $c.PlayerSeek.AddHandler([Windows.Controls.Primitives.Thumb]::DragCompletedEvent,[Windows.Controls.Primitives.DragCompletedEventHandler]{
  param($sender,$e)
  if($script:musicDragging){$script:musicDragging=$false;if(-not $e.Canceled){Send-OrbyMusicControl 'seek' $script:musicControls.PlayerSeek.Value $script:musicSeekTrack}}
 },$true)
 $c.PlayerSeek.Add_PreviewKeyDown({param($sender,$e)if($e.Key -in @('Left','Right','Home','End','PageUp','PageDown')){if(-not $script:musicDragging){$script:musicSeekTrack=$script:orbyShared.SelectedMusic.TrackKey};$script:musicDragging=$true}})
 $c.PlayerSeek.Add_KeyUp({param($sender,$e)if($e.Key -in @('Left','Right','Home','End','PageUp','PageDown')){$script:musicDragging=$false;Send-OrbyMusicControl 'seek' $sender.Value $script:musicSeekTrack}})
 $c.PlayerSeek.Add_LostKeyboardFocus({$script:musicDragging=$false})
}
function Show-OrbyMusicPlayer {
 if(-not $script:musicPopup){New-OrbyMusicPlayer}
 if($script:musicPopup.IsOpen){$script:musicPopup.IsOpen=$false;return}
 Update-OrbyMusicPlayer
 $script:musicPopup.HorizontalOffset=$window.Left+($window.Width-350)/2
 $script:musicPopup.VerticalOffset=$window.Top+$notch.Clip.Bounds.Bottom+6
 $script:musicPopup.PopupAnimation=if($script:orbySettings.ReducedMotion){'None'}else{'Fade'}
 $script:musicPopup.IsOpen=$true
 Invoke-OrbySound 'tap'
}
function Update-OrbyMusicPlayer {
 if(-not $script:musicControls){return}
 $c=$script:musicControls;$m=$script:orbyShared.SelectedMusic
 $fresh=$m -and $script:orbySettings.Music -and (([datetime]::UtcNow-$m.At).TotalSeconds -lt 8)
 if(-not $fresh){
  foreach($name in @('PlayerPrevious','PlayerNext','PlayerPlay','PlayerShuffle','PlayerRepeat','PlayerSeek')){$c[$name].IsEnabled=$false}
  $c.PlayerTitle.Text='Waiting for music';$c.PlayerArtist.Text='Play music in your favourite app';$c.PlayerNotice.Text='Choose a player in Settings';$c.MusicCover.Source=$null;$script:playerArtKey='';$c.PlayerPosition.Text='--:--';$c.PlayerDuration.Text='--:--';return
 }
 $c.PlayerTitle.Text=$m.Title;$c.PlayerTitle.ToolTip=$m.Title;$c.PlayerArtist.Text=$m.Artist
 $c.PlayerPrevious.IsEnabled=$m.CanPrevious;$c.PlayerNext.IsEnabled=$m.CanNext
 $c.PlayerPlay.IsEnabled=if($m.Playing){$m.CanPause}else{$m.CanPlay};$c.PlayerPlayIcon.Data=if($m.Playing){$script:musicPauseIcon}else{$script:musicPlayIcon}
 $c.PlayerShuffle.IsEnabled=$m.CanShuffle;$c.PlayerRepeat.IsEnabled=$m.CanRepeat
 $c.PlayerShuffle.Foreground=if($m.Shuffle){[Windows.Media.Brushes]::MediumSpringGreen}else{[Windows.Media.Brushes]::LightGray}
 $c.PlayerRepeat.Foreground=if($m.Repeat -in @('List','Track')){[Windows.Media.Brushes]::MediumSpringGreen}else{[Windows.Media.Brushes]::LightGray}
 $c.PlayerRepeat.Content=if($m.Repeat -eq 'Track'){'1'}else{[string][char]0x21BB};$c.PlayerRepeat.ToolTip='Repeat: '+$m.Repeat
 if($script:playerArtKey -ne $m.ArtworkKey){$script:playerArtKey=$m.ArtworkKey;try{$c.MusicCover.Source=Convert-OrbyAlbumBitmap $m.ArtworkBytes}catch{$c.MusicCover.Source=$null}}
 $position=Get-OrbySmoothMusicPosition $m
 $c.PlayerSeek.IsEnabled=$m.CanSeek
 if(-not $script:musicDragging){
  $c.PlayerSeek.Minimum=$m.Start;$c.PlayerSeek.Maximum=[math]::Max($m.Start+1,$m.Start+$m.Duration);$c.PlayerSeek.Value=$position
 }
 $c.PlayerPosition.Text=if($m.Duration -gt 0){Format-OrbyMusicTime ($position-$m.Start)}else{'--:--'}
 $c.PlayerDuration.Text=if($m.Duration -gt 0){Format-OrbyMusicTime $m.Duration}else{'--:--'}
 $c.PlayerNotice.Text=if($script:orbyShared.MusicResult){$script:orbyShared.MusicResult}elseif(-not $m.CanSeek){'Seeking is unavailable for this track'}else{''}
}

function Get-OrbySmoothMusicPosition {
 param($Media,[datetime]$Now=[datetime]::UtcNow)
 $position=[double]$Media.Position
 if($Media.Playing){$position+=[math]::Max(0.0,($Now-$Media.At).TotalSeconds)}
 $pending=$script:pendingMusicSeek
 if($pending){
  $age=($Now-$pending.At).TotalSeconds;$reply=$script:orbyShared.MusicControlReply
  $failed=$reply -and $reply.Id -eq $pending.Id -and -not $reply.Ok
  $target=$pending.Position+$(if($Media.Playing){[math]::Max(0.0,$age)}else{0})
  $confirmed=$Media.At -gt $pending.At -and [math]::Abs($position-$target) -lt 1.5
  if($Media.TrackKey -ne $pending.TrackKey -or $failed -or $confirmed -or $age -gt 3){$script:pendingMusicSeek=$null}else{$position=$target}
 }
 return [math]::Max($Media.Start,[math]::Min($Media.Start+$Media.Duration,$position))
}
