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
  public void Step(double dt){int steps=Math.Max(1,(int)Math.Ceiling(dt/(1.0/240)));double h=dt/steps;
   for(int i=0;i<steps;i++){double acc=Omega*Omega*(Target-Value)-2*Zeta*Omega*Velocity;Velocity+=acc*h;Value+=Velocity*h;}}
 }
 public sealed class Tracked {
  public Spring Spring;public int Mode;double from,to,start,duration;
  public Tracked(double value){Spring=new Spring(value);}
  public double Value{get{return Spring.Value;}} public bool Animating{get{return Mode!=0;}}
  public void Grow(double value){Spring.Configure(0.29,0.88);Spring.Target=value;Mode=1;}
  public void Close(double value,double now){from=Value;to=value;start=now;duration=0.20;Spring.Target=value;Spring.Velocity=0;Mode=2;}
  static double Axis(double t,double a,double b){return 3*(1-t)*(1-t)*t*a+3*(1-t)*t*t*b+t*t*t;}
  public static double CloseCurve(double x){double lo=0,hi=1,t=x;for(int i=0;i<12;i++){if(Axis(t,0.45,0.2)<x)lo=t;else hi=t;t=(lo+hi)/2;}return Axis(t,0,1);}
  public void Step(double dt,double now){if(Mode==1){Spring.Step(dt);if(Spring.Settled){Spring.Value=Spring.Target;Spring.Velocity=0;Mode=0;}}
   else if(Mode==2){double p=Math.Max(0,Math.Min(1,(now-start)/duration));Spring.Value=from+(to-from)*CloseCurve(p);if(p>=1){Spring.Value=to;Spring.Velocity=0;Mode=0;}}}
 }
 public static class Driver {
  sealed class Item{public DependencyObject Target;public DependencyProperty Property;public Tracked Track;}
  static readonly List<Item> items=new List<Item>();static readonly Stopwatch watch=Stopwatch.StartNew();
  static bool active;static double last;static TimeSpan rendered=TimeSpan.MinValue;
  public static void Move(DependencyObject target,DependencyProperty property,double to,bool grow){

   Item item=items.Find(x=>x.Target==target && x.Property==property);
   if(item==null){item=new Item{Target=target,Property=property,Track=new Tracked((double)target.GetValue(property))};items.Add(item);}
   double now=watch.Elapsed.TotalSeconds;if(grow)item.Track.Grow(to);else item.Track.Close(to,now);
   if(!active){last=now;active=true;CompositionTarget.Rendering+=Tick;}
  }
  static void Tick(object sender,EventArgs args){var frame=(RenderingEventArgs)args;if(frame.RenderingTime==rendered)return;rendered=frame.RenderingTime;double now=watch.Elapsed.TotalSeconds,dt=Math.Min(0.1,now-last);last=now;
   for(int i=items.Count-1;i>=0;i--){Item item=items[i];item.Track.Step(dt,now);item.Target.SetValue(item.Property,item.Track.Value);if(!item.Track.Animating)items.RemoveAt(i);}
   if(items.Count==0){active=false;CompositionTarget.Rendering-=Tick;}
  }
 }
}
