param([switch]$Water)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Xaml,System.Windows.Forms
. (Join-Path $PSScriptRoot 'Orb-Avatar.ps1')
. (Join-Path $PSScriptRoot 'Motion.ps1')
Add-Type -Path @((Join-Path $PSScriptRoot 'Native-Avatar.cs'),(Join-Path $PSScriptRoot 'Hydration-Avatar.cs'),(Join-Path $PSScriptRoot 'Rendered-Assets.cs'),(Join-Path $PSScriptRoot 'Hydration-Model.cs'),(Join-Path $PSScriptRoot 'Animation-Catalog.cs')) -ReferencedAssemblies @('WindowsBase','PresentationCore','PresentationFramework','System.Xaml')
$parts=New-OrbitAvatar
$renderer=New-Object OrbyAvatarRenderer ($parts)
if($Water){$renderer.SetState('idle','');$renderer.WaterProgress=.08;[void]$renderer.Trigger('water_reminder')}else{$renderer.SetState('idle','');[void]$renderer.Trigger('star_eyes')}
$renderer.Dispose()
foreach($id in [OrbyAvatarRenderer]::EyeStyles){
 $a=New-OrbitAvatar;$r=[OrbyAvatarRenderer]::new($a);$r.SetState('idle','');if(-not $r.Trigger($id)){throw "Trigger failed $id"};$r.Draw($r.TimeSeconds+1)
 if($r.ActiveId -ne $id){throw "Wrong style $id"}
  $a.Root.Measure([Windows.Size]::new(54,54));$a.Root.Arrange([Windows.Rect]::new(0,0,54,54));$a.Root.UpdateLayout()
 $bmp=[Windows.Media.Imaging.RenderTargetBitmap]::new(216,216,384,384,[Windows.Media.PixelFormats]::Pbgra32);$bmp.Render($a.Root)
 $enc=[Windows.Media.Imaging.PngBitmapEncoder]::new();$enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bmp));$stream=[IO.File]::Create((Join-Path $PSScriptRoot ($id+'.png')));$enc.Save($stream);$stream.Close()
 $r.EyeEffects=$false;$r.Draw($r.TimeSeconds+1.1)
 if($r.ActiveId -ne 'idle_neutral' -or $a.OrbEyeL.Fill.Color.B -gt 30){throw "Disabled style remained $id"}
 if($r.Trigger($id)){throw 'Disabled trigger accepted'}
 $r.Dispose()
}
[xml]$x=Get-Content (Join-Path $PSScriptRoot 'Settings.xaml') -Raw
$ui=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($x))
if(-not $ui.FindName('EnableEyeEffects')){throw 'Settings switch missing'}
'PASS: six styles render, immediate disable restores default, disabled triggers blocked, settings switch loads.'

