$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework
. (Join-Path $PSScriptRoot 'Panel-Layers.ps1')
function Assert($ok,$message){if(-not $ok){throw $message}}
function Invoke-OrbyMotion($target,$property,$to,$seconds){$target.BeginAnimation($property,$null);$target.SetValue($property,[double]$to)}
$header=[Windows.Controls.Grid]::new()
$fade=[Windows.Media.Animation.DoubleAnimation]::new(1,0,[Windows.Duration]::new([timespan]::FromSeconds(2)))
$header.BeginAnimation([Windows.UIElement]::OpacityProperty,$fade)
Set-OrbyCompactLayer $header $true
Assert ($header.Opacity -eq 0 -and -not $header.HasAnimatedProperties) 'Compact text keeps fading behind expanded UI'
Set-OrbyCompactLayer $header $false
Assert ($header.Opacity -eq 1) 'Compact text was not restored'
[xml]$x=Get-Content (Join-Path $PSScriptRoot 'Reference-Home.xaml') -Raw
$panelRoot=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($x))
$script:referenceControls=@{RefConnection=$panelRoot.FindName('RefConnection')}
Set-OrbyEventUnderlay $true
Assert ($script:referenceControls.RefConnection.Visibility -eq 'Collapsed') 'Home footer leaks below permission card'
Set-OrbyEventUnderlay $false
Assert ($script:referenceControls.RefConnection.Visibility -eq 'Visible') 'Home footer was not restored'
Write-Output 'PASS: immediate compact-layer removal, old fade cancellation, overlay footer hiding and restoration.'
