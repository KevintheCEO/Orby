param([switch]$NoNetwork,[string]$PersonalDirectory='',[string]$HomeDataDirectory='')
# Home is an overview. The existing AI chooser retains the full task/usage view.
$script:dashboardRoute='home';$script:homeNoNetwork=[bool]$NoNetwork
$script:homeDataDirectory=if($HomeDataDirectory){$HomeDataDirectory}elseif($logDir){$logDir}else{Join-Path $env:LOCALAPPDATA 'Orby'}
[void][IO.Directory]::CreateDirectory($script:homeDataDirectory)
$script:homeProviderTiles=@{}
[xml]$homeXml=Get-Content (Join-Path $PSScriptRoot 'Home-Dashboard.xaml') -Raw
$script:homeDashboard=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($homeXml));$script:homeControls=@{}
foreach($m in [regex]::Matches($homeXml.OuterXml,'x:Name="([^"]+)"')){$key=$m.Groups[1].Value;$script:homeControls[$key]=$script:homeDashboard.FindName($key)}
[void]$script:multiHome.Children.Add($script:homeDashboard)

function New-OrbyHomeText([string]$Text,[double]$Size=12,[string]$Color='#EFF0F3'){$t=[Windows.Controls.TextBlock]::new();$t.Text=$Text;$t.FontFamily='Segoe UI';$t.FontSize=$Size;$t.Foreground=[Windows.Media.BrushConverter]::new().ConvertFromString($Color);$t.TextTrimming='CharacterEllipsis';return $t}
function Test-OrbyHomeVisible {return $script:expanded -and $script:dashboardRoute -eq 'home' -and $script:compactMenuPage -eq 'home' -and -not $script:fullscreenHidden -and -not $script:orbyEventMode -and -not ($script:dropPanel -and $script:dropPanel.Visibility -eq 'Visible')}
function Update-OrbyHomeOverview {
 if(-not $script:homeDashboard){return};$visible=Test-OrbyHomeVisible;$total=0;$active=0
 foreach($id in @('chatgpt','claude','gemini')){
  if(-not $script:homeProviderTiles[$id]){$script:homeProviderTiles[$id]=New-OrbyHomeProviderTile $id}
  $tile=$script:homeProviderTiles[$id];$status=$script:multiProviderStatuses | Where-Object {$_.Id -eq $id} | Select-Object -First 1
  $tasks=@(if($status){Get-OrbyProviderTasks $id $status});$show=$status -and ($tasks.Count -gt 0 -or $status.State -eq 'error')
  $tile.Host.Visibility=if($show){'Visible'}else{'Collapsed'};$tile.Renderer.Suspended=-not ($visible -and $show);$tile.Renderer.ReducedMotion=[bool]$script:orbySettings.ReducedMotion;$tile.Renderer.EyeEffects=$false;$tile.Renderer.ShowStatusDot=$true;$tile.Renderer.StatusConnected=[bool]$show
  $tile.Separator.Visibility=if($show -and $active -gt 0){'Visible'}else{'Collapsed'};if($show){$active++;$total+=$tasks.Count;$tile.Count.Text=if($tasks.Count){[string]$tasks.Count+' task'+$(if($tasks.Count -ne 1){'s'})}else{'Needs attention'};$tile.Detail.Text=if($tasks.Count){$tasks[0].Action}else{$status.Detail};$tile.Host.ToolTip=(@($tasks | ForEach-Object {$_.Title+' · '+$_.Action}) -join "`n");$tile.Renderer.SetState($(if($tasks.Count){$tasks[0].State}else{'error'}),$tile.Detail.Text);Set-OrbyProviderAccent $tile.Parts $id $false ($visible -and -not $script:orbySettings.ReducedMotion)}
  for($i=0;$i -lt $tile.Buddies.Count;$i++){$buddy=$tile.Buddies[$i];$task=if($tasks.Count -gt ($i+1)){$tasks[$i+1]}else{$null};$buddy.Host.Visibility=if($task){'Visible'}else{'Collapsed'};$buddy.Renderer.Suspended=-not ($visible -and $show -and $task);$buddy.Renderer.ShowStatusDot=[bool]$task;$buddy.Renderer.StatusConnected=[bool]$task;$buddy.Renderer.ReducedMotion=[bool]$script:orbySettings.ReducedMotion;if($task){$buddy.Renderer.SetState($task.State,$task.Action)}}
 }
 $script:homeControls.ActiveProviders.Columns=[math]::Max(1,$active);$script:homeControls.NoActive.Visibility=if($active){'Collapsed'}else{'Visible'};$script:homeControls.ActiveTotal.Text=if($active){[string]$active+' provider'+$(if($active -ne 1){'s'})+' · '+$total+' active task'+$(if($total -ne 1){'s'})}else{'All quiet'}
 $script:homeControls.HomeIdleAI.Visibility=if($active){'Collapsed'}else{'Visible'};$script:homeControls.HomeActiveAI.Visibility=if($active){'Visible'}else{'Collapsed'}
 $script:homeControls.HomeAIRow.Height=[Windows.GridLength]::new($(if($active){76}else{58}))
 $script:homeIdleRenderer.Suspended=-not ($visible -and -not $active);$script:homeIdleRenderer.ReducedMotion=[bool]$script:orbySettings.ReducedMotion
 $coverSize=if($active){104}else{124}
 if($script:homeCoverSize -ne $coverSize){$script:homeCoverSize=$coverSize;$script:homeControls.HomeCoverFrame.Width=$coverSize;$script:homeControls.HomeCoverFrame.Height=$coverSize;$script:homeControls.HomeCoverColumn.Width=[Windows.GridLength]::new($coverSize+20);$script:homeControls.HomeMusicCover.Clip=[Windows.Media.RectangleGeometry]::new([Windows.Rect]::new(0,0,$coverSize-2,$coverSize-2),8,8)}
 Update-OrbyHomeMusic
 if(Test-Path function:Update-OrbyPersonalHome){Update-OrbyPersonalHome $visible}
}
function Update-OrbyHomeMusic {
 $u=$script:homeControls;$m=$script:orbyShared.SelectedMusic;$fresh=$m -and $script:orbySettings.Music -and ([datetime]::UtcNow-$m.At).TotalSeconds -lt 8
 $u.HomeMusicTitle.Text=if($fresh){$m.Title}else{'Nothing playing'};$u.HomeMusicTitle.ToolTip=if($fresh){$m.Title+' · '+$m.Artist}else{'Nothing playing'};$u.HomeMusicArtist.Text=if($fresh){$m.Artist}else{'Play music in your favorite app'};$u.MusicSource.Text=if($fresh){if($m.Name){$m.Name}else{$m.App}}else{'Your current player'}
 $key=if($fresh){[string]$m.ArtworkKey}else{''}
 if($key -ne $script:homeArtworkKey){$script:homeArtworkKey=$key;$u.HomeMusicCover.Source=$null;if($fresh -and $m.ArtworkBytes){try{$u.HomeMusicCover.Source=Convert-OrbyAlbumBitmap $m.ArtworkBytes}catch{}}}
 $u.MusicPlaceholder.Visibility=if($u.HomeMusicCover.Source){'Collapsed'}else{'Visible'}
 $script:compactMenuControls.MusicNavCover.Source=$u.HomeMusicCover.Source;if($script:musicNavButton){$script:musicNavButton.Visibility=if($u.HomeMusicCover.Source){'Visible'}else{'Collapsed'}}
 $duration=if($fresh){[double]$m.Duration}else{0};$start=if($fresh){[double]$m.Start}else{0};$position=if($fresh){Get-OrbySmoothMusicPosition $m}else{0}
 if(-not $script:homeMusicDragging){$u.HomeMusicSeek.Minimum=$start;$u.HomeMusicSeek.Maximum=[math]::Max($start+1,$start+$duration);$u.HomeMusicSeek.Value=[math]::Max($start,[math]::Min([double]$position,$u.HomeMusicSeek.Maximum))}
 $u.HomeMusicSeek.IsEnabled=$fresh -and $m.CanSeek -and $duration -gt 0
 $u.HomeMusicPosition.Text=if($fresh -and $duration -gt 0){Format-OrbyMusicTime ($position-$start)}else{'—:—'};$u.HomeMusicDuration.Text=if($fresh -and $duration -gt 0){Format-OrbyMusicTime $duration}else{'—:—'}
 $u.HomePrevious.IsEnabled=$fresh -and $m.CanPrevious;$u.HomeNext.IsEnabled=$fresh -and $m.CanNext;$u.HomePlay.IsEnabled=$fresh -and $(if($m.Playing){$m.CanPause}else{$m.CanPlay});$u.HomePlayGlyph.Data=[Windows.Media.Geometry]::Parse($(if($fresh -and $m.Playing){'M1,0 H6 V20 H1 Z M12,0 H17 V20 H12 Z'}else{'M2,0 L17,10 L2,20 Z'}))
 if($script:homeSourceLogoKey -ne $u.MusicSource.Text){$script:homeSourceLogoKey=$u.MusicSource.Text;$u.HomeSourceLogo.Content=New-OrbyHomeSourceLogo $u.MusicSource.Text}
}
function Complete-OrbyHomeSeek {if($script:homeMusicDragging){$script:homeMusicDragging=$false;Send-OrbyMusicControl 'seek' $script:homeControls.HomeMusicSeek.Value $script:homeSeekTrack;Update-OrbyHomeMusic}}
function Get-OrbyHomeDimensions {return @(596,344)}
function Update-OrbyDashboardLayout {
 if(-not $script:homeDashboard){return};$isDashboard=$script:dashboardRoute -eq 'home';$script:homeDashboard.Visibility=if($isDashboard){'Visible'}else{'Collapsed'};$script:sharedCompanionView.Visibility=if($isDashboard){'Collapsed'}else{'Visible'}
 $script:referenceControls.RefHome.Tag=if($isDashboard -and $script:compactMenuPage -eq 'home'){'Selected'}else{$null};$script:aiCompanionButton.Tag=if(-not $isDashboard -and $script:compactMenuPage -eq 'home'){'Selected'}else{$null}
 if($isDashboard -and $script:compactMenuPage -eq 'home' -and -not $script:orbyEventMode -and -not ($script:dropPanel -and $script:dropPanel.Visibility -eq 'Visible')){
  $size=Get-OrbyHomeDimensions;$targetWidth=$size[0]+24;$targetHeight=$size[1]+14
  if($notch.Width -lt $targetWidth){$notch.ReserveWidth($targetWidth);$window.Width=[math]::Max($window.Width,$targetWidth+48);if('OrbyMonitorLayout' -as [type]){[OrbyMonitorLayout]::Position($window)}}
  if($notch.Height -lt $targetHeight){$notch.Height=$targetHeight;$window.Height=[math]::Max($window.Height,$targetHeight+10)}
  $script:compactMenuControls.MenuFooter.Text=''
 }
 Update-OrbyHomeOverview
}

