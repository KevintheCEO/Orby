$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework
Add-Type -Path @((Join-Path $PSScriptRoot 'Liquid-Surface.cs'),(Join-Path $PSScriptRoot 'Monitor-Layout.cs')) -ReferencedAssemblies WindowsBase,PresentationCore,PresentationFramework,System.Xaml
foreach($scale in 1,1.25,1.5,2){
 $left=[OrbyMonitorLayout]::Center(1920,2560,640,$scale)
 $physical=$left*$scale
 if([math]::Abs(($physical+320*$scale)-(1920+1280)) -gt 0.51){throw 'Monitor centering drift'}
 [xml]$x=Get-Content (Join-Path $PSScriptRoot 'Reference-Home.xaml') -Raw
 $ui=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($x));$ui.Width=600
 $ui.Measure([Windows.Size]::new(616,180));$ui.Arrange([Windows.Rect]::new(0,0,616,180));$ui.UpdateLayout()
 $b=[Windows.Media.Imaging.RenderTargetBitmap]::new([int](616*$scale),[int](180*$scale),96*$scale,96*$scale,[Windows.Media.PixelFormats]::Pbgra32);$b.Render($ui)
 if($b.PixelWidth -ne [int](616*$scale)){throw 'Render resolution mismatch'}
}
'PASS: monitor centering and native layout/render at 100%, 125%, 150%, 200%.'
