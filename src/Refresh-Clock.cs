using System;
using System.Windows;
using System.Windows.Media.Animation;
// Keeps the WPF animation clock at the current monitor's requested cadence.
// Rendering remains compositor driven; this does not manufacture rendered frames.
public sealed class OrbyRefreshClock : Animatable {
 public static readonly DependencyProperty PulseProperty=DependencyProperty.Register("Pulse",typeof(double),typeof(OrbyRefreshClock));
 static readonly OrbyRefreshClock instance=new OrbyRefreshClock();
 public static int TargetHz {get;private set;}
 protected override Freezable CreateInstanceCore(){return new OrbyRefreshClock();}
 public static void Configure(int hz){
  hz=hz>1?Math.Min(500,hz):60;if(TargetHz==hz)return;TargetHz=hz;
  var pulse=new DoubleAnimation(0,1,new Duration(TimeSpan.FromSeconds(1))){RepeatBehavior=RepeatBehavior.Forever};
  Timeline.SetDesiredFrameRate(pulse,hz);instance.BeginAnimation(PulseProperty,pulse);
 }
 public static void Stop(){instance.BeginAnimation(PulseProperty,null);TargetHz=0;}
}
