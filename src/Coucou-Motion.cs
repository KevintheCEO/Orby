// Adapted from Louis-CFM/coucou windows/src/core/anim.ts (MIT).
// Copyright (c) 2026 Louis Raille. Original notice: third-party/Coucou-LICENSE.txt.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Windows;
using System.Windows.Threading;
using System.Windows.Media;
namespace OrbyMotion {
 public sealed class Spring {
  public double Value, Target, Velocity, Omega, Zeta;
  public Spring(double value,double response=0.5,double damping=0.72){Value=Target=value;Configure(response,damping);}
  public void Configure(double response,double damping){Omega=2*Math.PI/response;Zeta=damping;}
  public bool Settled {get{return Math.Abs(Target-Value)<0.01 && Math.Abs(Velocity)<0.05;}}
  // Closed-form damped spring: the same trajectory at 60, 144 and 240 Hz.
  public void Step(double dt){if(dt<=0)return;double d=Value-Target,a=Zeta*Omega,w=Omega*Math.Sqrt(Math.Max(.0001,1-Zeta*Zeta));
   double b=(Velocity+a*d)/w,e=Math.Exp(-a*dt),c=Math.Cos(w*dt),s=Math.Sin(w*dt);
   Value=Target+e*(d*c+b*s);Velocity=e*((b*w-a*d)*c+(-d*w-a*b)*s); }
 }
 public sealed class Tracked {
  public Spring Spring;public int Mode;double from=0,to=0,start=0,duration=0;
  public Tracked(double value){Spring=new Spring(value);}
  public double Value{get{return Spring.Value;}} public bool Animating{get{return Mode!=0;}}
  public void Grow(double value){Spring.Configure(0.38,0.88);Spring.Target=value;Mode=1;}
  public void Close(double value,double now){Spring.Configure(0.30,0.92);Spring.Target=value;Mode=1;}
  static double Axis(double t,double a,double b){return 3*(1-t)*(1-t)*t*a+3*(1-t)*t*t*b+t*t*t;}
  public static double CloseCurve(double x){double lo=0,hi=1,t=x;for(int i=0;i<12;i++){if(Axis(t,0.45,0.2)<x)lo=t;else hi=t;t=(lo+hi)/2;}return Axis(t,0,1);}
  public void Step(double dt,double now){if(Mode==1){Spring.Step(dt);if(Spring.Settled){Spring.Value=Spring.Target;Spring.Velocity=0;Mode=0;}}
   else if(Mode==2){double p=Math.Max(0,Math.Min(1,(now-start)/duration));Spring.Value=from+(to-from)*CloseCurve(p);if(p>=1){Spring.Value=to;Spring.Velocity=0;Mode=0;}}}
 }
 // One controllable clock per property, removed on completion or replacement.
 public static class Transitions {
  sealed class Item {public DependencyObject Target;public DependencyProperty Property;public System.Windows.Media.Animation.AnimationClock Clock;public EventHandler Done;public double To;}
  static readonly List<Item> items=new List<Item>();
  sealed class Reveal {public DependencyObject Target,Source;public DependencyProperty Property,SourceProperty;public double To,Seconds,Threshold;public int Hz;}
  static readonly List<Reveal> reveals=new List<Reveal>();static bool watchingReveal;
  public static int PendingCount{get{return items.Count+reveals.Count;}}
  static void StopRevealWatch(){if(reveals.Count==0&&watchingReveal){CompositionTarget.Rendering-=RevealTick;watchingReveal=false;}}
  static void CancelReveal(DependencyObject target,DependencyProperty property){reveals.RemoveAll(x=>x.Target==target&&x.Property==property);StopRevealWatch();}
  public static void MoveAfterReveal(DependencyObject target,DependencyProperty property,double to,double seconds,int hz,bool reduced,DependencyObject source,DependencyProperty sourceProperty,double threshold){
   CancelReveal(target,property);
   if(reduced||source==null||(double)source.GetValue(sourceProperty)>=threshold){MoveAfter(target,property,to,seconds,hz,reduced,0);return;}
   MoveAfter(target,property,0,0,hz,true,0);
   reveals.Add(new Reveal{Target=target,Property=property,To=to,Seconds=seconds,Hz=hz,Source=source,SourceProperty=sourceProperty,Threshold=threshold});
   if(!watchingReveal){watchingReveal=true;CompositionTarget.Rendering+=RevealTick;}
  }
  static void RevealTick(object sender,EventArgs args){foreach(var item in reveals.ToArray()){if((double)item.Source.GetValue(item.SourceProperty)<item.Threshold)continue;reveals.Remove(item);MoveAfter(item.Target,item.Property,item.To,item.Seconds,item.Hz,false,0);}StopRevealWatch();}
  static void Remove(Item item){item.Clock.Completed-=item.Done;items.Remove(item);}
  public static void Move(DependencyObject target,DependencyProperty property,double to,double seconds,int hz,bool reduced){MoveAfter(target,property,to,seconds,hz,reduced,0);}
  public static void MoveAfter(DependencyObject target,DependencyProperty property,double to,double seconds,int hz,bool reduced,double delay){
   CancelReveal(target,property);
   var animated=target as System.Windows.Media.Animation.IAnimatable;if(animated==null)return;
   double from=(double)target.GetValue(property);
   var old=items.Find(x=>x.Target==target && x.Property==property);if(old!=null && old.To==to && !reduced && old.Clock.CurrentState==System.Windows.Media.Animation.ClockState.Active && Math.Abs(from-to)>.0001)return;if(old!=null)Remove(old);
   if(reduced||seconds<=0||Math.Abs(from-to)<.0001){target.SetValue(property,to);animated.ApplyAnimationClock(property,null);return;}
   // The base stays at the visible value until WPF starts the new clock. Using
   // the destination here creates a one-frame native window-region jump.
   target.SetValue(property,from);
   var animation=new System.Windows.Media.Animation.DoubleAnimation(from,to,TimeSpan.FromSeconds(seconds)){
    EasingFunction=new System.Windows.Media.Animation.CubicEase{EasingMode=System.Windows.Media.Animation.EasingMode.EaseOut},FillBehavior=System.Windows.Media.Animation.FillBehavior.HoldEnd};
   if(delay>0)animation.BeginTime=TimeSpan.FromSeconds(delay);
   if(hz>1)System.Windows.Media.Animation.Timeline.SetDesiredFrameRate(animation,hz);
   var item=new Item{Target=target,Property=property,To=to,Clock=animation.CreateClock()};
   item.Done=delegate{if(!items.Contains(item))return;if(Math.Abs((double)target.GetValue(property)-to)<.0001){target.SetValue(property,to);animated.ApplyAnimationClock(property,null);}Remove(item);};
   item.Clock.Completed+=item.Done;items.Add(item);animated.ApplyAnimationClock(property,item.Clock,System.Windows.Media.Animation.HandoffBehavior.SnapshotAndReplace);
  }
  public static void StopAll(){reveals.Clear();StopRevealWatch();foreach(var item in items.ToArray()){double value=(double)item.Target.GetValue(item.Property);item.Target.SetValue(item.Property,value);((System.Windows.Media.Animation.IAnimatable)item.Target).ApplyAnimationClock(item.Property,null);Remove(item);}}
 }
 public static class Driver {
  sealed class Item{public DependencyObject Target;public DependencyProperty Property;public Tracked Track;}
  static readonly List<Item> items=new List<Item>();static readonly Stopwatch watch=Stopwatch.StartNew();
  static bool active;static double last;static TimeSpan rendered=TimeSpan.MinValue;
  public static long FrameCount{get;private set;}public static double MaxFrameGapMs{get;private set;}
  public static void ResetMetrics(){FrameCount=0;MaxFrameGapMs=0;}
  public static int PendingCount{get{return items.Count;}}
  public static void StopAll(){items.Clear();if(active){active=false;CompositionTarget.Rendering-=Tick;}rendered=TimeSpan.MinValue;}
  public static void Snap(DependencyObject target,DependencyProperty property,double value){
   items.RemoveAll(x=>x.Target==target && x.Property==property);
   var animated=target as System.Windows.Media.Animation.Animatable;
   if(animated!=null)animated.BeginAnimation(property,null);
   var element=target as UIElement;if(element!=null)element.BeginAnimation(property,null);
   target.SetValue(property,value);
   if(items.Count==0 && active){active=false;CompositionTarget.Rendering-=Tick;}
  }
  public static void Move(DependencyObject target,DependencyProperty property,double to,bool grow){

   Item item=items.Find(x=>x.Target==target && x.Property==property);
   if(item==null){item=new Item{Target=target,Property=property,Track=new Tracked((double)target.GetValue(property))};items.Add(item);}
   if(item.Track.Spring.Target==to && item.Track.Animating)return;
   double now=watch.Elapsed.TotalSeconds;if(grow)item.Track.Grow(to);else item.Track.Close(to,now);
   if(!active){last=now;active=true;CompositionTarget.Rendering+=Tick;}
  }
  static void Tick(object sender,EventArgs args){var frame=(RenderingEventArgs)args;if(frame.RenderingTime==rendered)return;rendered=frame.RenderingTime;double now=watch.Elapsed.TotalSeconds,elapsed=now-last,dt=Math.Min(0.1,elapsed);last=now;FrameCount++;MaxFrameGapMs=Math.Max(MaxFrameGapMs,elapsed*1000);
   for(int i=items.Count-1;i>=0;i--){Item item=items[i];item.Track.Step(dt,now);item.Target.SetValue(item.Property,item.Track.Value);if(!item.Track.Animating)items.RemoveAt(i);}
   if(items.Count==0){active=false;CompositionTarget.Rendering-=Tick;}
  }
 }
}
