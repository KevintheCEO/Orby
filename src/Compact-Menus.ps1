if(-not (Test-Path function:Invoke-OrbySafeAction)){. (Join-Path $PSScriptRoot 'UI-Recovery.ps1')}
. (Join-Path $PSScriptRoot 'Media-Sources.ps1')
. (Join-Path $PSScriptRoot 'Music-Source-UI.ps1')
# Approved compact menus. Reuse the live input controls and their handlers, not screenshots.
function Move-OrbyMenuControl {
 param($Control,$TargetSlot)
 if(-not $Control -or -not $TargetSlot){return}
 $parent=$Control.Parent
 if($parent -is [Windows.Controls.Panel]){$parent.Children.Remove($Control)}
 elseif($parent -is [Windows.Controls.Decorator]){$parent.Child=$null}
 elseif($parent -is [Windows.Controls.ContentControl]){$parent.Content=$null}
 [Windows.Controls.Grid]::SetRow($Control,0);[Windows.Controls.Grid]::SetColumn($Control,0)
 $Control.Margin=[Windows.Thickness]::new(0)
 if($TargetSlot -is [Windows.Controls.Panel]){[void]$TargetSlot.Children.Add($Control)}else{$TargetSlot.Content=$Control}
}
function Open-OrbyProviderUsage {
 param([string]$Id=$script:orbySettings.PrimaryProvider)
 $url=switch($id){claude{'https://claude.ai/settings/usage'}gemini{'https://gemini.google.com/usage'}default{$null}}
 if($url){Start-Process $url}
}
function Update-OrbyLocalUsage {
 param([string]$Id)
 $u=$script:compactMenuControls
 $snapshots=@($script:orbyShared.ProviderSnapshots | Where-Object {$_.Provider -eq $Id -and $_.UsagePage -and $_.Usage -and $_.At -le [datetime]::UtcNow.AddSeconds(5) -and ([datetime]::UtcNow-$_.At).TotalSeconds -lt 8})
 $conflict=@($snapshots | ForEach-Object {[string]$_.Usage.SessionRemaining+'|'+[string]$_.Usage.WeekRemaining} | Select-Object -Unique).Count -gt 1
 $data=if(-not $conflict -and $snapshots.Count){($snapshots | Sort-Object At -Descending | Select-Object -First 1).Usage}else{$null}
 foreach($pair in @(@('Session','SessionRemaining','SessionReset'),@('Week','WeekRemaining','WeekReset'))){
  $value=if($data){$data.($pair[1])}else{$null};$known=$null -ne $value -and [double]$value -ge 0 -and [double]$value -le 100
  $u['Local'+$pair[0]+'Percent'].Text=if($known){[string][math]::Round([double]$value)+'% remaining'}else{'Not available'}
  $u['Local'+$pair[0]+'Bar'].Value=if($known){[double]$value}else{0}
  $u['Local'+$pair[0]+'Bar'].Visibility=if($known){'Visible'}else{'Hidden'}
  $u['Local'+$pair[0]+'Percent'].ToolTip=if($known){$data.($pair[2])}else{'No readable account usage for this window'}
 }
 $u.LocalUsageNote.Text=if($conflict){'Multiple usage pages disagree. Keep the account you want open.'}elseif($data){'Read from the open '+$script:providerCatalog[$Id].Name+' Usage page. Hover a value for its reset time.'}else{'Click Open usage, sign in, and keep that Usage page open in your browser.'}
}
function Set-OrbyCompactMenuPage {
 param([string]$Page='home')
 $previousPage=$script:compactMenuPage
 $script:compactMenuPage=$Page
 $c=$script:referenceControls
 $c.RefHomePage.Visibility=if($Page -eq 'home'){'Visible'}else{'Collapsed'}
 $c.RefAgentsPage.Visibility=if($Page -eq 'agents'){'Visible'}else{'Collapsed'}
 $c.RefMusicPage.Visibility=if($Page -eq 'music'){'Visible'}else{'Collapsed'}
 Update-OrbyNavSelection $Page
 if($Page -eq 'settings'){$c.RefHome.Tag=$null}
 $script:compactSettingsButton.Tag=if($Page -eq 'settings'){'Selected'}else{$null}
 if($Page -eq 'settings'){
  foreach($key in @('Music','Sounds','HideFullscreen','ReducedMotion')){$script:compactMenuControls['Quick'+$key].IsChecked=[bool]$script:orbySettings[$key]}
  $script:compactMenuControls.SizeMini.IsChecked=$script:orbySettings.NotchSize -eq 'mini'
  $script:compactMenuControls.SizeDefault.IsChecked=$script:orbySettings.NotchSize -ne 'mini'
  $script:compactMenuControls.SettingsNote.Text=''
 }
 if($Page -eq 'agents' -and $script:orbySettings.PrimaryProvider -eq 'chatgpt'){Update-OrbyAgents}
 if($Page -eq 'music'){Update-OrbyMusicTab}
 Update-OrbyMultiProvider
 Update-OrbyCompactMenus
 if($previousPage -ne $Page -and $script:expanded -and $script:compactMenuControls){
  $name=switch($Page){music{'MusicMenu'}settings{'SettingsMenu'}agents{if($script:orbySettings.PrimaryProvider -eq 'chatgpt'){'ChatMenu'}else{'ClaudeMenu'}}default{'HomeMenu'}}
  $body=$script:compactMenuControls[$name]
  if($body){
   $body.BeginAnimation([Windows.UIElement]::OpacityProperty,$null);$body.Opacity=if($script:orbySettings.ReducedMotion -or -not [Windows.SystemParameters]::ClientAreaAnimation){1}else{.72}
   Invoke-OrbyMotion $body ([Windows.UIElement]::OpacityProperty) 1 .14
  }
 }
}
function Update-OrbyCompactMenus {
 if(-not $script:compactMenus){return}
 $u=$script:compactMenuControls;$c=$script:referenceControls;$page=$script:compactMenuPage
 $overlay=[bool]$script:orbyEventMode -or ($script:dropPanel -and $script:dropPanel.Visibility -eq 'Visible')
 $script:compactMenus.Visibility=if($overlay){'Collapsed'}else{'Visible'}
 if($overlay){$overlayHeight=if($script:dropBusy){322}elseif($script:orbyEventMode -eq 'attention' -and $script:approvalRequest -and $script:approvalRequest.Available -and $script:approvalRequest.Kind -eq 'question'){308}else{180};$expandedArea.Width=596;$expandedArea.Height=$overlayHeight;if($notch){$notch.ExpandedWidth=620;if($script:compactMenuHeight -ne -1){$notch.BeginAnimation([OrbyLiquidSurface]::ExpandedHeightProperty,$null)};$notch.ExpandedHeight=$overlayHeight+14};$script:compactMenuHeight=-1;return}
 # Home uses real layout space, not a scaled bitmap or scaled text.
 $local=$page -eq 'agents' -and $script:orbySettings.PrimaryProvider -ne 'chatgpt'
 $shown=switch($page){music{'MusicMenu'}settings{'SettingsMenu'}agents{if($local){'ClaudeMenu'}else{'ChatMenu'}}default{'HomeMenu'}}
 $isHomeMenu=$shown -eq 'HomeMenu'
 $contentWidth=596
 $dashboard=$script:homeDashboard -and $page -eq 'home' -and $script:dashboardRoute -eq 'home'
 if($dashboard){$homeSize=Get-OrbyHomeDimensions;$contentWidth=$homeSize[0]}
 $script:compactMenus.Width=$contentWidth
 if($notch){$notch.ExpandedWidth=$contentWidth+24}
 $script:compactMenus.RowDefinitions[0].Height=[Windows.GridLength]::new(34)
 $script:compactMenus.RowDefinitions[2].Height=[Windows.GridLength]::new($(if($dashboard){8}else{20}))
 $u.MenuHealth.FontSize=11;$u.MenuFooter.FontSize=10
 foreach($button in $u.MenuNav.Children){$button.Width=if($button -eq $script:aiCompanionButton){58}else{34};$button.Height=30}
 foreach($name in @('HomeMenu','ChatMenu','ClaudeMenu','MusicMenu','SettingsMenu')){$u[$name].Visibility=if($name -eq $shown){'Visible'}else{'Collapsed'}}
 $height=switch($shown){MusicMenu{342}ChatMenu{286}ClaudeMenu{352}SettingsMenu{344}default{if($script:sharedCompanion){if($script:aiChooserOpen){354}else{310}}elseif(@(Get-OrbyPairedProviders).Count -gt 2){342}else{198}}}
 if($dashboard){$height=$homeSize[1]}
 # The host remains large enough for permissions; only the live menu/body is compact.
 $script:compactMenus.Height=$height;$expandedArea.Width=$contentWidth;$expandedArea.Height=$height
 if($notch -and ($script:compactMenuHeight -ne ($height+14))){
  $script:compactMenuHeight=$height+14
  if($script:expanded -and -not $script:orbySettings.ReducedMotion){Invoke-OrbyMotion $notch ([OrbyLiquidSurface]::ExpandedHeightProperty) ($height+14) .18}
  else{$notch.BeginAnimation([OrbyLiquidSurface]::ExpandedHeightProperty,$null);$notch.ExpandedHeight=$height+14}
 }
 $u.MenuHealth.Text=if($script:orbyShared.Health -and -not $script:orbyShared.Health.Network){'Offline'}else{'Online'}
 $u.MenuHealthDot.Fill=[Windows.Media.BrushConverter]::new().ConvertFromString($(if($u.MenuHealth.Text -eq 'Offline'){'#E2A550'}else{'#38D58B'}))
 $u.MenuHealth.ToolTip=$c.RefHealth.Text
 $u.MenuFooter.Text=switch($shown){ChatMenu{'Codex account usage · local chat activity'}ClaudeMenu{'Provider account usage · percentages remaining'}SettingsMenu{'Your preferences stay on this computer'}MusicMenu{'Media controls follow the selected player'}default{(@(Get-OrbyPairedProviders | ForEach-Object {$script:providerCatalog[$_].Name}) -join ' + ')+' connected'}}
 $fresh=$script:usageSnapshot -and $script:usageSnapshot.Connected -and ([datetime]::UtcNow-$script:usageSnapshot.At).TotalSeconds -lt 180
 $u.ChatStatus.Text=if($fresh){'Codex connected'}elseif($script:chatConnectionPresent){'ChatGPT ready · no quota feed'}else{'Waiting for local activity'}
 $u.ChatStatus.ToolTip=$c.RefUsageNotice.Text
 $u.MusicNavCover.Source=if($c.RefMusicCover.Source){$c.RefMusicCover.Source}elseif($script:albumCoverButton -and $script:albumCoverButton.Visibility -eq 'Visible'){$script:albumCoverButton.ApplyTemplate() | Out-Null;$image=$script:albumCoverButton.Template.FindName('AlbumCoverImage',$script:albumCoverButton);if($image){$image.Source}}
 $musicName=if($script:orbySettings.MediaApp){Get-OrbyMediaSourceName $script:orbySettings.MediaApp}else{'Automatic'}
 $u.ChooseMusicSource.Content='Player: '+$musicName+'  '+[char]0x25BE
 if($script:musicNavButton){$script:musicNavButton.Visibility=if($u.MusicNavCover.Source -and $script:orbySettings.Music){'Visible'}else{'Collapsed'}}
 $musicFresh=$script:orbyShared.SelectedMusic -and ([datetime]::UtcNow-$script:orbyShared.SelectedMusic.At).TotalSeconds -lt 8
 $u.MusicTint.Color=if($c.RefMusicCover.Source -and $musicFresh -and $script:compactArtworkAccent){$script:compactArtworkAccent}else{[Windows.Media.Colors]::Transparent}
 foreach($id in @('chatgpt','claude')){
  $displayId=if($id -eq 'claude' -and $local){$script:orbySettings.PrimaryProvider}else{$id}
  $avatar=$script:compactMenuAvatars[$id];$status=Get-OrbyIndependentStatus $displayId
  if($avatar){
   $visible=$script:expanded -and -not $script:fullscreenHidden -and (($id -eq 'chatgpt' -and $shown -eq 'ChatMenu') -or ($id -eq 'claude' -and $shown -eq 'ClaudeMenu'))
   $avatar.Renderer.Suspended=-not $visible;$avatar.Renderer.ReducedMotion=[bool]$script:orbySettings.ReducedMotion
   $avatar.Renderer.SetState($(if($status.Sleeping){'sleep'}elseif($status.State -eq 'unknown'){'idle'}else{$status.State}),$status.Detail)
   Set-OrbyProviderAccent $avatar.Parts $displayId $status.Sleeping ($visible -and -not $script:orbySettings.ReducedMotion)
  }
 }
 if($local){
  $id=$script:orbySettings.PrimaryProvider;$status=Get-OrbyIndependentStatus $id
  $u.LocalProviderName.Text=$script:providerCatalog[$id].Name
  if($script:compactLocalLogoId -ne $id){$u.ClaudeLogo.Content=New-OrbyProviderLogo $id 19;$script:compactLocalLogoId=$id}
  $u.ClaudeStatus.Text=if($status.Sleeping){'Sleeping'}elseif($status.State -eq 'unknown'){if($status.Open){'App open'}else{'Waiting for activity'}}elseif($status.State -eq 'idle'){'Ready'}else{$status.Detail}
  $u.ClaudeStatus.ToolTip=$status.Detail
  $desktop=@($script:orbyShared.ProviderSnapshots | Where-Object {$_.Provider -eq $id -and -not $_.UsagePage -and $_.Source -ne 'code' -and ([datetime]::UtcNow-$_.At).TotalSeconds -lt 8} | Select-Object -First 1)
  $u.ClaudeDesktop.Text=if($desktop.Count -and $desktop[0].AppOpen){if($desktop[0].StatusReadable -and $desktop[0].State -eq 'working'){'Working'}else{'App open'}}else{'Waiting for activity'}
  $code=$script:orbyShared.ClaudeCodeStatus
  $u.ClaudeCode.Text=if($id -ne 'claude'){'Not applicable'}elseif($code -and $script:orbyShared.ClaudeCodeAt -and ([datetime]::UtcNow-$script:orbyShared.ClaudeCodeAt).TotalSeconds -lt 8 -and $code.Open){if($code.State -eq 'working'){'Working'}else{'Sync ready'}}elseif(Get-OrbyClaudeCodeSync){'Sync enabled'}else{'Sync off'}
  $u.LocalCodeSync.IsEnabled=$id -eq 'claude'
  $u.LocalCodeSync.Visibility=if($id -eq 'claude'){'Visible'}else{'Collapsed'}
  $u.LocalCodeRow.Visibility=if($id -eq 'claude'){'Visible'}else{'Collapsed'}
  Update-OrbyLocalUsage $id
 }
 # The separate compact cover is replaced by the navigation cover while expanded.
 if($script:albumCoverButton){$script:albumCoverButton.Opacity=if($script:expanded){0}else{1};$script:albumCoverButton.IsHitTestVisible=-not $script:expanded}
}
function Initialize-OrbyCompactMenus {
 [xml]$x=Get-Content (Join-Path $PSScriptRoot 'Compact-Menus.xaml') -Raw
 $script:compactMenus=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($x));$script:compactMenuControls=@{}
 foreach($match in [regex]::Matches($x.OuterXml,'x:Name="([^"]+)"')){$name=$match.Groups[1].Value;$script:compactMenuControls[$name]=$script:compactMenus.FindName($name)}
 $u=$script:compactMenuControls;$c=$script:referenceControls
 # Keep the old namescope and controls alive for existing media/usage/permission updates.
 foreach($key in $script:referenceHome.Resources.Keys){if(-not $script:compactMenus.Resources.Contains($key)){$script:compactMenus.Resources.Add($key,$script:referenceHome.Resources[$key])}}
 $expandedArea.Children.Remove($script:referenceHome);[void]$expandedArea.Children.Add($script:compactMenus)
 Move-OrbyMenuControl $c.RefHome $u.MenuNav
 foreach($id in @('chatgpt','claude','gemini')){Move-OrbyMenuControl $script:providerNav[$id] $u.MenuNav}
 $script:compactSettingsButton=[Windows.Controls.Button]::new();$script:compactSettingsButton.Style=$script:referenceHome.Resources.NavButton
 $glyph=[Windows.Controls.TextBlock]::new();$glyph.FontFamily='Segoe MDL2 Assets';$glyph.Text=[string][char]0xE713;$glyph.FontSize=13
 $script:compactSettingsButton.Content=$glyph;$script:compactSettingsButton.ToolTip='Settings';$script:compactSettingsButton.Add_Click({Set-OrbyCompactMenuPage 'settings'})
 [void]$u.MenuNav.Children.Add($script:compactSettingsButton)
 $music=[Windows.Controls.Button]::new();$music.Style=$script:referenceHome.Resources.NavButton;$music.ToolTip='Music player';$script:musicNavButton=$music;$music.Add_Click({Set-OrbyHomePage 'music'})
 $cover=[Windows.Controls.Image]::new();$cover.Width=19;$cover.Height=19;$cover.Stretch='UniformToFill';$u.MusicNavCover=$cover
 $tile=[Windows.Controls.Border]::new();$tile.Width=19;$tile.Height=19;$tile.CornerRadius=[Windows.CornerRadius]::new(4)
 $tile.Clip=[Windows.Media.RectangleGeometry]::new([Windows.Rect]::new(0,0,19,19),4,4);$tile.Child=$cover
 $music.Content=$tile;[void]$u.MenuNav.Children.Add($music)
 Move-OrbyMenuControl $script:multiHome $u.HomeMenu
 foreach($pair in @(@('RefMusicCover','CoverSlot'),@('RefMusicTitle','TitleSlot'),@('RefMusicArtist','ArtistSlot'),@('RefMusicNotice','NoticeSlot'),@('RefMusicSeek','SeekSlot'),@('RefMusicPosition','PositionSlot'),@('RefMusicDuration','DurationSlot'),@('RefMusicVolume','VolumeSlot'),@('RefMusicVolumeText','VolumeValueSlot'),@('RefTokenValue','TokenSlot'),@('RefActivityPeriod','PeriodSlot'))){Move-OrbyMenuControl $c[$pair[0]] $u[$pair[1]]}
 foreach($key in @('RefMusicTitle','RefMusicArtist','RefMusicNotice','RefMusicPosition','RefMusicDuration','RefMusicVolumeText')){$c[$key].FontSize=if($key -eq 'RefMusicTitle'){16}else{12};$c[$key].TextTrimming='CharacterEllipsis'}
 $c.RefMusicCover.Width=80;$c.RefMusicCover.Height=80
 foreach($key in @('RefMusicShuffle','RefMusicPrevious','RefMusicPlay','RefMusicNext','RefMusicRepeat')){Move-OrbyMenuControl $c[$key] $u.PlaybackHost;$c[$key].Width=42;$c[$key].Height=38;$c[$key].Margin=[Windows.Thickness]::new(4,0,4,0);$c[$key].Padding=[Windows.Thickness]::new(0)}
 $c.RefMusicVolume.Height=30;$c.RefMusicVolume.Width=[double]::NaN;$c.RefMusicSeek.Height=30
 foreach($key in @('RefSessionRow','RefWeekRow','RefQuotaNotice')){Move-OrbyMenuControl $c[$key] $u.QuotaHost;$c[$key].Margin=[Windows.Thickness]::new(0,2,0,2)}
 foreach($key in @('RefSessionLabel','RefWeekLabel','RefSessionPercent','RefWeekPercent','RefQuotaNotice')){$c[$key].FontSize=12}
 foreach($key in @('RefSessionBar','RefWeekBar')){$c[$key].Style=$c.RefAgentsPage.Resources[[type][Windows.Controls.ProgressBar]];$c[$key].Height=6;$c[$key].Foreground=[Windows.Media.BrushConverter]::new().ConvertFromString('#48D68D')}
 $c.RefTokenValue.FontSize=13;$c.RefTokenValue.FontWeight='Bold';$c.RefActivityPeriod.FontSize=11
 $u.UsageRefresh.Add_Click({$script:usagePollAt=[datetime]::MinValue;Update-OrbyAccountUsage;Update-OrbyAgents})
 $u.ChatLogo.Content=New-OrbyProviderLogo 'chatgpt' 18;$u.ClaudeLogo.Content=New-OrbyProviderLogo 'claude' 19
 $script:compactMenuAvatars=@{}
 foreach($pair in @(@('chatgpt','ChatAvatar'),@('claude','ClaudeAvatar'))){$parts=New-OrbitAvatar;$renderer=[OrbyAvatarRenderer]::new($parts);$renderer.ShowStatusDot=$false;$u[$pair[1]].Child=$parts.Root;$script:compactMenuAvatars[$pair[0]]=@{Parts=$parts;Renderer=$renderer}}
 foreach($key in @('LocalSessionBar','LocalWeekBar')){$u[$key].Style=$c.RefAgentsPage.Resources[[type][Windows.Controls.ProgressBar]]}
 $u.LocalUsageOpen.Add_Click({Invoke-OrbySafeAction {Open-OrbyProviderUsage} 'Open account usage'})
 $u.LocalConnections.Add_Click({Show-OrbyConnections});$u.QuickConnections.Add_Click({Show-OrbyConnections})
 $u.LocalCodeSync.Add_Click({Toggle-OrbyClaudeCodeSync;Update-OrbyCompactMenus})
 if($script:orbyPrivateWater){
  $privatePreview=[Windows.Controls.Button]::new();$privatePreview.Content='Water animation';$privatePreview.FontSize=11;$privatePreview.Padding='8,3';$privatePreview.Margin='12,0,8,0'
  $privatePreview.Add_Click({Invoke-OrbySafeAction {Show-OrbyAnimations} 'Personal animation preview'})
  [Windows.Controls.DockPanel]::SetDock($privatePreview,'Right');$u.MoreSettings.Parent.Children.Insert(0,$privatePreview)
 }
 $u.MoreSettings.Add_Click({Show-OrbySettings})
 $u.ChooseMusicSource.Add_Click({Show-OrbyMusicSources $this})
 $u.QuickMusicApp.Add_Click({Set-OrbyHomePage 'music'})
 $u.QuickSave.Add_Click({
  foreach($key in @('Music','Sounds','HideFullscreen','ReducedMotion')){$script:orbySettings[$key]=[bool]$script:compactMenuControls['Quick'+$key].IsChecked}
  $script:orbySettings.NotchSize=if($script:compactMenuControls.SizeMini.IsChecked){'mini'}else{'default'}
  Save-OrbySettings;Update-OrbyCompactTask;$script:compactMenuControls.SettingsNote.Text='Saved'
 })
 $window.Add_Closed({foreach($avatar in $script:compactMenuAvatars.Values){$avatar.Renderer.Dispose()}})
 $script:compactMenuPage='home';Update-OrbyCompactMenus
}

