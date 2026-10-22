param([string]$PreviewDirectory='',[string]$PrivateDirectory='',[switch]$KeepHomeWindow)
$ErrorActionPreference='Stop';$outputDirectory=$PreviewDirectory
. (Join-Path $PSScriptRoot 'Test-AllLargeMenus.ps1') -KeepWindow
$PreviewDirectory=$outputDirectory;$script:homeChecks=0
function CheckHome($Ok,[string]$Why){if(-not $Ok){throw $Why};$script:homeChecks++}
$isolated=Join-Path ([IO.Path]::GetTempPath()) ('Orby-home-test-'+[guid]::NewGuid().ToString('N'));[void][IO.Directory]::CreateDirectory($isolated)
. (Join-Path $PSScriptRoot 'Home-Dashboard.ps1') -NoNetwork -PersonalDirectory $PrivateDirectory -HomeDataDirectory $isolated
function HomeLayout {$window.Content.Measure([Windows.Size]::new($window.Width,$window.Height));$window.Content.Arrange([Windows.Rect]::new(0,0,$window.Width,$window.Height));$window.Content.UpdateLayout()}
function SaveHome([string]$Name){
 if(-not $PreviewDirectory){return};[void][IO.Directory]::CreateDirectory($PreviewDirectory);HomeLayout
 $script:homeIdleRenderer.Draw(1)
 foreach($tile in $script:homeProviderTiles.Values){$tile.Renderer.Draw(1);foreach($b in $tile.Buddies){$b.Renderer.Draw(1)}}
 $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new([int]$window.Width,[int]$window.Height,96,96,[Windows.Media.PixelFormats]::Pbgra32);$bitmap.Render($window.Content)
 $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap));$fs=[IO.File]::Create((Join-Path $PreviewDirectory ($Name+'.png')));try{$encoder.Save($fs)}finally{$fs.Dispose()}
}
try{
 $script:expanded=$true;$script:orbyEventMode='';$script:fullscreenHidden=$false;$script:orbySettings.ReducedMotion=$true;$script:orbySettings.ProviderEnabled='chatgpt,claude,gemini';Set-OrbyHomePage 'home';HomeLayout
 CheckHome ($script:dashboardRoute -eq 'home' -and $script:homeDashboard.Visibility -eq 'Visible' -and $script:sharedCompanionView.Visibility -eq 'Collapsed') 'Home still duplicates AI detail'
 CheckHome ($script:compactMenus.Width -eq 596 -and $script:compactMenus.Height -eq 344) 'Home does not match Settings dimensions'
 CheckHome ($notch.Height -ge $script:compactMenus.Height+14 -and $window.Height -ge $notch.Height) 'Native host clips the expanded Home'
 CheckHome ($script:homeControls.HomeMusicSeek.IsEnabled -eq $false -and $script:homeControls.HomeMusicCover.Source -eq $null) 'Idle music shows stale metadata'
 CheckHome (-not $script:homeControls.ContainsKey('WeatherCard') -and -not (Test-Path function:Start-OrbyHomeForecast)) 'Home still contains or polls weather'
 CheckHome ($script:homeControls.HomeAICard.Background.Color.ToString() -eq '#FF101115' -and $script:homeControls.HomeMusicCard.Background.Color.ToString() -eq '#FF101115') 'Home does not match charcoal menu cards'
 foreach($card in $script:providerCards.Values){CheckHome ($card.Renderer.Suspended) 'Hidden detailed AI animation is running on Home'}
 $script:orbyActiveTasks=@(
  [pscustomobject]@{Id='gpt-one';Provider='chatgpt';State='working';Title='Example review';Action='Reviewing code'},
  [pscustomobject]@{Id='gpt-two';Provider='chatgpt';State='working';Title='Example second task';Action='Checking attachments'},
  [pscustomobject]@{Id='claude-one';Provider='claude';State='working';Title='Example writing';Action='Writing'},
  [pscustomobject]@{Id='gemini-one';Provider='gemini';State='working';Title='Example research';Action='Researching'},
  [pscustomobject]@{Id='gemini-two';Provider='gemini';State='attention';Title='Example question';Action='Waiting for input'})
 Update-OrbyMultiProvider;HomeLayout
 CheckHome ($script:homeControls.ActiveProviders.Columns -eq 3 -and $script:homeControls.ActiveTotal.Text -eq '3 providers · 5 active tasks') 'Overview lost providers/task counts'
 foreach($id in @('chatgpt','claude','gemini')){CheckHome ($script:homeProviderTiles[$id].Host.Visibility -eq 'Visible') 'Active provider absent'}
 CheckHome ($script:homeProviderTiles.chatgpt.Buddies[0].Host.Visibility -eq 'Visible' -and $script:homeProviderTiles.chatgpt.Buddies[0].Renderer.ShowStatusDot) 'Second task avatar/orbit absent'
 CheckHome ($script:homeProviderTiles.claude.Buddies[0].Host.Visibility -eq 'Collapsed') 'Overview invented an extra task'
 $script:homeProviderTiles.chatgpt.Host.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent));HomeLayout
 CheckHome ($script:dashboardRoute -eq 'ai' -and $script:companionSelection -eq 'chatgpt' -and $script:sharedCompanionView.Visibility -eq 'Visible') 'Active tile does not open selected AI detail'
 CheckHome ($script:providerCards.chatgpt.Tasks.Count -eq 2 -and -not $script:providerCards.chatgpt.Renderer.Suspended) 'Detailed task inspector regressed'
 foreach($tile in $script:homeProviderTiles.Values){CheckHome ($tile.Renderer.Suspended) 'Hidden Home renderer still running'}
 Set-OrbyHomePage 'home';Set-OrbyAIChooser $true;HomeLayout
 CheckHome ($script:dashboardRoute -eq 'ai' -and $script:aiChooserOpen -and $script:compactMenus.Width -eq 596) 'AI button lost separate chooser/detail view'
 Set-OrbyHomePage 'home';CheckHome (-not $script:aiChooserOpen) 'Home leaves AI selector open'
 foreach($page in @('settings','music','agents')){Set-OrbyHomePage $page;HomeLayout;CheckHome ($script:compactMenus.Width -eq 596) 'Non-Home menu design changed';CheckHome $script:homeIdleRenderer.Suspended 'Hidden idle Home avatar keeps rendering'}
 Set-OrbitExpanded $false;Set-OrbitExpanded $true;HomeLayout;CheckHome ($script:dashboardRoute -eq 'home') 'Reopening notch did not return to Home'
 # Actual controls use the existing media worker; test only records the command.
 $script:orbyShared.SelectedMusic=[pscustomobject]@{At=[datetime]::UtcNow;Title='Example track';Artist='Test artist';Name='Test player';Duration=240;Playing=$true;CanPause=$true;CanPlay=$true;CanPrevious=$true;CanNext=$true;CanSeek=$true;TrackKey='fixture-track';ArtworkKey='';ArtworkBytes=$null}
 Update-OrbyHomeMusic;CheckHome ($script:homeControls.HomeMusicSeek.IsEnabled -and $script:homeControls.HomeMusicTitle.Text -eq 'Example track') 'Live Home music controls not bound'
 $script:homeControls.HomePlay.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent));CheckHome ($script:lastMusic -eq 'pause') 'Home play/pause not routed to real control path'
 $script:orbyShared.SelectedMusic.At=[datetime]::UtcNow.AddSeconds(-20);Update-OrbyHomeMusic;CheckHome (-not $script:homeControls.HomePlay.IsEnabled -and $script:homeControls.HomeMusicTitle.Text -eq 'Nothing playing') 'Stale media remains actionable'
 $script:orbyShared.SelectedMusic=$null
 if($PrivateDirectory){
  CheckHome ($script:personalWaterCard -and $script:homeControls.HomePersonalHost.Visibility -eq 'Visible' -and $script:homeControls.HomeWaterRow.Height.Value -eq 58) 'Personal water row missing'
  $script:testNow=[datetime]'2026-10-21T14:00:00';function Get-OrbyPersonalNow {return $script:testNow}
  $script:personalWater.Date='2026-10-21';$script:personalWater.TotalMl=0;$script:personalWater.History=@([pscustomobject]@{Date='2026-10-20';TotalMl=500});$script:personalWater.NextReminder=$script:testNow.AddMinutes(-1).ToString('o');$script:personalWater.UnknownPreserved='keep'
  $script:orbyEventMode='attention';Invoke-OrbyPersonalHomeTick;CheckHome (-not $script:personalReminderPending -and $script:personalWater.TotalMl -eq 0) 'Reminder obscures approval or logs a drink'
  $script:orbyEventMode='';Invoke-OrbyPersonalHomeTick;CheckHome ($script:personalReminderPending -and $script:personalWater.TotalMl -eq 0) 'Due reminder not restored safely'
  Invoke-OrbyPersonalHomeTick;CheckHome ($script:personalWater.TotalMl -eq 0) 'Repeated reminder logged water'
  Snooze-OrbyPersonalReminder;CheckHome (-not $script:personalReminderPending -and $script:personalWater.TotalMl -eq 0 -and [datetime]::Parse($script:personalWater.NextReminder) -eq $script:testNow.AddMinutes(10)) 'Snooze changes intake or wrong schedule'
  Add-OrbyPersonalDrink;Add-OrbyPersonalDrink;CheckHome ($script:personalWater.TotalMl -eq 250) 'Explicit log missing or double-click counted twice'
  CheckHome ($script:personalUi.Percent.Text -eq '8%' -and [math]::Abs($script:personalUi.Fill.Height-(32.0/12)) -lt .01) ('Bottle not synchronized: '+$script:personalUi.Percent.Text+' fill='+$script:personalUi.Fill.Height+' goal='+$script:personalPreferences.GoalMl)
  $saved=Get-Content (Join-Path $isolated 'water-progress.json') -Raw | ConvertFrom-Json;CheckHome ($saved.UnknownPreserved -eq 'keep' -and $saved.History.Count -eq 1) 'Saving destroyed previous history/fields'
  $script:testNow=$script:testNow.AddDays(1);Invoke-OrbyPersonalHomeTick;CheckHome ($script:personalWater.TotalMl -eq 0 -and $script:personalWater.History.Count -eq 2 -and -not $script:personalReminderPending) 'Midnight rollover lost history or sends catch-up reminders'
  $script:personalWater.TotalMl=3000;$script:personalWater.NextReminder=$script:testNow.AddMinutes(-1).ToString('o');Invoke-OrbyPersonalHomeTick;CheckHome (-not $script:personalReminderPending) 'Goal reached still triggers reminders'
  $script:personalWater.TotalMl=1500;$script:personalWater.NextReminder=$script:testNow.AddMinutes(20).ToString('o');Update-OrbyPersonalHome $true;SaveHome 'Personal-Home-example-data'
  $script:personalUi.Preferences.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent));HomeLayout
  CheckHome ($script:personalPreferencesWindow.IsVisible -and $script:personalPreferencesUi.Enabled.IsChecked -and $script:personalPreferencesUi.Snooze.IsEnabled) 'Water settings no longer reachable from the card'
  $script:personalPreferencesUi.Enabled.IsChecked=$false;$script:personalPreferencesUi.Save.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
  CheckHome (-not $script:personalPreferences.Enabled -and -not $script:personalPreferencesWindow.IsVisible) 'Moved reminder enable control does not save'
  Show-OrbyPersonalPreferences;$script:personalPreferencesUi.Enabled.IsChecked=$true;$script:personalPreferencesUi.Save.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
  CheckHome $script:personalPreferences.Enabled 'Reminders cannot be re-enabled'
  Show-OrbyPersonalPreferences;$script:personalPreferencesUi.Snooze.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
  CheckHome ([datetime]::Parse($script:personalWater.NextReminder) -eq $script:testNow.AddMinutes(10) -and $script:personalWater.TotalMl -eq 1500) 'Moved snooze control changed intake or lost its timing' 
 }else{CheckHome (-not $script:personalWaterCard -and -not (Test-Path function:Invoke-OrbyPersonalHomeTick)) 'Public Home includes private reminders';SaveHome 'Public-Home-example-data'}
 # Empty state must not retain fabricated activity after snapshots disappear.
 $script:orbyActiveTasks=@();$script:orbyShared.ProviderSnapshots=@();$script:chatLogState='idle';$script:chatConnectionPresent=$false;$script:orbyShared.ProviderPresence=$null;Update-OrbyMultiProvider
 CheckHome ($script:homeControls.ActiveProviders.Columns -ge 1) 'Empty AI state has invalid layout'
 $script:orbySettings.ProviderEnabled='';$script:orbyActiveTasks=@();Update-OrbyMultiProvider;HomeLayout
 CheckHome ($script:homeControls.HomeIdleAI.Visibility -eq 'Visible' -and $script:homeControls.HomeAIRow.Height.Value -eq 58) 'Idle AI strip did not collapse'
 CheckHome ($script:homeControls.HomeCoverFrame.Width -eq 124) 'Idle music did not gain space'
 $script:orbyEventMode='attention';Update-OrbyCompactMenus;CheckHome ($script:compactMenus.Visibility -eq 'Collapsed') 'Dashboard covers approval card'
 $script:orbyEventMode='';Set-OrbyHomePage 'home';HomeLayout
 $script:testPage='Home dashboard';Check-VisibleControls $script:compactMenus
 CheckHome ($script:homeDashboard.ScrollableHeight -eq 0) 'Full-size Home unnecessarily scrolls'
 $script:compactMenus.Height=260;$expandedArea.Height=260;HomeLayout
 CheckHome ($script:homeDashboard.ScrollableHeight -gt 0) 'Small display has no way to reach lower Home controls'
 $script:homeDashboard.ScrollToBottom();HomeLayout
 CheckHome ($script:homeDashboard.VerticalOffset -gt 0) 'Home scrolling is stuck'
 Set-OrbyHomePage 'home';HomeLayout
 "PASS: $script:homeChecks Home dashboard checks; isolated data: $isolated"
}finally{if(-not $KeepHomeWindow){$window.Close()}}
