Add-Type -AssemblyName System.Windows.Forms
function Invoke-OrbyMotion {
    param([Windows.DependencyObject]$Target,[Windows.DependencyProperty]$Property,[double]$To,[double]$Seconds=0.25)
    $from=[double]$Target.GetValue($Property)
    $Target.BeginAnimation($Property,$null)
    $Target.SetValue($Property,$To)
    $animation=New-Object Windows.Media.Animation.DoubleAnimation
    if($script:displayHz -gt 0){[Windows.Media.Animation.Timeline]::SetDesiredFrameRate($animation,$script:displayHz)}
    $animation.From=$from;$animation.To=$To
    $animation.Duration=New-Object Windows.Duration ([timespan]::FromSeconds($Seconds))
    $ease=New-Object Windows.Media.Animation.CubicEase
    $ease.EasingMode=[Windows.Media.Animation.EasingMode]::EaseOut
    $animation.EasingFunction=$ease
    $animation.FillBehavior=[Windows.Media.Animation.FillBehavior]::Stop
    $Target.BeginAnimation($Property,$animation,[Windows.Media.Animation.HandoffBehavior]::SnapshotAndReplace)
}


Add-Type -Path (Join-Path $PSScriptRoot 'Coucou-Motion.cs') -ReferencedAssemblies @('WindowsBase','PresentationCore','PresentationFramework')

Add-Type -Path @((Join-Path $PSScriptRoot 'Native-Avatar.cs'),(Join-Path $PSScriptRoot 'Animation-Catalog.cs')) -ReferencedAssemblies @('WindowsBase','PresentationCore','PresentationFramework','System.Xaml')
$script:displayHz=[OrbyDisplay]::RefreshHz([Windows.Forms.Screen]::PrimaryScreen.DeviceName)