# Adapt the existing update entry points so all sources continue updating one live UI.
$script:classicMultiProviderUpdate=${function:Update-OrbyMultiProvider}
function Update-OrbyMultiProvider {& $script:classicMultiProviderUpdate;Update-OrbyCompactMenus}
function Set-OrbyHomePage {param([string]$Page='home') Set-OrbyCompactMenuPage $Page}
$script:classicAlbumPlacement=${function:Set-OrbyAlbumPlacement}
function Set-OrbyAlbumPlacement {
 param([bool]$Expand,[bool]$Animate=$true)
 if($script:albumCoverButton){$script:albumCoverButton.Opacity=if($Expand){0}else{1};$script:albumCoverButton.IsHitTestVisible=-not $Expand}
 if(-not $Expand -and $script:classicAlbumPlacement){& $script:classicAlbumPlacement $false $Animate}
}
$script:classicEventUpdate=${function:Update-OrbyEventCard}
if($script:classicEventUpdate){function Update-OrbyEventCard {& $script:classicEventUpdate;Update-OrbyCompactMenus}}
$script:classicDropComposer=${function:Show-OrbyDropComposer}
if($script:classicDropComposer){function Show-OrbyDropComposer {& $script:classicDropComposer;Update-OrbyCompactMenus}}
$script:classicExpandedToggle=${function:Set-OrbitExpanded}
if($script:classicExpandedToggle){function Set-OrbitExpanded {param([bool]$Expand) if(-not $Expand -and (($script:musicSourceMenu -and $script:musicSourceMenu.IsOpen) -or (Test-OrbyTaskMenuOpen))){return};$wasExpanded=$script:expanded;& $script:classicExpandedToggle $Expand;if($wasExpanded -ne $script:expanded){Update-OrbyMultiProvider}}}
$script:classicFullscreenToggle=${function:Set-OrbyFullscreenHidden}
if($script:classicFullscreenToggle){function Set-OrbyFullscreenHidden {param([bool]$hide) if($hide){Close-OrbyTaskMenus};if($hide -and $script:musicSourceMenu){$script:musicSourceMenu.IsOpen=$false};& $script:classicFullscreenToggle $hide;Update-OrbyMultiProvider}}
Initialize-OrbyCompactMenus
. (Join-Path $PSScriptRoot 'Shared-Companion.ps1')
