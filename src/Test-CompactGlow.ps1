$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework
Add-Type -Path (Join-Path $PSScriptRoot 'Liquid-Surface.cs') -ReferencedAssemblies WindowsBase,PresentationCore,PresentationFramework,System.Xaml
$surface=[OrbyLiquidSurface]::new();$surface.SetArtworkAccent([Windows.Media.Color]::FromRgb(20,210,30),$true,$false)
$w=[Windows.Window]::new();$w.Width=650;$w.Height=120;$w.Content=$surface;$w.ShowActivated=$false
$t=[Windows.Threading.DispatcherTimer]::new();$t.Interval=[timespan]::FromSeconds(1)
$t.Add_Tick({
 $t.Stop();$b=[Windows.Media.Imaging.RenderTargetBitmap]::new(620,58,96,96,[Windows.Media.PixelFormats]::Pbgra32);$b.Render($surface);$pixel=New-Object byte[] 4;$b.CopyPixels([Windows.Int32Rect]::new(425,24,1,1),$pixel,4,0)
 if($pixel[1] -le $pixel[2]){throw 'Album color missing from collapsed surface'}
 $surface.SetArtworkAccent([Windows.Media.Colors]::Green,$false,$false)
 if($surface.ArtworkAccentVisible){throw 'Glow remained visible'}
 $w.Close()
});$w.Add_ContentRendered({$t.Start()});[void]$w.ShowDialog()
'PASS: rendered collapsed surface uses album hue; glow disable clears visibility.'
