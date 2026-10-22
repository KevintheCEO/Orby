param([string]$PreviewPath)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Xaml,System.Windows.Forms
. (Join-Path $PSScriptRoot 'Orb-Avatar.ps1')
. (Join-Path $PSScriptRoot 'Motion.ps1')
. (Join-Path $PSScriptRoot 'Task-Avatars.ps1')
[xml]$x=Get-Content (Join-Path $PSScriptRoot 'Reference-Home.xaml') -Raw
$script:referenceHome=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($x))
$script:referenceControls=@{RefOrbHost=$script:referenceHome.FindName('RefOrbHost')}
$script:referenceOrb=New-OrbitAvatar;$script:orbParts=New-OrbitAvatar
$window=[Windows.Window]::new();$window.Width=640;$window.Height=225;$window.ShowActivated=$false
$layout=[Windows.Controls.Grid]::new();$compact=[Windows.Controls.Canvas]::new();$compact.Name='PetCanvas';[Windows.NameScope]::SetNameScope($window,[Windows.NameScope]::new());$window.RegisterName('PetCanvas',$compact);[void]$layout.Children.Add($compact);[void]$layout.Children.Add($script:referenceHome);$window.Content=$layout
Initialize-OrbyTaskPack
$tasks=@(1..5 | ForEach-Object {[pscustomobject]@{Id=[string]$_;State='working';Title='Example task '+$_;Action='Thinking'}})
Update-OrbyTaskStack $script:expandedTaskStack $tasks $true
if($script:expandedTaskStack.Buddies.Count -ne 4){throw 'Missing one of four companions'}
$hostCanvas=$script:expandedTaskStack.Host
$bodies=@([Windows.Rect]::new(36.6,26,50.4,50.4))
foreach($b in $script:expandedTaskStack.Buddies.Values){
 $left=[Windows.Controls.Canvas]::GetLeft($b.Parts.Root);$top=[Windows.Controls.Canvas]::GetTop($b.Parts.Root)
 $r=[Windows.Rect]::new(($left+9*1.05),($top+10*1.05),(36*1.05),(36*1.05))
 if($r.Left -lt 0 -or $r.Right -gt $hostCanvas.Width -or $r.Top -lt 0 -or $r.Bottom -gt $hostCanvas.Height){throw 'A companion body falls outside reserved space'}
 $bodies+=$r
}
$primary=$bodies[0];$cx=$primary.X+$primary.Width/2;$cy=$primary.Y+$primary.Height/2
foreach($b in $script:expandedTaskStack.Buddies.Values){
 if([Windows.Controls.Panel]::GetZIndex($b.Parts.Root) -ge [Windows.Controls.Panel]::GetZIndex($script:referenceOrb.Root)){throw 'Companion is in front of white Orby'}
 $left=[Windows.Controls.Canvas]::GetLeft($b.Parts.Root);$top=[Windows.Controls.Canvas]::GetTop($b.Parts.Root)
 $dx=$left+27*1.05-$cx;$dy=$top+28*1.05-$cy
 if([math]::Sqrt($dx*$dx+$dy*$dy) -ge 25.2+18.9){throw 'Companion is separated from the cluster'}
 foreach($eyeX in @(11,24)){
  $ex=$left+(9+$eyeX)*1.05;$ey=$top+(10+18)*1.05
  if([math]::Sqrt(($ex-$cx)*($ex-$cx)+($ey-$cy)*($ey-$cy)) -le 25.2){throw 'A companion eye is hidden by white Orby'}
 }
}
$timer=[Windows.Threading.DispatcherTimer]::new();$timer.Interval=[timespan]::FromSeconds(0.6)
$timer.Add_Tick({$timer.Stop();if($PreviewPath){$bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new(640,180,96,96,[Windows.Media.PixelFormats]::Pbgra32);$bitmap.Render($script:referenceHome);$encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap));$stream=[IO.File]::Create($PreviewPath);try{$encoder.Save($stream)}finally{$stream.Dispose()}};$window.Close()})
$window.Add_ContentRendered({$timer.Start()});[void]$window.ShowDialog()
foreach($b in $script:expandedTaskStack.Buddies.Values){$b.Renderer.Dispose()}
[OrbyRefreshClock]::Stop()
Write-Output 'PASS: tight five-Orby cluster fits, white Orby stays in front and companion eyes remain visible.'
