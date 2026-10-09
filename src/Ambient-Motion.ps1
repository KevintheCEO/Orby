function Initialize-OrbyAmbientMotion {
 $script:ambientPools=@();$index=0
 foreach($pair in @(@('HomeAmbientBrush','RefHomePage'),@('OrbAmbientBrush','RefHomePage'),@('MusicAmbientBrush','RefMusicPage'),@('PillAmbientBrush0','RefHomePage'),@('PillAmbientBrush1','RefHomePage'),@('PillAmbientBrush2','RefHomePage'),@('PillAmbientBrush3','RefHomePage'))){
  $brush=$script:referenceHome.FindName($pair[0]);$owner=$script:referenceHome.FindName($pair[1])
  $pool=@{Brush=$brush;Owner=$owner;Center=$brush.Center;Origin=$brush.GradientOrigin;Radius=$brush.RadiusX;Index=$index;Running=$false}
  $script:ambientPools+=$pool;$index++
 }
 $script:referenceHome.Add_IsVisibleChanged({Update-OrbyAmbientMotion})
 $script:referenceHome.FindName('RefHomePage').Add_IsVisibleChanged({Update-OrbyAmbientMotion})
 $script:referenceHome.FindName('RefMusicPage').Add_IsVisibleChanged({Update-OrbyAmbientMotion})
 Update-OrbyAmbientMotion
}
function Set-OrbyAmbientPool {
 param($Pool,[bool]$Run)
 if($Pool.Running -eq $Run){return};$Pool.Running=$Run;$b=$Pool.Brush
 if(-not $Run){foreach($dp in @([Windows.Media.RadialGradientBrush]::CenterProperty,[Windows.Media.RadialGradientBrush]::GradientOriginProperty,[Windows.Media.RadialGradientBrush]::RadiusXProperty,[Windows.Media.Brush]::OpacityProperty)){$b.BeginAnimation($dp,$null)};return}
 $seconds=18+$Pool.Index*1.7;$ease=[Windows.Media.Animation.SineEase]::new();$ease.EasingMode='EaseInOut'
 foreach($dp in @([Windows.Media.RadialGradientBrush]::CenterProperty,[Windows.Media.RadialGradientBrush]::GradientOriginProperty)){
  $origin=if($dp -eq [Windows.Media.RadialGradientBrush]::CenterProperty){$Pool.Center}else{$Pool.Origin}
  $a=[Windows.Media.Animation.PointAnimation]::new();$a.From=$origin;$a.To=[Windows.Point]::new($origin.X+0.055,$origin.Y+0.04);$a.Duration=[timespan]::FromSeconds($seconds);$a.AutoReverse=$true;$a.RepeatBehavior=[Windows.Media.Animation.RepeatBehavior]::Forever;$a.EasingFunction=$ease
  if($script:displayHz -gt 0){[Windows.Media.Animation.Timeline]::SetDesiredFrameRate($a,$script:displayHz)}
  $b.BeginAnimation($dp,$a)
 }
 $breath=[Windows.Media.Animation.DoubleAnimation]::new();$breath.From=1;$breath.To=0.88;$breath.Duration=[timespan]::FromSeconds(9+$Pool.Index*.9);$breath.AutoReverse=$true;$breath.RepeatBehavior=[Windows.Media.Animation.RepeatBehavior]::Forever;$breath.EasingFunction=$ease
 if($script:displayHz -gt 0){[Windows.Media.Animation.Timeline]::SetDesiredFrameRate($breath,$script:displayHz)}
 $b.BeginAnimation([Windows.Media.Brush]::OpacityProperty,$breath)
 $spread=[Windows.Media.Animation.DoubleAnimation]::new();$spread.From=$Pool.Radius;$spread.To=$Pool.Radius*1.045;$spread.Duration=[timespan]::FromSeconds($seconds+3);$spread.AutoReverse=$true;$spread.RepeatBehavior=[Windows.Media.Animation.RepeatBehavior]::Forever;$spread.EasingFunction=$ease
 $b.BeginAnimation([Windows.Media.RadialGradientBrush]::RadiusXProperty,$spread)
}
function Update-OrbyAmbientMotion {
 $reduced=[bool]$script:orbySettings.ReducedMotion -or -not [Windows.SystemParameters]::ClientAreaAnimation
 foreach($pool in $script:ambientPools){Set-OrbyAmbientPool $pool ([bool]($pool.Owner.IsVisible -and -not $reduced))}
}
function Stop-OrbyAmbientMotion {foreach($pool in $script:ambientPools){Set-OrbyAmbientPool $pool $false}}
