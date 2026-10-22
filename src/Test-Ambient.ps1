$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework
. (Join-Path $PSScriptRoot 'Reference-Home.ps1')
$bytes=New-Object byte[] (16*16*4)
for($i=0;$i -lt $bytes.Length;$i+=4){$bytes[$i]=20;$bytes[$i+1]=200;$bytes[$i+2]=30;$bytes[$i+3]=255}
$b=[Windows.Media.Imaging.BitmapSource]::Create(16,16,96,96,[Windows.Media.PixelFormats]::Bgra32,$null,$bytes,64)
$c=Get-OrbyArtworkAccent $b
if($c.G -lt 190 -or $c.R -gt 40 -or $c.A -ge 255){throw 'Artwork accent mismatch'}
[xml]$x=Get-Content (Join-Path $PSScriptRoot 'Reference-Home.xaml') -Raw
$ui=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($x))
if(-not $ui.FindName('RefOrbGlow') -or -not $ui.FindName('RefMusicAmbient')){throw 'Missing ambient bindings'}
'PASS: green artwork produces green translucent light; ambient controls load.'
