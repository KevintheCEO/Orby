$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework
Add-Type -Path (Join-Path $PSScriptRoot 'Coucou-Motion.cs') -ReferencedAssemblies WindowsBase,PresentationCore,PresentationFramework
Add-Type -Path (Join-Path $PSScriptRoot 'Liquid-Surface.cs') -ReferencedAssemblies WindowsBase,PresentationCore,PresentationFramework,System.Xaml
[xml]$x='<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Width="300" Height="100"><Grid><Grid x:Name="CompactHeader"/></Grid></Window>'
$window=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($x));$window.ShowActivated=$false;$window.Show()
$notch=[OrbyLiquidSurface]::new();$expandedArea=[Windows.Controls.Grid]::new();$script:hoverExitTimer=[Windows.Threading.DispatcherTimer]::new()
function Write-OrbitLog($text){};function Position-Orbit {};function Set-OrbyAlbumPlacement($expanded){}
$script:orbySettings=@{HideFullscreen=$true}
. (Join-Path $PSScriptRoot 'Fullscreen-Guard.ps1')
$script:fullscreenTimer.Stop()
$m=[OrbyFullscreen+Rect]::new();$m.Right=1920;$m.Bottom=1080
if(-not [OrbyFullscreen]::Covers($m,$m)){throw 'Fullscreen not recognized'}
$r=$m;$r.Bottom=1040;if([OrbyFullscreen]::Covers($r,$m)){throw 'Maximized working area treated as fullscreen'}
$client=$m;$client.Top=32
if([OrbyFullscreen]::IsFullscreen($m,$client,$m)){throw 'Title-bar window incorrectly recognized as fullscreen'}
if(-not [OrbyFullscreen]::IsFullscreen($m,$m,$m)){throw 'Borderless fullscreen was missed'}
if([OrbyFullscreen]::ShouldHide($m,$m,$m,$true,$true,$false)){throw 'Maximized app hidden with auto-hide taskbar'}
if([OrbyFullscreen]::ShouldHide($m,$m,$m,$false,$false,$false)){throw 'Other-monitor game hid Orby'}
if([OrbyFullscreen]::ShouldHide($m,$m,$m,$true,$false,$true)){throw 'Screenshot overlay treated as game'}
if(-not [OrbyFullscreen]::IsTransient('SnippingTool','')){throw 'Screenshot overlay not excluded'}
if(-not [OrbyFullscreen]::ShouldHide($m,$m,$m,$true,$false,$false)){throw 'True full-screen content missed'}
$window.Opacity=0
Set-OrbyFullscreenHidden $true
if($window.IsVisible -or -not $script:fullscreenHidden){throw 'Not hidden'}
Set-OrbyFullscreenHidden $false
if(-not $window.IsVisible -or $script:fullscreenHidden -or $notch.Morph -ne 0){throw 'Not restored collapsed'}
if($window.Opacity -ne 1 -or -not $window.Topmost){throw 'Restore remained transparent or behind apps'}
# Enter fullscreen while an expansion spring is running, then return immediately.
[OrbyMotion.Driver]::Move($notch,[OrbyLiquidSurface]::MorphProperty,1,$true)
Set-OrbyFullscreenHidden $true;Set-OrbyFullscreenHidden $false
$frame=[Windows.Threading.DispatcherFrame]::new();$timer=[Windows.Threading.DispatcherTimer]::new();$timer.Interval=[timespan]::FromMilliseconds(700);$timer.Add_Tick({$timer.Stop();$frame.Continue=$false});$timer.Start();[Windows.Threading.Dispatcher]::PushFrame($frame)
if($notch.Morph -ne 0 -or $expandedArea.Visibility -ne 'Collapsed' -or $expandedArea.Opacity -ne 0){throw 'Old expansion animation overwrote restored compact surface'}
function Get-OrbyFullscreenObservation {$script:fixture}
$script:fixture=[pscustomobject]@{Foreground=101L;Fullscreen=$true;Transient=$false}
$now=[datetime]::UtcNow;Update-OrbyFullscreenGuard $now;Update-OrbyFullscreenGuard ($now.AddMilliseconds(650))
if(-not $script:fullscreenHidden){throw 'Stable game not hidden'}
$script:fixture=[pscustomobject]@{Foreground=102L;Fullscreen=$false;Transient=$true};Update-OrbyFullscreenGuard ($now.AddSeconds(1))
if(-not $script:fullscreenHidden){throw 'Screenshot overlay revealed Orby over a game'}
$script:fixture=[pscustomobject]@{Foreground=103L;Fullscreen=$false;Transient=$false};Update-OrbyFullscreenGuard ($now.AddSeconds(2));Update-OrbyFullscreenGuard ($now.AddSeconds(2.7))
if($script:fullscreenHidden -or -not $window.IsVisible){throw 'Normal app did not restore Orby'}
if($script:fullscreenRaisedForeground -ne 103){throw 'Normal foreground recovery was skipped'}
$script:fixture | Add-Member NoteProperty Geometry 'normal-after-F11'
Update-OrbyFullscreenGuard ($now.AddSeconds(2.8))
if($script:fullscreenRaisedForeground -ne 0){throw 'Same-window layout transition did not schedule recovery'}
Update-OrbyFullscreenGuard ($now.AddSeconds(3.5))
if($script:fullscreenRaisedForeground -ne 103){throw 'Same-window full-screen exit did not repair stacking'}
$script:orbySettings.HideFullscreen=$false;$script:fixture.Fullscreen=$true;Update-OrbyFullscreenGuard ($now.AddSeconds(3))
if($script:fullscreenHidden){throw 'Disabled preference still hid Orby'}
1..3 | ForEach-Object {Set-OrbyFullscreenHidden $true;Set-OrbyFullscreenHidden $false;if(-not $window.IsVisible){throw 'Repeat restore failed'}}
$window.Close()
'PASS: fullscreen bounds, maximized exclusion, hidden state and collapsed restoration.'
