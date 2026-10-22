param([switch]$Water)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Xaml,System.Windows.Forms
. (Join-Path $PSScriptRoot 'Orb-Avatar.ps1')
. (Join-Path $PSScriptRoot 'Motion.ps1')
Add-Type -Path @((Join-Path $PSScriptRoot 'Native-Avatar.cs'),(Join-Path $PSScriptRoot 'Hydration-Avatar.cs'),(Join-Path $PSScriptRoot 'Rendered-Assets.cs'),(Join-Path $PSScriptRoot 'Hydration-Model.cs'),(Join-Path $PSScriptRoot 'Animation-Catalog.cs')) -ReferencedAssemblies @('WindowsBase','PresentationCore','PresentationFramework','System.Xaml')
$parts=New-OrbitAvatar
$renderer=New-Object OrbyAvatarRenderer ($parts)
if($Water){$renderer.SetState('idle','');$renderer.WaterProgress=.08;[void]$renderer.Trigger('water_reminder')}else{$renderer.SetState('idle','');[void]$renderer.Trigger('star_eyes')}
$start=$renderer.TimeSeconds
$renderer.Draw($start+1)
if($renderer.ActiveId -ne 'star_eyes'){throw 'Star clip missing'}
if($parts.OrbEyeL.Fill.Color.B -lt 150){throw 'Cyan eyes missing'}
$parts.Root.Measure([Windows.Size]::new(54,54));$parts.Root.Arrange([Windows.Rect]::new(0,0,54,54));$parts.Root.UpdateLayout()
$renderer.Draw($start+4.5)
if($renderer.ActiveId -ne 'idle_neutral'){throw 'Default not restored'}
if($parts.OrbEyeL.Fill.Color.B -gt 30){throw 'Eye color not restored'}
$renderer.SetState('working','Thinking')
if($renderer.Trigger('star_eyes')){throw 'Star interrupts work'}
$renderer.SetState('idle','');$renderer.WaterPriority=$true;[void]$renderer.Trigger('water_reminder')
if($renderer.Trigger('star_eyes')){throw 'Star interrupts water'}
$renderer.Dispose()
'PASS: cyan star eyes, automatic default restoration, work and water priority.'