$script:homeClassicSelect=${function:Select-OrbyCompanion}
function Select-OrbyCompanion {param([string]$Id) $script:homeSelecting=$true;try{& $script:homeClassicSelect $Id}finally{$script:homeSelecting=$false}}
function Set-OrbyHomePage {
 param([string]$Page='home')
 $script:dashboardRoute=if($Page -eq 'ai' -or $script:homeSelecting){'ai'}else{$Page}
 if($script:dashboardRoute -eq 'home'){$script:aiChooserOpen=$false;$script:aiChooser.BeginAnimation([Windows.FrameworkElement]::HeightProperty,$null);$script:aiChooser.Height=0;$script:aiChooser.IsHitTestVisible=$false;$script:aiChevron.Text=[string][char]0x2304}
 Set-OrbyCompactMenuPage $(if($Page -eq 'ai'){'home'}else{$Page})
 Update-OrbyDashboardLayout
}
$script:homeClassicChooser=${function:Set-OrbyAIChooser}
function Set-OrbyAIChooser {param([bool]$Open) if($script:dashboardRoute -ne 'ai'){Set-OrbyHomePage 'ai'};& $script:homeClassicChooser $Open;Update-OrbyDashboardLayout}
$script:homeClassicUpdate=${function:Update-OrbyMultiProvider}
function Update-OrbyMultiProvider {& $script:homeClassicUpdate;Update-OrbyDashboardLayout}
$script:homeClassicExpand=${function:Set-OrbitExpanded}
function Set-OrbitExpanded {param([bool]$Expand) if($Expand -and -not $script:expanded -and -not $script:orbyEventMode -and -not ($script:dropPanel -and $script:dropPanel.Visibility -eq 'Visible')){Set-OrbyHomePage 'home'};& $script:homeClassicExpand $Expand;Update-OrbyDashboardLayout}

