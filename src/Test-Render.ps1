param([switch]$Water)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Xaml,System.Windows.Forms
. (Join-Path $PSScriptRoot 'Orb-Avatar.ps1')
. (Join-Path $PSScriptRoot 'Motion.ps1')
Add-Type -Path @((Join-Path $PSScriptRoot 'Native-Avatar.cs'),(Join-Path $PSScriptRoot 'Hydration-Avatar.cs'),(Join-Path $PSScriptRoot 'Rendered-Assets.cs'),(Join-Path $PSScriptRoot 'Hydration-Model.cs'),(Join-Path $PSScriptRoot 'Animation-Catalog.cs')) -ReferencedAssemblies @('WindowsBase','PresentationCore','PresentationFramework','System.Xaml')
$parts=New-OrbitAvatar
$renderer=New-Object OrbyAvatarRenderer ($parts)
if($Water){$renderer.SetState('idle','');$renderer.WaterProgress=.08;[void]$renderer.Trigger('water_reminder')}else{$renderer.SetState('working','Thinking')}
$window=New-Object Windows.Window;$window.Topmost=$true;$window.Width=454;$window.Height=180;$window.Content=$parts.Root;$window.ShowActivated=$false
$timer=New-Object Windows.Threading.DispatcherTimer;$timer.Interval=[timespan]::FromSeconds($(if($Water){10}else{8}))
$timer.Add_Tick({$timer.Stop();$window.Close()})
$window.Add_ContentRendered({$timer.Start()})
[void]$window.ShowDialog()
$renderer.Dispose()
"RefreshHz=$([OrbyDisplay]::RefreshHz([Windows.Forms.Screen]::PrimaryScreen.DeviceName)) FPS=$([math]::Round($renderer.ObservedFps,1)) P95ms=$([math]::Round($renderer.P95FrameMs,1)) maxMs=$([math]::Round($renderer.MaxFrameGapMs,1)) frames=$($renderer.Frames)"

