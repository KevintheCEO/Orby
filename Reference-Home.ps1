function New-OrbyHome {
 [xml]$xml=Get-Content (Join-Path $PSScriptRoot 'Reference-Home.xaml') -Raw
 $script:referenceHome=[Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader $xml))
 $script:referenceControls=@{}
 foreach($name in @('RefHome','RefMusic','RefTools','RefSettings','RefAnimations','RefHealth','RefHomePage','RefMusicPage','RefOrbHost','RefTitle','RefAction','RefDetail','RefConnection','RefPillText0','RefPillText1','RefPillText2','RefPillText3','RefMusicCover','RefMusicTitle','RefMusicArtist','RefMusicNotice','RefMusicSeek','RefMusicPosition','RefMusicDuration','RefMusicShuffle','RefMusicPrevious','RefMusicPlay','RefMusicNext','RefMusicRepeat')){$script:referenceControls[$name]=$script:referenceHome.FindName($name)}
 $script:referenceOrb=New-OrbitAvatar
 $script:referenceControls.RefOrbHost.Child=$script:referenceOrb.Root
 Update-OrbitAvatar $script:referenceOrb 'idle' 0
 $script:referenceControls.RefMusic.Add_Click({Set-OrbyHomePage 'music'})
 $script:referenceControls.RefTools.Add_Click({Show-OrbyTools})
 $script:referenceControls.RefAnimations.Add_Click({Show-OrbyAnimations})
 $script:referenceControls.RefSettings.Add_Click({Show-OrbySettings})
 $script:referenceControls.RefHome.Add_Click({Set-OrbyHomePage 'home'})
 Initialize-OrbyMusicTab
 return $script:referenceHome
}
function Set-OrbyHomePage {
 param([string]$Page='home')
 if(-not $script:referenceControls){return}
 $isMusic=$Page -eq 'music'
 $script:referenceControls.RefHomePage.Visibility=if($isMusic){'Collapsed'}else{'Visible'}
 $script:referenceControls.RefMusicPage.Visibility=if($isMusic){'Visible'}else{'Collapsed'}
 if($isMusic){Update-OrbyMusicTab}
}
function Initialize-OrbyMusicTab {
 $c=$script:referenceControls
 if(-not $c.RefMusicSeek){return}
 $c.RefMusicPlay.Add_Click({$m=$script:orbyShared.SpotifyMedia;if($m){Send-OrbyMusicControl $(if($m.Playing){'pause'}else{'play'})}})
 $c.RefMusicNext.Add_Click({Send-OrbyMusicControl 'next'})
 $c.RefMusicPrevious.Add_Click({Send-OrbyMusicControl 'previous'})
 $c.RefMusicShuffle.Add_Click({$m=$script:orbyShared.SpotifyMedia;if($m){Send-OrbyMusicControl 'shuffle' (-not [bool]$m.Shuffle)}})
 $c.RefMusicRepeat.Add_Click({$m=$script:orbyShared.SpotifyMedia;if($m){$next=switch($m.Repeat){List{'Track'}Track{'None'}default{'List'}};Send-OrbyMusicControl 'repeat' $next}})
 $c.RefMusicSeek.Add_PreviewMouseLeftButtonDown({$script:referenceMusicDragging=$true;$script:referenceMusicTrack=$script:orbyShared.SpotifyMedia.TrackKey})
 $c.RefMusicSeek.Add_PreviewMouseLeftButtonUp({if($script:referenceMusicDragging){$script:referenceMusicDragging=$false;Send-OrbyMusicControl 'seek' $script:referenceControls.RefMusicSeek.Value $script:referenceMusicTrack}})
}
function Update-OrbyMusicTab {
 $c=$script:referenceControls;if(-not $c.RefMusicPage -or $c.RefMusicPage.Visibility -ne 'Visible'){return}
 $m=$script:orbyShared.SpotifyMedia;$fresh=$m -and $script:orbySettings.Music -and (([datetime]::UtcNow-$m.At).TotalSeconds -lt 8)
 if(-not $fresh){$c.RefMusicTitle.Text='Spotify not connected';$c.RefMusicArtist.Text='Play a song in Spotify';$c.RefMusicNotice.Text='Waiting for Spotify playback';$c.RefMusicCover.Source=$null;$c.RefMusicPosition.Text='--:--';$c.RefMusicDuration.Text='--:--';foreach($n in @('RefMusicShuffle','RefMusicPrevious','RefMusicPlay','RefMusicNext','RefMusicRepeat','RefMusicSeek')){$c[$n].IsEnabled=$false};return}
 $c.RefMusicTitle.Text=$m.Title;$c.RefMusicArtist.Text=$m.Artist;$c.RefMusicNotice.Text=if($script:orbyShared.SpotifyResult){$script:orbyShared.SpotifyResult}elseif(-not $m.CanSeek){'Seeking unavailable for this track'}else{'Spotify playback'}
 if($script:referenceMusicArtKey -ne $m.ArtworkKey){$script:referenceMusicArtKey=$m.ArtworkKey;try{$c.RefMusicCover.Source=Convert-OrbyAlbumBitmap $m.ArtworkBytes}catch{$c.RefMusicCover.Source=$null}}
 $c.RefMusicPrevious.IsEnabled=$m.CanPrevious;$c.RefMusicNext.IsEnabled=$m.CanNext;$c.RefMusicPlay.IsEnabled=if($m.Playing){$m.CanPause}else{$m.CanPlay};$c.RefMusicPlay.Content=if($m.Playing){[string][char]0x23F8}else{[string][char]0x25B6};$c.RefMusicShuffle.IsEnabled=$m.CanShuffle;$c.RefMusicRepeat.IsEnabled=$m.CanRepeat;$c.RefMusicSeek.IsEnabled=$m.CanSeek
 $position=[double]$m.Position;if($m.Playing){$position+=[math]::Max(0,([datetime]::UtcNow-$m.At).TotalSeconds)};$position=[math]::Min($m.Start+$m.Duration,$position);if(-not $script:referenceMusicDragging){$c.RefMusicSeek.Minimum=$m.Start;$c.RefMusicSeek.Maximum=[math]::Max($m.Start+1,$m.Start+$m.Duration);$c.RefMusicSeek.Value=$position};$c.RefMusicPosition.Text=Format-OrbyMusicTime ($position-$m.Start);$c.RefMusicDuration.Text=if($m.Duration -gt 0){Format-OrbyMusicTime $m.Duration}else{'--:--'}
}
function Show-OrbyTools {
 if(-not $script:toolsWindow){
  $script:toolsWindow=New-Object Windows.Window
  $script:toolsWindow.Title='Orby controls';$script:toolsWindow.Width=640;$script:toolsWindow.Height=410
  $script:toolsWindow.Background=[Windows.Media.BrushConverter]::new().ConvertFromString('#0E0F11')
  $script:toolsWindow.WindowStartupLocation='CenterScreen';$script:toolsWindow.Content=$script:desktopPanel
  $script:toolsWindow.Add_Closing({param($sender,$args)if(-not $script:orbyShared.Stop){$args.Cancel=$true;$sender.Hide()}})
 }
 Update-OrbyPanel;$script:toolsWindow.Show();[void]$script:toolsWindow.Activate()
}
function Update-OrbyHome {
 $c=$script:referenceControls;if(-not $c){return}
 $c.RefTitle.Text=if($script:chatLogState -in @('working','attention','success','error','stopped')){Get-NotchTaskTitle 'ChatGPT task'}else{'No active task'}
 $c.RefAction.Text=if($script:chatLogMessage){$script:chatLogMessage}else{'Waiting for a task'}
 $c.RefDetail.Text=if($script:chatLogState -eq 'working'){'Working locally'}elseif($script:chatLogState -eq 'attention'){'Needs your input'}else{'Ready when you are'}
 $health=$script:orbyShared.Health
 $c.RefHealth.Text=if($health){$(if($health.Network){'Online'}else{'Offline'})+'   '+$(if($null -ne $health.Battery){[string]$health.Battery+'% battery'}else{'AC power'})}else{'Local connections'}
 $fallback=@('ChatGPT idle',(@($script:orbyAlerts | Where-Object {-not $_.Read}).Count.ToString()+' alerts'),$(if($script:orbyFocusEnd -gt [datetime]::UtcNow){'Focus running'}else{'Focus off'}),'Files ready')
 $tasks=@($script:orbyActiveTasks)
 for($i=0;$i -lt 4;$i++){
  $c['RefPillText'+$i].Text=if($i -lt $tasks.Count -and $tasks[$i]){$tasks[$i].Title}else{$fallback[$i]}
  $c['RefPillText'+$i].ToolTip=if($i -lt $tasks.Count -and $tasks[$i]){$tasks[$i].Title+' - '+$tasks[$i].Action}else{$fallback[$i]}
 }
 $c.RefConnection.Text=if($script:petFeedAvailable){'ChatGPT connected | '+$tasks.Count+' active task(s)'}else{'Waiting for local ChatGPT activity'}
 Update-OrbyMusicTab
}
