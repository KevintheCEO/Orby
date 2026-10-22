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
$script:orbySettings.ReducedMotion=$true;$window.Show();Set-OrbyHomePage 'settings';Layout
$u=$script:compactMenuControls
function Bounds($control,$relative){$p=$control.TranslatePoint([Windows.Point]::new(0,0),$relative);[Windows.Rect]::new($p.X,$p.Y,$control.ActualWidth,$control.ActualHeight)}
$toggle=Bounds $u.QuickReducedMotion $script:compactMenus
$connections=Bounds $u.QuickConnections $script:compactMenus
$music=Bounds $u.QuickMusicApp $script:compactMenus
$save=Bounds $u.QuickSave $script:compactMenus
$more=Bounds $u.MoreSettings $script:compactMenus
Assert ($connections.Top-$toggle.Bottom -ge 12) 'No breathing room after Reduced motion'
Assert ($save.Top-$connections.Bottom -ge 12) 'Save row is pressed against connection actions'
Assert ($music.Left-$connections.Right -ge 12) 'Connection buttons touch'
Assert ([math]::Abs($connections.Top-$music.Top) -lt .1) 'Connection actions do not align'
Assert ([math]::Abs($more.Top-$save.Top) -lt .1) 'Bottom actions do not align'
foreach($name in @('QuickSave','MoreSettings','QuickMusicApp','QuickConnections')){
 $b=Bounds $u[$name] $script:compactMenus
 Assert ($b.Height -ge 36 -and $b.Bottom -le $script:compactMenus.Height-25) ('Settings action is cramped or clipped: '+$name)
}
$u.QuickConnections.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent));Assert $script:connectionsClicked 'AI connection handler was lost'
$u.MoreSettings.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent));Assert $script:moreClicked 'More settings handler was lost'
$u.QuickMusicApp.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent));Assert ($script:compactMenuPage -eq 'music') 'Music app handler was lost'
Set-OrbyHomePage 'settings';$u.QuickSounds.IsChecked=$true
$u.QuickSave.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert ($script:orbySettings.Sounds -and $u.SettingsNote.Text -eq 'Saved') 'Settings save or confirmation was lost'
Capture 'settings-roomy'
# Full settings uses a scrollable body and permanently visible Save/Close actions.
[xml]$xml=Get-Content (Join-Path $PSScriptRoot 'Settings.xaml') -Raw
$full=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($xml));$full.ShowActivated=$false;$full.Show()
function Find-Scroll($node){if($node -is [Windows.Controls.ScrollViewer]){return $node};foreach($child in [Windows.LogicalTreeHelper]::GetChildren($node)){if($child -is [Windows.DependencyObject]){$r=Find-Scroll $child;if($r){return $r}}}}
$scroll=Find-Scroll $full.Content
foreach($size in @(@(590,480),@(640,760),@(820,600))){
 $full.Width=$size[0];$full.Height=$size[1];$full.UpdateLayout()
 $relative=$full.Content;$before=Bounds $full.FindName('SaveSettings') $relative
 $scroll.ScrollToEnd();$full.UpdateLayout();$after=Bounds $full.FindName('SaveSettings') $relative
 Assert ([math]::Abs($before.Y-$after.Y) -lt .1) 'Save button moved out of view with settings scroll'
 Assert ($after.Bottom -le $relative.ActualHeight -and $after.Height -ge 30) 'Full settings Save is outside the window'
 $close=Bounds $full.FindName('CloseSettings') $relative
 Assert ($close.Bottom -le $relative.ActualHeight -and -not $close.IntersectsWith($after)) 'Full settings Close overlaps Save or is outside the window'
 $scroll.ScrollToTop();$full.UpdateLayout()
}
Assert ($full.ResizeMode -eq 'CanResize') 'Full settings cannot be resized'
Assert ($full.FindName('AIConnections') -and $full.FindName('MediaApp') -and $full.FindName('EnableReducedMotion')) 'Full settings controls missing'
$picker=$full.FindName('MediaApp');$picker.ItemsSource=@([pscustomobject]@{Id='auto';Name='Automatic'},[pscustomobject]@{Id='test-player';Name='Sample music player'})
$picker.SelectedIndex=0;$full.UpdateLayout();$picker.IsDropDownOpen=$true;$full.UpdateLayout();$picker.SelectedIndex=1;$picker.IsDropDownOpen=$false
Assert ($picker.SelectedValue -eq 'test-player') 'Styled music picker lost its selected value'
$full.FindName('EnableReducedMotion').IsChecked=$true;$full.UpdateLayout()
Assert ($full.FindName('EnableReducedMotion').IsChecked) 'Styled checkbox lost its state'
if($PreviewDirectory){
 $full.Width=640;$full.Height=760;$full.UpdateLayout()
 $bmp=[Windows.Media.Imaging.RenderTargetBitmap]::new([int]$full.ActualWidth,[int]$full.ActualHeight,96,96,[Windows.Media.PixelFormats]::Pbgra32);$bmp.Render($full.Content)
 $enc=[Windows.Media.Imaging.PngBitmapEncoder]::new();$enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bmp));$fs=[IO.File]::Create((Join-Path $PreviewDirectory 'more-settings.png'));try{$enc.Save($fs)}finally{$fs.Dispose()}
}
$script:orbyShared.SelectedMusic=$null;$script:referenceControls.RefMusicCover.Source=$null;Set-OrbyHomePage 'music'
Assert ($u.MusicTint.Color.A -eq 0) 'Old album glow remained behind an empty music player'
$full.Close();$window.Close();"PASS: $script:assertions settings spacing, live actions, pinned footer, resize and empty-player glow checks"
