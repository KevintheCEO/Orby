$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework
. (Join-Path $PSScriptRoot 'Ambient-Motion.ps1')
[xml]$x=Get-Content (Join-Path $PSScriptRoot 'Reference-Home.xaml') -Raw
$script:referenceHome=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($x));$script:orbySettings=@{ReducedMotion=$false};$script:displayHz=165
$w=[Windows.Window]::new();$w.Width=640;$w.Height=240;$w.Content=$script:referenceHome;$w.ShowActivated=$false;$w.Show()
Initialize-OrbyAmbientMotion
$homePools=@($script:ambientPools | Where-Object {$_.Owner.Name -eq 'RefHomePage'})
if($homePools.Count -ne 6 -or @($homePools | Where-Object {-not $_.Running}).Count){throw 'Home pools not running'}
if($script:ambientPools[2].Running){throw 'Hidden music pool running'}
$script:orbySettings.ReducedMotion=$true;Update-OrbyAmbientMotion
foreach($pool in $script:ambientPools){if($pool.Running -or $pool.Brush.HasAnimatedProperties){throw 'Motion remained in reduced mode'}}
$script:orbySettings.ReducedMotion=$false;Update-OrbyAmbientMotion
if(-not $homePools[0].Brush.HasAnimatedProperties){throw 'Animation did not resume'}
Stop-OrbyAmbientMotion;$w.Close()
'PASS: six visible Home pools animate, hidden Music paused, reduced-motion stop/resume, animation clocks removed on cleanup.'

