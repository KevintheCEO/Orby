$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework
Add-Type -Path (Join-Path $PSScriptRoot 'Liquid-Surface.cs') -ReferencedAssemblies WindowsBase,PresentationCore,PresentationFramework,System.Xaml
Add-Type @'
using System;using System.Runtime.InteropServices;
public static class ShapeTest {
 [DllImport("gdi32.dll")]public static extern IntPtr CreateRectRgn(int a,int b,int c,int d);
 [DllImport("user32.dll")]public static extern int GetWindowRgn(IntPtr h,IntPtr r);
 [DllImport("gdi32.dll")]public static extern bool PtInRegion(IntPtr r,int x,int y);
 [DllImport("gdi32.dll")]public static extern bool DeleteObject(IntPtr r);
}
'@
$surface=[OrbyLiquidSurface]::new()
foreach($width in @(360,800)){
 $surface.ReserveWidth($width);$surface.CompactWidth=$width
 foreach($phase in @(0,.25,.5,.75,1,1.02)){
  $surface.Morph=$phase;$bounds=$surface.Clip.Bounds;$bodyLeft=$bounds.Left+18
  if(-not $surface.Clip.FillContains([Windows.Point]::new($bodyLeft-10,1))){throw 'Shoulder lip missing'}
  if($surface.Clip.FillContains([Windows.Point]::new($bodyLeft-10,15))){throw 'Outer corner is convex instead of concave'}
  if(-not $surface.Clip.FillContains([Windows.Point]::new($bodyLeft+1,25))){throw 'Body narrowed into content'}
  foreach($scale in @(1,1.25,1.5,2)){
   $surface.Measure([Windows.Size]::new($surface.Width,374));$surface.Arrange([Windows.Rect]::new(0,0,$surface.Width,374))
   $bmp=[Windows.Media.Imaging.RenderTargetBitmap]::new([int]($surface.Width*$scale),[int](374*$scale),96*$scale,96*$scale,[Windows.Media.PixelFormats]::Pbgra32);$bmp.Render($surface)
  }
 }
}
$window=[Windows.Window]::new();$window.WindowStyle='None';$window.AllowsTransparency=$true;$window.Background=[Windows.Media.Brushes]::Transparent;$window.ShowActivated=$false;$window.Height=384;$window.Content=$surface
$surface.ReserveWidth(620);$surface.CompactWidth=360;$surface.Morph=1
$window.Show();$surface.Attach($window);$window.UpdateLayout()
$handle=[Windows.Interop.WindowInteropHelper]::new($window).Handle;$region=[ShapeTest]::CreateRectRgn(0,0,0,0)
try{
 if([ShapeTest]::GetWindowRgn($handle,$region) -eq 0){throw 'Native notch region absent'}
 $scale=[Windows.PresentationSource]::FromVisual($window).CompositionTarget.TransformToDevice.M11
 if(-not [ShapeTest]::PtInRegion($region,[int](14*$scale),[int]$scale)){throw 'Native region clipped flared lip'}
 if([ShapeTest]::PtInRegion($region,[int](14*$scale),[int](16*$scale))){throw 'Transparent shoulder intercepts clicks'}
 if(-not [ShapeTest]::PtInRegion($region,[int](30*$scale),[int](30*$scale))){throw 'Native body clipped'}
}finally{[void][ShapeTest]::DeleteObject($region);$window.Close()}
'PASS: concave shoulders, preserved body, animation phases, 100/125/150/200% rendering and native click region.'