. (Join-Path $PSScriptRoot 'Home-Visuals.ps1')
$u=$script:homeControls
$idleParts=New-OrbitAvatar;$u.HomeIdleAvatar.Child=$idleParts.Root;$script:homeIdleRenderer=[OrbyAvatarRenderer]::new($idleParts);$script:homeIdleRenderer.SetState('idle','');$script:homeIdleRenderer.ShowStatusDot=$false;$script:homeIdleRenderer.EyeEffects=$false
$u.HomeAIOptions.Add_Click({Set-OrbyAIChooser $true})
$u.OpenMusic.Add_Click({Set-OrbyHomePage 'music'})
$u.HomePrevious.Add_Click({Send-OrbyMusicControl 'previous'});$u.HomeNext.Add_Click({Send-OrbyMusicControl 'next'})
$u.HomePlay.Add_Click({$m=$script:orbyShared.SelectedMusic;if($m){Send-OrbyMusicControl $(if($m.Playing){'pause'}else{'play'})}})
$u.HomeMusicSeek.Add_PreviewMouseLeftButtonDown({$script:homeMusicDragging=$true;$script:homeSeekTrack=$script:orbyShared.SelectedMusic.TrackKey})
$u.HomeMusicSeek.Add_PreviewMouseLeftButtonUp({Complete-OrbyHomeSeek});$u.HomeMusicSeek.Add_LostMouseCapture({Complete-OrbyHomeSeek})
$u.HomeMusicSeek.Add_PreviewKeyDown({param($sender,$e)if($e.Key -in @('Left','Right','Home','End','PageUp','PageDown')){$script:homeMusicDragging=$true;$script:homeSeekTrack=$script:orbyShared.SelectedMusic.TrackKey}})
$u.HomeMusicSeek.Add_PreviewKeyUp({Complete-OrbyHomeSeek})
$private=if($PersonalDirectory){$PersonalDirectory}else{Join-Path $PSScriptRoot 'Personal'}
if(Test-Path -LiteralPath (Join-Path $private 'Home.ps1')){. (Join-Path $private 'Home.ps1');Initialize-OrbyPersonalHome $u.HomePersonalHost $script:homeDataDirectory}
$script:homeTimer=[Windows.Threading.DispatcherTimer]::new();$script:homeTimer.Interval=[timespan]::FromSeconds(1)
$script:homeTimer.Add_Tick({try{if(Test-OrbyHomeVisible){Update-OrbyHomeMusic};if(Test-Path function:Invoke-OrbyPersonalHomeTick){Invoke-OrbyPersonalHomeTick}}catch{if(Test-Path function:Write-OrbitLog){Write-OrbitLog ('Home update: '+$_.Exception.Message)}}});$script:homeTimer.Start()
$window.Add_Closed({$script:homeTimer.Stop();$script:homeIdleRenderer.Dispose();foreach($tile in $script:homeProviderTiles.Values){$tile.Renderer.Dispose();foreach($b in $tile.Buddies){$b.Renderer.Dispose()}};if(Test-Path function:Stop-OrbyPersonalHome){Stop-OrbyPersonalHome}})
Set-OrbyHomePage 'home'
