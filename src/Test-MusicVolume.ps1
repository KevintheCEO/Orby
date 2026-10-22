$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework
Add-Type -Path (Join-Path $PSScriptRoot 'Output-Volume.cs')
$v=[OrbyOutputVolume]::Get()
if($v -lt 0 -or $v -gt 100){throw 'Invalid output volume'}
[OrbyOutputVolume]::Set($v)
if([math]::Abs([OrbyOutputVolume]::Get()-$v) -gt 1){throw 'Volume read/write mismatch'}
[xml]$x=Get-Content (Join-Path $PSScriptRoot 'Reference-Home.xaml') -Raw
$ui=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($x));$ui.Width=600
$ui.FindName('RefHomePage').Visibility='Collapsed';$ui.FindName('RefMusicPage').Visibility='Visible'
$ui.Measure([Windows.Size]::new(616,180));$ui.Arrange([Windows.Rect]::new(0,0,616,180));$ui.UpdateLayout()
$slider=$ui.FindName('RefMusicVolume');$pos=$slider.TransformToAncestor($ui).Transform([Windows.Point]::new(0,0))
if($slider.ActualWidth -lt 100 -or $pos.Y+$slider.ActualHeight -gt 162){throw 'Volume slider clipped'}
'PASS: native output volume read/write (same level preserved), music volume layout visible.'
