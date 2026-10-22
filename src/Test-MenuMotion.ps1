$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework
Add-Type -Path @((Join-Path $PSScriptRoot 'Liquid-Surface.cs'),(Join-Path $PSScriptRoot 'Coucou-Motion.cs'),(Join-Path $PSScriptRoot 'Refresh-Clock.cs')) -ReferencedAssemblies WindowsBase,PresentationCore,PresentationFramework,System.Xaml
$helper=Get-Content (Join-Path $PSScriptRoot 'Motion.ps1') -Raw
. ([scriptblock]::Create($helper.Substring($helper.IndexOf('function Invoke-OrbyMotion'),$helper.IndexOf("Add-Type -Path")-$helper.IndexOf('function Invoke-OrbyMotion'))))
$script:orbySettings=@{ReducedMotion=$false};$script:displayHz=144
function Pump($seconds){$f=[Windows.Threading.DispatcherFrame]::new();$timer=[Windows.Threading.DispatcherTimer]::new();$timer.Interval=[timespan]::FromSeconds($seconds);$timer.Add_Tick({$timer.Stop();$f.Continue=$false}.GetNewClosure());$timer.Start();[Windows.Threading.Dispatcher]::PushFrame($f)}
function Check($ok,$why){if(-not $ok){throw $why};$script:checks++}
$w=[Windows.Window]::new();$w.Width=668;$w.Height=384;$w.WindowStyle='None';$w.AllowsTransparency=$true;$w.Background=[Windows.Media.Brushes]::Transparent;$w.ShowActivated=$false
$s=[OrbyLiquidSurface]::new();$w.Content=$s;$w.Show();$s.Attach($w)
try{
 [OrbyRefreshClock]::Configure(144)
 # Changing a hidden endpoint must never send the native shape to that endpoint
 # before the animation's first frame, including mid-flight reversals.
 $s.Morph=1;$s.ExpandedHeight=242;Pump .05
 Invoke-OrbyMotion $s ([OrbyLiquidSurface]::ExpandedHeightProperty) 358 .3
 Check ($s.ExpandedHeight -lt 243) 'Height jumped to endpoint before first frame'
 Pump .08;$before=$s.ExpandedHeight;Check ($before -gt 242 -and $before -lt 358) 'Height did not interpolate'
 Invoke-OrbyMotion $s ([OrbyLiquidSurface]::ExpandedHeightProperty) 270 .25
 Check ([math]::Abs($s.ExpandedHeight-$before) -lt .01) 'Reversal lost its visible position'
 Pump .4;Check ([math]::Abs($s.ExpandedHeight-270) -lt .01) 'Reversal failed to settle'
 $g=$s.GeometryUpdates;$r=$s.NativeRegionUpdates
 foreach($i in 1..100){$s.CompactWidth=360+$i/1000.0}
 Check ($s.GeometryUpdates -eq $g -and $s.NativeRegionUpdates -eq $r) 'Invisible compact updates rebuilt expanded geometry'
 # Same integer polygon should reuse its native region.
 $s.Morph=0;Pump .02;$r=$s.NativeRegionUpdates
 foreach($i in 1..100){$s.CompactWidth=360.1+$i/100000.0}
 Check (($s.NativeRegionUpdates-$r) -le 2) 'Subpixel updates repeatedly replaced identical native regions'
 # Analytic spring trajectory must not depend on the chosen frame cadence.
 foreach($hz in @(60,144,240)){
  $spring=[OrbyMotion.Spring]::new(0,.38,.88)
  $spring.Target=1;foreach($i in 1..$hz){$spring.Step(1.0/$hz)}
  if($hz -eq 60){$reference=$spring.Value}else{Check ([math]::Abs($spring.Value-$reference) -lt .0000001) 'Spring speed changed with frame cadence'}
 }
 foreach($hz in @(60,144,240)){
  [OrbyRefreshClock]::Configure($hz);Check ([OrbyRefreshClock]::TargetHz -eq $hz) 'Refresh change ignored'
  [OrbyMotion.Driver]::ResetMetrics()
  foreach($cycle in 1..3){[OrbyMotion.Driver]::Move($s,[OrbyLiquidSurface]::MorphProperty,1,$true);Pump .35;[OrbyMotion.Driver]::Move($s,[OrbyLiquidSurface]::MorphProperty,0,$false);Pump .4}
  Check ([math]::Abs($s.Morph) -lt .01) 'Hover failed to settle'
  "CADENCE target=$hz frames=$([OrbyMotion.Driver]::FrameCount) maxGapMs=$([math]::Round([OrbyMotion.Driver]::MaxFrameGapMs,2))"
 }
 foreach($i in 1..200){[OrbyMotion.Driver]::Move($s,[OrbyLiquidSurface]::MorphProperty,1,$true);[OrbyMotion.Driver]::Move($s,[OrbyLiquidSurface]::MorphProperty,0,$false)}
 Check ([OrbyMotion.Driver]::PendingCount -le 1) 'Reversals queued extra clocks'
 [OrbyMotion.Driver]::Snap($s,[OrbyLiquidSurface]::MorphProperty,0);Pump .1
 Check ([OrbyMotion.Driver]::PendingCount -eq 0 -and $s.Morph -eq 0) 'Snap left pending motion'
 Check ([OrbyMotion.Transitions]::PendingCount -eq 0) 'Completed transitions retained clocks'
 Invoke-OrbyMotion $s ([OrbyLiquidSurface]::ExpandedHeightProperty) 390 .18;Pump .04
 $s.BeginAnimation([OrbyLiquidSurface]::ExpandedHeightProperty,$null);$s.ExpandedHeight=260
 Pump .3;Check ($s.ExpandedHeight -eq 260 -and [OrbyMotion.Transitions]::PendingCount -eq 0) 'Canceled transition later overwrote its replacement'
 Invoke-OrbyMotion $s ([OrbyLiquidSurface]::ExpandedHeightProperty) 320 .3;Pump .04
 $script:orbySettings.ReducedMotion=$true
 Invoke-OrbyMotion $s ([OrbyLiquidSurface]::ExpandedHeightProperty) 333 .25
 Check ($s.ExpandedHeight -eq 333 -and -not $s.HasAnimatedProperties) 'Reduced motion left a transition active'
 "PASS: $script:checks motion assertions; native mask continuity, redundant work, frame-independent spring, refresh changes, rapid reversal, reduced motion."
}finally{[OrbyMotion.Transitions]::StopAll();[OrbyMotion.Driver]::StopAll();[OrbyRefreshClock]::Stop();$w.Close()}
