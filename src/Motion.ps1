Add-Type -AssemblyName System.Windows.Forms
function Invoke-OrbyMotion {
    param([Windows.DependencyObject]$Target,[Windows.DependencyProperty]$Property,[double]$To,[double]$Seconds=0.25,[double]$Delay=0)
    [OrbyMotion.Transitions]::MoveAfter($Target,$Property,$To,$Seconds,$script:displayHz,([bool]$script:orbySettings.ReducedMotion -or -not [Windows.SystemParameters]::ClientAreaAnimation),$Delay)
}


Add-Type -Path (Join-Path $PSScriptRoot 'Coucou-Motion.cs') -ReferencedAssemblies @('WindowsBase','PresentationCore','PresentationFramework')

$privateRoot=Join-Path $PSScriptRoot 'Personal'
$script:orbyPrivateWater=(Test-Path (Join-Path $privateRoot 'Hydration-Avatar.cs')) -and (Test-Path (Join-Path $privateRoot 'Animation-Catalog.cs')) -and (Test-Path (Join-Path $privateRoot 'Water-Preview.ps1'))
$extraRoot=if($script:orbyPrivateWater){$privateRoot}else{$PSScriptRoot}
$avatarSources=@((Join-Path $PSScriptRoot 'Native-Avatar.cs'),(Join-Path $extraRoot 'Hydration-Avatar.cs'),(Join-Path $PSScriptRoot 'Rendered-Assets.cs'),(Join-Path $extraRoot 'Animation-Catalog.cs'))
if($script:orbyPrivateWater){$avatarSources+=Join-Path $privateRoot 'Hydration-Model.cs'}
Add-Type -Path $avatarSources -ReferencedAssemblies @('WindowsBase','PresentationCore','PresentationFramework','System.Xaml')
$script:displayHz=[OrbyDisplay]::RefreshHz([Windows.Forms.Screen]::PrimaryScreen.DeviceName)


Add-Type -Path (Join-Path $PSScriptRoot 'Refresh-Clock.cs') -ReferencedAssemblies @('WindowsBase','PresentationCore','PresentationFramework')
[OrbyRefreshClock]::Configure($script:displayHz)


[OrbyRenderedAssets]::Configure($PSScriptRoot)
