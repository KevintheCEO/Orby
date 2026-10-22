param([string]$PreviewDirectory='')
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Xaml
. (Join-Path $PSScriptRoot 'Orb-Avatar.ps1')
. (Join-Path $PSScriptRoot 'Motion.ps1')
Add-Type -Path (Join-Path $PSScriptRoot 'Liquid-Surface.cs') -ReferencedAssemblies WindowsBase,PresentationCore,PresentationFramework,System.Xaml
Add-Type -Path (Join-Path $PSScriptRoot 'Provider-Reader.cs') -ReferencedAssemblies UIAutomationClient,UIAutomationTypes,WindowsBase,System.Core
. (Join-Path $PSScriptRoot 'Account-Usage.ps1')
. (Join-Path $PSScriptRoot 'Reference-Home.ps1')
$window=[Windows.Window]::new();$window.Width=668;$window.Height=384;$window.ShowActivated=$false;$window.WindowStyle='None';$window.Background=[Windows.Media.Brushes]::Black
$expandedArea=[Windows.Controls.Grid]::new();$expandedArea.HorizontalAlignment='Center';$expandedArea.VerticalAlignment='Top';$expandedArea.Margin='0,8,0,0'
$notch=[OrbyLiquidSurface]::new();$notch.Morph=1;$notch.Child=$expandedArea;$window.Content=$notch
$script:orbySettings=@{PrimaryProvider='chatgpt';ProviderEnabled='chatgpt,claude';ReducedMotion=$false;EyeEffects=$true;NotchSize='mini';Music=$true;Sounds=$false;HideFullscreen=$true}
$script:orbyShared=@{Health=@{Network=$true;Battery=80};ProviderPresence=@{At=[datetime]::UtcNow;Names=@('Claude','ChatGPT')};ProviderSnapshots=@(
 [OrbyProviderSnapshot]@{Provider='claude';Source='chat';AppOpen=$true;Connected=$true;StatusReadable=$true;State='working';Detail='Writing a reply';At=[datetime]::UtcNow},
 [OrbyProviderSnapshot]@{Provider='chatgpt';AppOpen=$true;Connected=$true;StatusReadable=$true;State='working';Detail='Reviewing code';At=[datetime]::UtcNow})}
