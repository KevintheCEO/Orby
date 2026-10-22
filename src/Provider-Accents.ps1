# Local halos are independent from task dots and Spotify artwork ambience.
$script:providerAccentPalettes=@{chatgpt=@('#4CA3FF');claude=@('#D97757');gemini=@('#4285F4','#9B72CB','#D96570')}
function Set-OrbyProviderAccent {
 param($Parts,[string]$Id='chatgpt',[bool]$Sleeping=$false,[bool]$Animate=$false)
 if(-not $Parts -or -not $Parts.Root){return}
 if(-not $script:providerAccentPalettes.ContainsKey($Id)){$Id='chatgpt'}
 $key=$Id+'|'+$Sleeping+'|'+$Animate
 if($Parts.AccentKey -eq $key){return}
 if(-not $Parts.AccentHost){
  $layer=[Windows.Controls.Canvas]::new();$layer.Width=54;$layer.Height=56;$layer.IsHitTestVisible=$false
  [Windows.Controls.Panel]::SetZIndex($layer,-100);$Parts.Root.Children.Insert(0,$layer);$Parts.AccentHost=$layer
 }
 foreach($old in $Parts.AccentHost.Children){$old.Fill.BeginAnimation([Windows.Media.RadialGradientBrush]::GradientOriginProperty,$null)}
 $Parts.AccentKey=$key;$Parts.AccentId=$Id;$Parts.AccentHost.Children.Clear()
 $colors=$script:providerAccentPalettes[$Id];$offsets=@([Windows.Point]::new(0,0))
 if($Id -eq 'gemini'){$offsets=@([Windows.Point]::new(-3,-1),[Windows.Point]::new(3,-2),[Windows.Point]::new(0,3))}
 for($i=0;$i -lt $colors.Count;$i++){
  $rgb=[Windows.Media.ColorConverter]::ConvertFromString($colors[$i]);$alpha=if($Sleeping){7}elseif($Id -eq 'gemini'){23}else{30}
  $brush=[Windows.Media.RadialGradientBrush]::new();$brush.Center=[Windows.Point]::new(.5,.5);$brush.GradientOrigin=$brush.Center
  foreach($offset in @(0,.52)){$brush.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.Color]::FromArgb([byte]$alpha,$rgb.R,$rgb.G,$rgb.B),$offset))}
  $brush.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.Color]::FromArgb(0,$rgb.R,$rgb.G,$rgb.B),1))
  $halo=[Windows.Shapes.Ellipse]::new();$halo.Width=56;$halo.Height=56;$halo.Fill=$brush;$halo.IsHitTestVisible=$false
  [Windows.Controls.Canvas]::SetLeft($halo,-1+$offsets[$i].X);[Windows.Controls.Canvas]::SetTop($halo,$offsets[$i].Y);[void]$Parts.AccentHost.Children.Add($halo)
  if($Animate -and -not $Sleeping){
   $drift=[Windows.Media.Animation.PointAnimation]::new([Windows.Point]::new(.47,.48),[Windows.Point]::new(.53,.52),[timespan]::FromSeconds(18+$i*3))
   $drift.AutoReverse=$true;$drift.RepeatBehavior=[Windows.Media.Animation.RepeatBehavior]::Forever;$drift.EasingFunction=[Windows.Media.Animation.SineEase]::new();$brush.BeginAnimation([Windows.Media.RadialGradientBrush]::GradientOriginProperty,$drift)
  }
 }
}
