param([switch]$Water)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Xaml,System.Windows.Forms
. (Join-Path $PSScriptRoot 'Orb-Avatar.ps1')
. (Join-Path $PSScriptRoot 'Motion.ps1')
Add-Type -Path @((Join-Path $PSScriptRoot 'Native-Avatar.cs'),(Join-Path $PSScriptRoot 'Hydration-Avatar.cs'),(Join-Path $PSScriptRoot 'Rendered-Assets.cs'),(Join-Path $PSScriptRoot 'Hydration-Model.cs'),(Join-Path $PSScriptRoot 'Animation-Catalog.cs')) -ReferencedAssemblies @('WindowsBase','PresentationCore','PresentationFramework','System.Xaml')
$parts=New-OrbitAvatar
$renderer=New-Object OrbyAvatarRenderer ($parts)
if($Water){$renderer.SetState('idle','');$renderer.WaterProgress=.08;[void]$renderer.Trigger('water_reminder')}else{$renderer.SetState('idle','');[void]$renderer.Trigger('star_eyes')}
$renderer.StatusConnected=$true;$renderer.SetState('idle','');$renderer.Draw(10)
if($parts.OrbLed.Fill.Color.G -lt 150){throw 'Connected not green'}
$renderer.SetState('working','Thinking');$renderer.Draw(11);$a=$parts.OrbLed.RenderTransform.X;$renderer.Draw(11.2)
if($renderer.VisibleParticleCount -ne 0){throw 'Duplicate working particles'}
if([math]::Abs($a-$parts.OrbLed.RenderTransform.X) -lt .1){throw 'Dot not moving'}
$renderer.SetState('attention','');foreach($t in 12,12.1,12.2,12.3){$renderer.Draw($t)}
if($parts.OrbLed.Fill.Color.R -lt 150){throw 'Amber missing'}
$renderer.WaterPriority=$true;$renderer.Draw(13)
if($parts.OrbLed.Opacity -ne 0){throw 'Dot overlays water'}
$renderer.Dispose()
'PASS: one moving working indicator, idle green, amber attention, water priority.'