$script:chatConnectionPresent=$true;$script:chatLogState='working';$script:expanded=$true
function Save-OrbySettings {$script:savedCount++}
function Get-NotchTaskTitle {'Reviewing code'}
function Get-OrbyClaudeCodeSync {$false}
function Toggle-OrbyClaudeCodeSync {$script:codeClicked=$true}
function Open-OrbyProvider($Id){$script:lastOpened=$Id}
function Show-OrbyConnections {$script:connectionsClicked=$true}
function Show-OrbySettings {$script:moreClicked=$true}
function Send-OrbyMusicControl($Action,$Value,$TrackKey){$script:lastMusic=$Action}
function Get-OrbySmoothMusicPosition($m){return 64}
function Format-OrbyMusicTime($seconds){'{0}:{1:00}' -f [math]::Floor($seconds/60),($seconds%60)}
function Update-OrbyCompactTask {}
function Set-OrbitExpanded($Expand){$script:expanded=$Expand}
$script:providerDirectory=$PSScriptRoot
. (Join-Path $PSScriptRoot 'Provider-Icons.ps1');Initialize-OrbyProviderIcons
$script:providerCatalog=@{chatgpt=@{Name='ChatGPT'};claude=@{Name='Claude'};gemini=@{Name='Gemini'}}
$source=Get-Content (Join-Path $PSScriptRoot 'Providers.ps1') -Raw
$functions=$source.Substring($source.IndexOf('function Get-OrbyProviderSnapshot'),$source.IndexOf('. (Join-Path $PSScriptRoot ''Multi-Provider.ps1'')')-$source.IndexOf('function Get-OrbyProviderSnapshot'))
. ([scriptblock]::Create($functions))
# Keep fixture side effects local.
function Save-OrbySettings {$script:savedCount++}
function Open-OrbyProvider($Id){$script:lastOpened=$Id}
function Show-OrbyConnections {$script:connectionsClicked=$true}
$script:referenceHome=New-OrbyHome;[void]$expandedArea.Children.Add($script:referenceHome);$script:providerIconResources=$null;Initialize-OrbyProviderIcons
. (Join-Path $PSScriptRoot 'Multi-Provider.ps1');Initialize-OrbyMultiProvider
. (Join-Path $PSScriptRoot 'Compact-Menus.ps1')
function Assert($ok,$why){if(-not $ok){throw $why};$script:assertions++}
function Layout {
 $window.Content.Measure([Windows.Size]::new(668,384));$window.Content.Arrange([Windows.Rect]::new(0,0,668,384));$window.Content.UpdateLayout()
}
function Capture($name){
 if(-not $PreviewDirectory){return}
 [void][IO.Directory]::CreateDirectory($PreviewDirectory);Layout
 foreach($card in $script:providerCards.Values){$card.Renderer.Draw(1);foreach($b in $card.Buddies){$b.Renderer.Draw(1)}}
 foreach($a in $script:compactMenuAvatars.Values){$a.Renderer.Draw(1)}
 $height=[int]($script:compactMenus.Height+16)
 $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new(([int]$script:compactMenus.Width+56),$height,96,96,[Windows.Media.PixelFormats]::Pbgra32)
 $visual=[Windows.Media.DrawingVisual]::new();$dc=$visual.RenderOpen();$brush=[Windows.Media.VisualBrush]::new($script:compactMenus);$dc.DrawRectangle([Windows.Media.Brushes]::Black,$null,[Windows.Rect]::new(0,0,($script:compactMenus.Width+56),$height));$dc.DrawRectangle($brush,$null,[Windows.Rect]::new(28,8,$script:compactMenus.Width,$script:compactMenus.Height));$dc.Close();$bitmap.Render($visual)
 $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap));$fs=[IO.File]::Create((Join-Path $PreviewDirectory ($name+'.png')));try{$encoder.Save($fs)}finally{$fs.Dispose()}
}
$window.Show();Layout
Assert ($script:compactMenus.ActualWidth -eq 596) 'Compact menu content width incorrect'
Assert ([math]::Abs($notch.Clip.Bounds.Width-656) -lt .1) 'Expanded body or shoulder geometry does not fit compact menu'
Assert ($script:providerCards.Count -eq 2) 'Two provider cards missing'
foreach($card in $script:providerCards.Values){Assert ($card.View.ActualWidth -ge 160 -and $card.Controls.Title.ActualWidth -ge 65) 'Home card text squeezed';Assert ($card.Buddies.Count -eq 4) 'Companion animations lost'}
Capture '01-home'
$snapshot=[OrbyUsageSnapshot]::new();$snapshot.Connected=$true;$snapshot.At=[datetime]::UtcNow
$resetHour=[DateTimeOffset]::UtcNow.AddHours(1).ToUnixTimeSeconds();$resetWeek=[DateTimeOffset]::UtcNow.AddDays(3).ToUnixTimeSeconds()
$snapshot.LimitsJson='{"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":40,"windowDurationMins":300,"resetsAt":'+$resetHour+'},"secondary":{"usedPercent":15,"windowDurationMins":10080,"resetsAt":'+$resetWeek+'}}}}'
$snapshot.UsageJson='{"dailyUsageBuckets":[{"startDate":"'+[datetime]::UtcNow.ToString('yyyy-MM-dd')+'","tokens":12400}]}'
$script:usageSnapshot=$snapshot
Update-OrbyAgents # Match startup/background completion preparation in the app.
$pending=[System.Threading.Tasks.TaskCompletionSource[OrbyUsageSnapshot]]::new();$script:usagePollTask=$pending.Task
$openWatch=[Diagnostics.Stopwatch]::StartNew();Select-OrbyProviderPage 'chatgpt';$openWatch.Stop();Layout
Assert ($openWatch.ElapsedMilliseconds -lt 500 -and -not $pending.Task.IsCompleted) 'New account menu blocked on pending refresh'
Assert ($script:compactMenuControls.ChatMenu.Visibility -eq 'Visible') 'ChatGPT page missing'
Assert ($script:referenceControls.RefSessionBar.Value -eq 60) 'Live quota binding lost'
Assert ($script:referenceControls.RefWeekBar.Value -eq 85) 'Weekly quota binding lost'
Capture '02-chatgpt-sample-data'
$script:usagePollTask=$null
Select-OrbyProviderPage 'claude';Layout
Assert ($script:compactMenuControls.ClaudeMenu.Visibility -eq 'Visible') 'Claude page missing'
Assert ($script:orbySettings.ProviderEnabled -eq 'chatgpt,claude') 'Provider selection disconnected another provider'
Assert ($script:compactMenuControls.ClaudeDesktop.Text -eq 'Working') 'Claude desktop activity missing'
Capture '03-claude'
Set-OrbyHomePage 'settings';Layout
Assert ($script:compactMenuControls.SettingsMenu.Visibility -eq 'Visible') 'Settings page missing'
$script:compactMenuControls.SizeDefault.IsChecked=$true;$script:compactMenuControls.QuickMusic.IsChecked=$false
$script:compactMenuControls.QuickSave.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert ($script:orbySettings.NotchSize -eq 'default' -and -not $script:orbySettings.Music -and $script:savedCount -gt 0) 'Settings Save did not persist'
Capture '04-settings'
$script:orbySettings.Music=$true
$pixels=New-Object byte[] (64*64*4);for($i=0;$i -lt $pixels.Length;$i+=4){$pixels[$i]=140;$pixels[$i+1]=35;$pixels[$i+2]=4;$pixels[$i+3]=255}
$cover=[Windows.Media.Imaging.BitmapSource]::Create(64,64,96,96,[Windows.Media.PixelFormats]::Bgra32,$null,$pixels,256)
$script:referenceControls.RefMusicCover.Source=$cover;$script:compactArtworkAccent=[Windows.Media.Color]::FromArgb(100,4,35,140)
$script:orbyShared.SelectedMusic=@{At=[datetime]::UtcNow;App='AppleMusic.exe';Name='Apple Music';Title='Night drive';Artist='Sample track';ArtworkKey='test';Playing=$true;CanPause=$true;CanPlay=$true;CanSeek=$true;CanNext=$true;CanPrevious=$true;CanShuffle=$true;CanRepeat=$true;Start=0;Duration=240}
$script:referenceMusicArtKey='test'
Set-OrbyHomePage 'music';Layout
Assert ($script:referenceControls.RefMusicSeek.Maximum -eq 240) 'Track timeline disconnected'
$script:referenceControls.RefMusicNext.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert ($script:lastMusic -eq 'next') 'Playback handler lost during layout migration'
Assert ($script:referenceControls.RefMusicSeek.ActualWidth -ge 220) 'Seek target too narrow'
foreach($element in @($script:referenceControls.RefMusicSeek,$script:referenceControls.RefMusicVolume,$script:compactMenuControls.ChooseMusicSource)){
 $point=$element.TranslatePoint([Windows.Point]::new(0,0),$script:compactMenus)
 Assert ($point.Y -ge 26 -and $point.Y+$element.ActualHeight -le $script:compactMenus.Height-16) 'Music input is outside the visible content panel'
}
Capture '05-music-sample-data'
$script:orbyShared.MusicSources=@(@{Id='AppleMusic.exe';Name='Apple Music';Count=1},@{Id='chrome.exe';Name='Chrome · browser media';Count=1})
$script:compactMenuControls.ChooseMusicSource.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert ($script:musicSourceMenu.IsOpen -and $script:musicSourceMenu.Items.Count -eq 5) 'Source picker did not open with Auto and detected apps'
Set-OrbitExpanded $false
Assert $script:expanded 'Notch closed while choosing a music app'
$script:musicSourceMenu.Items[1].RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.MenuItem]::ClickEvent))
Assert ($script:orbySettings.MediaApp -eq 'AppleMusic.exe' -and $null -eq $script:orbyShared.SelectedMusic) 'Source picker did not save the chosen app or clear old media'
$script:musicSourceMenu.IsOpen=$false
for($i=0;$i -lt 12;$i++){foreach($p in @('home','agents','settings','music')){Set-OrbyHomePage $p;Layout;Assert ($expandedArea.ActualWidth -eq 596) 'Menu width changed between tabs'}}
$script:orbySettings.ProviderEnabled='chatgpt,claude,gemini';Set-OrbyHomePage 'home';Layout
Assert ($script:providerCards.Count -eq 3 -and $script:compactMenus.Height -eq 342) 'Third provider did not fit'
$script:expanded=$false;Update-OrbyCompactMenus
foreach($a in $script:compactMenuAvatars.Values){Assert $a.Renderer.Suspended 'Hidden menu avatar kept rendering'}
$script:orbyEventMode='attention';Update-OrbyCompactMenus
Assert ($notch.ExpandedWidth -eq 620 -and $expandedArea.Width -eq 596 -and $script:compactMenus.Visibility -eq 'Collapsed') 'Permission overlay was clipped or covered by compact menu'
$script:orbyEventMode='';Update-OrbyCompactMenus
Assert ($notch.ExpandedWidth -eq 620 -and $expandedArea.Width -eq 596 -and $script:compactMenus.Visibility -eq 'Visible') 'Menu did not recover after permission overlay'
$script:dropPanel=[Windows.Controls.Grid]::new();$script:dropPanel.Visibility='Visible';Update-OrbyCompactMenus
Assert ($notch.ExpandedWidth -eq 620) 'File-drop composer was clipped'
$script:dropPanel.Visibility='Collapsed';Update-OrbyCompactMenus
Assert ($notch.ExpandedWidth -eq 620) 'Drop composer did not restore compact body'
$script:orbyEventMode='';$script:dropPanel.Visibility='Collapsed';$script:expanded=$true
$script:orbySettings.ProviderEnabled='chatgpt,claude';$script:orbySettings.ReducedMotion=$true
Set-OrbyHomePage 'home';$notch.Morph=1;$notch.Attach($window);Layout
function Check-MenuFits {
 Layout
 $baseHeight=[double]$notch.GetAnimationBaseValue([OrbyLiquidSurface]::ExpandedHeightProperty)
 Assert ($baseHeight -eq $script:compactMenus.Height+14) 'Background update reset the expanded notch height'
 $elements=@($script:compactMenuControls.MenuFooter,$script:compactMenuControls.MenuHealth)
 foreach($card in $script:providerCards.Values){if($script:multiHome.Children.Contains($card.View)){$elements+=@($card.Controls.Name,$card.Controls.Title,$card.Controls.Detail,$card.Controls.BuddyRow)}}
 foreach($element in $elements){
  if(-not $element.ActualWidth -or -not $element.ActualHeight){continue}
  foreach($xy in @(@(1,1),@(($element.ActualWidth-1),1),@(1,($element.ActualHeight-1)),@(($element.ActualWidth-1),($element.ActualHeight-1)))){
   $point=$element.TranslatePoint([Windows.Point]::new($xy[0],$xy[1]),$notch)
   Assert ($notch.Clip.FillContains($point)) ('Visible menu content falls outside notch shape: '+$element.Name)
  }
 }
}
for($i=0;$i -lt 20;$i++){Update-OrbyMultiProvider;Check-MenuFits}
$script:orbySettings.ProviderEnabled='chatgpt,claude,gemini';Update-OrbyMultiProvider;Check-MenuFits
$script:orbySettings.ProviderEnabled='chatgpt,claude';Set-OrbyHomePage 'home';Update-OrbyMultiProvider;Check-MenuFits
# Render the actual clipped surface, rather than an unclipped VisualBrush of its content.
if($PreviewDirectory){
 $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new(668,230,96,96,[Windows.Media.PixelFormats]::Pbgra32);$bitmap.Render($window.Content)
 $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
 $stream=[IO.File]::Create((Join-Path $PreviewDirectory 'Home-actual-notch.png'));try{$encoder.Save($stream)}finally{$stream.Dispose()}
}
$window.Close();"PASS: $script:assertions checks including repeated background updates, three providers and content inside the real notch clip"