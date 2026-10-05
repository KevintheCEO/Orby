using System;
using System.Collections.Generic;
namespace OrbyPack {
 public sealed class Channel {
  public string Key; public double[] Keys,Times;public bool Linear;
  public Channel(string key,double[] keys,double[] times,bool linear){Key=key;Keys=keys;Times=times;Linear=linear;}
  public double Value(double p){if(Keys.Length==1)return Keys[0];p=Math.Max(0,Math.Min(1,p));int i=0;
   while(i<Keys.Length-2 && p>=(Times==null?(i+1.0)/(Keys.Length-1):Times[i+1]))i++;
   double a=Times==null?(i+0.0)/(Keys.Length-1):Times[i],b=Times==null?(i+1.0)/(Keys.Length-1):Times[i+1];
   double q=Math.Max(0,Math.Min(1,(p-a)/Math.Max(0.000001,b-a)));if(!Linear)q=(1-Math.Cos(q*Math.PI))/2;
   return Keys[i]+(Keys[i+1]-Keys[i])*q;
  }
 }
 public sealed class Clip {
  public string Id,Name,Exit,ParticleMode,Color,Indicator,Pose;public int Duration,Priority,Cooldown,Count,Period;public bool Loop;public double Radius;public Channel[] Channels;
  public Clip(string id,string name,int duration,bool loop,int priority,int cooldown,string exit,Channel[] channels,int count,string mode,double radius,int period,string color,string indicator,string pose){Id=id;Name=name;Duration=duration;Loop=loop;Priority=priority;Cooldown=cooldown;Exit=exit;Channels=channels;Count=count;ParticleMode=mode;Radius=radius;Period=period;Color=color;Indicator=indicator;Pose=pose;}
 }
 public sealed class Pose {
  public double X,Y,Rotation,ScaleX=1,ScaleY=1,Opacity=1,EyeX,EyeY,EyeWidth=1,EyeHeight=1,LeftHeight=1,RightHeight=1,LeftY,RightY;
  public void Reset(){X=Y=Rotation=EyeX=EyeY=LeftY=RightY=0;ScaleX=ScaleY=Opacity=EyeWidth=EyeHeight=LeftHeight=RightHeight=1;}
  public void Apply(Clip clip,double p){foreach(var ch in clip.Channels){double v=ch.Value(p);switch(ch.Key){
   case "body.x":X=v;break;case "body.y":Y=v;break;case "body.rotationDeg":Rotation=v;break;
   case "body.scale":ScaleX=ScaleY=v;break;case "body.scaleX":ScaleX=v;break;case "body.scaleY":ScaleY=v;break;case "body.opacity":Opacity=v;break;
   case "eyes.x":EyeX=v;break;case "eyes.y":EyeY=v;break;case "eyes.width":EyeWidth=v;break;case "eyes.height":EyeHeight=v;break;
   case "eyes.leftHeight":LeftHeight=v;break;case "eyes.rightHeight":RightHeight=v;break;case "eyes.leftY":LeftY=v;break;case "eyes.rightY":RightY=v;break;
  }}}
 }
 public static class Catalog {
  public static readonly Clip[] All=new Clip[]{
new Clip("idle_shuffle","Tiny Side Step",1600,false,20,45000,"idle_neutral",new Channel[]{new Channel("body.x",new double[]{0.0,-1.0,-3.0,-1.0,0.0,2.0,0.0},null,false),new Channel("body.y",new double[]{0.0,-1.0,0.0,-1.0,0.0,-1.0,0.0},null,false),new Channel("body.rotationDeg",new double[]{0.0,-3.0,0.0,3.0,0.0},null,false),new Channel("eyes.x",new double[]{0.0,-0.4,0.4,0.0},null,false)},0,"",20.0,1600,"neutral","",""),
new Clip("idle_stretch","Little Stretch",1800,false,20,45000,"idle_neutral",new Channel[]{new Channel("body.y",new double[]{0.0,1.0,-1.0,0.0},null,false),new Channel("body.scaleX",new double[]{1.0,1.03,0.96,1.0},null,false),new Channel("body.scaleY",new double[]{1.0,0.97,1.06,1.0},null,false),new Channel("eyes.height",new double[]{1.0,0.65,0.75,1.0},null,false)},0,"",20.0,1800,"neutral","",""),
new Clip("idle_ponder","Daydream",2300,false,20,45000,"idle_neutral",new Channel[]{new Channel("body.rotationDeg",new double[]{0.0,-4.0,-4.0,0.0},null,false),new Channel("eyes.x",new double[]{0.0,-0.35,-0.35,0.0},null,false),new Channel("eyes.y",new double[]{0.0,-0.4,-0.4,0.0},null,false),new Channel("eyes.leftHeight",new double[]{1.0,0.8,0.8,1.0},null,false)},0,"",20.0,2300,"neutral","",""),
new Clip("idle_double_hop","Two Tiny Hops",1100,false,20,45000,"idle_neutral",new Channel[]{new Channel("body.y",new double[]{0.0,1.0,-3.0,0.0,1.0,-2.0,0.0},null,false),new Channel("body.scaleX",new double[]{1.0,1.04,0.98,1.0,1.03,0.99,1.0},null,false),new Channel("body.scaleY",new double[]{1.0,0.96,1.02,1.0,0.97,1.01,1.0},null,false)},0,"",20.0,1100,"neutral","",""),
new Clip("idle_neutral","Neutral Idle",2600,true,10,0,"idle_neutral",new Channel[]{new Channel("body.y",new double[]{0.0,-1.5,0.0,1.5,0.0},null,false),new Channel("body.scaleX",new double[]{1.0},null,false),new Channel("body.scaleY",new double[]{1.0},null,false),new Channel("eyes.x",new double[]{0.0},null,false),new Channel("eyes.y",new double[]{0.0},null,false),new Channel("eyes.width",new double[]{1.0},null,false),new Channel("eyes.height",new double[]{1.0},null,false)},0,"",20.0,2600,"ai","",""),
new Clip("blink_natural","Natural Blink",180,false,35,2200,"idle_neutral",new Channel[]{new Channel("eyes.height",new double[]{1.0,0.08,1.0},new double[]{0.0,0.45,1.0},false)},0,"",20.0,180,"ai","",""),
new Clip("blink_double","Double Blink",420,false,32,10000,"idle_neutral",new Channel[]{new Channel("eyes.height",new double[]{1.0,0.08,1.0,1.0,0.08,1.0},new double[]{0.0,0.16,0.3,0.55,0.72,1.0},false)},0,"",20.0,420,"ai","",""),
new Clip("look_left_right","Look Left / Right",1300,false,22,0,"idle_neutral",new Channel[]{new Channel("eyes.x",new double[]{0.0,-0.8,-0.8,0.8,0.8,0.0},null,false)},0,"",20.0,1300,"ai","",""),
new Clip("look_up_down","Look Up / Down",1200,false,22,0,"idle_neutral",new Channel[]{new Channel("eyes.y",new double[]{0.0,-0.65,-0.65,0.6,0.6,0.0},null,false)},0,"",20.0,1200,"ai","",""),
new Clip("curious_tilt","Curious Tilt",900,false,45,3000,"idle_neutral",new Channel[]{new Channel("body.rotationDeg",new double[]{0.0,10.0,8.0,0.0},null,false),new Channel("eyes.x",new double[]{0.35},null,false),new Channel("eyes.y",new double[]{-0.15},null,false)},0,"",20.0,900,"ai","",""),
new Clip("cursor_follow","Cursor Follow",0,true,40,0,"idle_neutral",new Channel[]{},0,"",20.0,1500,"ai","",""),
new Clip("cursor_surprise","Cursor Surprise",430,false,55,2500,"hover_happy",new Channel[]{new Channel("body.y",new double[]{0.0,-3.0,0.0},null,false),new Channel("body.scale",new double[]{1.0,0.94,1.02,1.0},null,false),new Channel("eyes.width",new double[]{1.0,1.25,1.08},null,false),new Channel("eyes.height",new double[]{1.0,1.15,1.0},null,false)},0,"",20.0,430,"ai","",""),
new Clip("hover_happy","Hover Happy",500,false,50,0,"notch_open",new Channel[]{new Channel("body.y",new double[]{0.0,-2.0,0.0},null,false),new Channel("body.scaleY",new double[]{1.0,1.05,1.0},null,false),new Channel("eyes.width",new double[]{1.1},null,false),new Channel("eyes.height",new double[]{1.08},null,false)},0,"",20.0,500,"ai","",""),
new Clip("notch_open","Notch Open",520,false,70,0,"open_idle",new Channel[]{new Channel("body.scaleX",new double[]{1.0,1.12,0.97,1.0},null,false),new Channel("body.scaleY",new double[]{1.0,0.9,1.04,1.0},null,false)},0,"",20.0,520,"ai","",""),
new Clip("notch_close","Notch Close",420,false,75,0,"idle_neutral",new Channel[]{new Channel("body.scaleX",new double[]{1.0,0.94,1.0},null,false),new Channel("body.scaleY",new double[]{1.0,1.05,1.0},null,false)},0,"",20.0,420,"ai","",""),
new Clip("listening","Listening",1200,true,85,0,"idle_neutral",new Channel[]{new Channel("body.scale",new double[]{1.0,1.015,1.0},null,false),new Channel("eyes.height",new double[]{1.1},null,false)},0,"",20.0,1200,"ai","ring",""),
new Clip("user_typing","User Typing",1600,true,35,0,"idle_neutral",new Channel[]{new Channel("eyes.x",new double[]{0.35},null,false),new Channel("eyes.y",new double[]{0.2},null,false)},0,"",20.0,1600,"ai","",""),
new Clip("thinking_basic","Thinking Basic",2200,true,88,0,"idle_neutral",new Channel[]{new Channel("body.rotationDeg",new double[]{0.0,-3.0,3.0,0.0},null,false),new Channel("eyes.x",new double[]{0.0,-0.7,0.7,0.0},null,false)},0,"",20.0,2200,"ai","statusDot",""),
new Clip("thinking_deep","Thinking Deep",3000,true,89,0,"idle_neutral",new Channel[]{new Channel("body.rotationDeg",new double[]{0.0,6.0,2.0,0.0},null,false),new Channel("eyes.leftY",new double[]{-0.1},null,false),new Channel("eyes.rightY",new double[]{0.08},null,false),new Channel("eyes.x",new double[]{0.0,-0.4,0.4,0.0},null,false)},1,"orbit",18.0,1800,"ai","",""),
new Clip("thinking_search","Thinking Search",1500,true,90,0,"idle_neutral",new Channel[]{new Channel("eyes.x",new double[]{-0.9,0.9,-0.9},null,true),new Channel("eyes.y",new double[]{-0.35,0.35,-0.35},null,false)},0,"",20.0,1500,"ai","",""),
new Clip("task_starting","Task Starting",650,false,95,0,"working_normal",new Channel[]{new Channel("body.y",new double[]{0.0,-3.0,0.0},null,false),new Channel("body.scale",new double[]{1.0,1.04,1.0},null,false)},0,"",20.0,650,"ai","statusDot",""),
new Clip("working_normal","Working Normal",2200,true,92,0,"working_normal",new Channel[]{new Channel("eyes.x",new double[]{0.0},null,false),new Channel("eyes.y",new double[]{-0.05},null,false)},3,"orbit",20.0,2200,"neutral","",""),
new Clip("working_fast","Working Fast",1200,true,93,0,"working_normal",new Channel[]{new Channel("eyes.x",new double[]{-0.5,0.5,-0.5},null,false)},3,"orbit",18.0,1100,"ai","",""),
new Clip("working_long","Working Long Task",6200,true,91,0,"working_long",new Channel[]{new Channel("body.rotationDeg",new double[]{0.0,2.0,-2.0,0.0},null,false),new Channel("eyes.x",new double[]{0.0,-0.5,0.3,0.0},null,false),new Channel("eyes.y",new double[]{0.0,-0.15,0.12,0.0},null,false)},2,"orbit",20.0,3000,"neutral","",""),
new Clip("tool_use","Tool Use",900,false,96,0,"working_normal",new Channel[]{},0,"",20.0,900,"ai","iconBubble",""),
new Clip("task_progress","Task Progress",1800,true,94,0,"working_normal",new Channel[]{},1,"progressOrbit",21.0,1800,"ai","",""),
new Clip("task_complete","Task Complete",900,false,100,0,"idle_neutral",new Channel[]{new Channel("body.y",new double[]{0.0,-5.0,0.0},null,false),new Channel("body.scaleX",new double[]{1.0,1.08,0.96,1.0},null,false),new Channel("body.scaleY",new double[]{1.0,0.94,1.05,1.0},null,false),new Channel("eyes.width",new double[]{1.0,1.2,1.0},null,false),new Channel("eyes.height",new double[]{1.0,1.1,1.0},null,false)},0,"",20.0,900,"success","flashDot",""),
new Clip("big_success","Big Success",1200,false,99,0,"idle_neutral",new Channel[]{new Channel("body.y",new double[]{0.0,-8.0,0.0},null,false),new Channel("body.scale",new double[]{1.0,1.07,0.96,1.0},null,false),new Channel("eyes.width",new double[]{1.25},null,false),new Channel("eyes.height",new double[]{1.15},null,false)},6,"burst",26.0,1200,"success","",""),
new Clip("paused","Paused",700,false,110,0,"paused_idle",new Channel[]{new Channel("body.y",new double[]{0.0,1.0,0.0},null,false),new Channel("eyes.x",new double[]{0.45},null,false),new Channel("eyes.y",new double[]{0.05},null,false)},0,"",20.0,700,"warning","statusDot",""),
new Clip("paused_idle","Paused Idle",2200,true,105,0,"paused_idle",new Channel[]{new Channel("body.y",new double[]{0.0,-0.6,0.0,0.6,0.0},null,false),new Channel("eyes.x",new double[]{0.25},null,false),new Channel("eyes.height",new double[]{0.92},null,false)},0,"",20.0,2200,"warning","statusDot",""),
new Clip("stopped_cancelled","Stopped / Cancelled",550,false,120,0,"idle_neutral",new Channel[]{new Channel("body.y",new double[]{0.0,2.0,0.0},null,false),new Channel("body.scaleY",new double[]{1.0,0.9,1.03,1.0},null,false),new Channel("eyes.height",new double[]{1.0,0.7,1.0},null,false)},0,"",20.0,550,"ai","",""),
new Clip("waiting_user","Waiting for User",2400,true,102,0,"waiting_user",new Channel[]{new Channel("eyes.x",new double[]{0.35},null,false),new Channel("eyes.y",new double[]{0.18},null,false)},0,"",20.0,2400,"ai","speechDot",""),
new Clip("notification","Notification",1000,false,80,0,"idle_neutral",new Channel[]{new Channel("body.y",new double[]{0.0,-2.0,0.0},null,false),new Channel("eyes.x",new double[]{0.6},null,false),new Channel("eyes.y",new double[]{-0.2},null,false)},0,"",20.0,1000,"ai","bubble",""),
new Clip("unread_notification","Unread Notification",3000,true,42,0,"idle_neutral",new Channel[]{new Channel("eyes.x",new double[]{0.0,0.5,0.0},null,false)},0,"",20.0,3000,"ai","bubble",""),
new Clip("error_failure","Error / Failure",850,false,115,0,"idle_neutral",new Channel[]{new Channel("body.x",new double[]{0.0,-2.0,2.0,-1.0,1.0,0.0},null,false),new Channel("body.scale",new double[]{1.0,0.96,1.0},null,false),new Channel("eyes.width",new double[]{0.9},null,false),new Channel("eyes.height",new double[]{0.85},null,false)},0,"",20.0,850,"error","flashDot",""),
new Clip("confused","Confused",1100,false,65,0,"idle_neutral",new Channel[]{new Channel("body.rotationDeg",new double[]{0.0,8.0,5.0,0.0},null,false),new Channel("eyes.leftY",new double[]{-0.18},null,false),new Channel("eyes.rightY",new double[]{0.12},null,false)},0,"",20.0,1100,"ai","",""),
new Clip("gesture_no","No / Can't Do That",600,false,70,0,"idle_neutral",new Channel[]{new Channel("body.rotationDeg",new double[]{0.0,-6.0,6.0,-4.0,4.0,0.0},null,false)},0,"",20.0,600,"ai","",""),
new Clip("gesture_yes","Yes / Confirmed",520,false,70,0,"idle_neutral",new Channel[]{new Channel("body.y",new double[]{0.0,2.0,-1.0,0.0},null,false),new Channel("body.scaleY",new double[]{1.0,0.97,1.02,1.0},null,false)},0,"",20.0,520,"ai","",""),
new Clip("sleep_afk","Sleep / AFK",4200,true,25,0,"sleep_afk",new Channel[]{new Channel("body.y",new double[]{2.0},null,false),new Channel("body.scaleY",new double[]{0.99},null,false),new Channel("eyes.height",new double[]{1.0,0.2,0.12},new double[]{0.0,0.45,1.0},false)},0,"",20.0,4200,"ai","",""),
new Clip("wake_up","Wake Up",780,false,80,0,"idle_neutral",new Channel[]{new Channel("body.y",new double[]{2.0,-2.0,0.0},null,false),new Channel("eyes.height",new double[]{0.12,0.2,1.25,1.0,0.08,1.0},null,false),new Channel("eyes.width",new double[]{1.0,1.0,1.15,1.0,1.0,1.0},null,false)},0,"",20.0,780,"ai","",""),
new Clip("bored_idle","Bored Idle",3200,false,18,60000,"idle_neutral",new Channel[]{new Channel("body.rotationDeg",new double[]{0.0,-3.0,3.0,0.0},null,false),new Channel("eyes.x",new double[]{0.0,-0.8,0.8,0.0},null,false),new Channel("eyes.y",new double[]{0.0,0.25,-0.1,0.0},null,false)},0,"",20.0,3200,"ai","",""),
new Clip("playful_bounce","Playful Bounce",700,false,20,30000,"idle_neutral",new Channel[]{new Channel("body.y",new double[]{0.0,-4.0,0.0},null,false),new Channel("body.scaleX",new double[]{1.0,1.07,0.96,1.0},null,false),new Channel("body.scaleY",new double[]{1.0,0.93,1.05,1.0},null,false)},0,"",20.0,700,"ai","",""),
new Clip("eye_peek","Eye Peek",900,false,20,30000,"idle_neutral",new Channel[]{new Channel("eyes.leftHeight",new double[]{1.0,0.08,1.0,1.0},null,false),new Channel("eyes.rightHeight",new double[]{1.0,0.08,0.08,1.0},null,false)},0,"",20.0,900,"ai","",""),
new Clip("orbiting_dot_game","Orbiting Dot Game",3800,false,16,90000,"idle_neutral",new Channel[]{},1,"orbit",22.0,1500,"neutral","",""),
new Clip("catch_dot","Catch the Dot",1600,false,17,90000,"idle_neutral",new Channel[]{new Channel("body.x",new double[]{0.0,2.0,-1.0,0.0},null,false),new Channel("body.rotationDeg",new double[]{0.0,5.0,-3.0,0.0},null,false)},1,"dart_away_then_vanish",20.0,1600,"neutral","",""),
new Clip("tiny_arms","Tiny Arms",1200,false,15,120000,"idle_neutral",new Channel[]{},0,"",20.0,1200,"ai","optionalArms","peek"),
new Clip("wave","Wave",1400,false,50,0,"idle_neutral",new Channel[]{},0,"",20.0,1400,"ai","optionalArms","wave"),
new Clip("coffee_break","Coffee / Break",4200,false,12,300000,"idle_neutral",new Channel[]{new Channel("eyes.height",new double[]{0.88},null,false)},0,"",20.0,4200,"ai","prop","tiny_cup"),
new Clip("music_mode","Music Mode",800,true,34,0,"idle_neutral",new Channel[]{},0,"",20.0,800,"ai","",""),
new Clip("headphones_mode","Headphones Mode",950,false,60,0,"idle_neutral",new Channel[]{new Channel("eyes.width",new double[]{1.0,1.15,1.0},null,false)},0,"",20.0,950,"ai","iconBubble",""),
new Clip("volume_change","Volume Change",650,false,55,0,"idle_neutral",new Channel[]{new Channel("body.scale",new double[]{1.0,1.02,1.0},null,false)},0,"",20.0,650,"ai","",""),
new Clip("drag_orbit","Drag Orbit",0,true,85,0,"idle_neutral",new Channel[]{new Channel("body.stretchOppositeVelocity",new double[]{0.06},null,false)},0,"",20.0,1500,"ai","",""),
new Clip("dragged_too_fast","Dragged Too Fast",900,false,86,0,"idle_neutral",new Channel[]{new Channel("eyes.width",new double[]{1.15},null,false)},0,"",20.0,900,"ai","",""),
new Clip("window_appears","Window Appears",650,false,36,0,"idle_neutral",new Channel[]{},0,"",20.0,650,"ai","",""),
new Clip("window_close","Window Close",520,false,34,0,"idle_neutral",new Channel[]{new Channel("eyes.returnMs",new double[]{240.0},null,false)},0,"",20.0,520,"ai","",""),
new Clip("battery_warning","Battery / System Warning",1200,true,108,0,"battery_warning",new Channel[]{new Channel("eyes.width",new double[]{0.95},null,false),new Channel("eyes.height",new double[]{0.86},null,false)},0,"",20.0,1200,"warning","statusDot",""),
new Clip("internet_lost","Internet Lost",1500,false,112,0,"offline_idle",new Channel[]{new Channel("body.rotationDeg",new double[]{0.0,6.0,0.0},null,false),new Channel("eyes.leftY",new double[]{-0.12},null,false),new Channel("eyes.rightY",new double[]{0.08},null,false)},0,"",20.0,1500,"error","iconBubble",""),
new Clip("offline_idle","Offline Idle",2400,true,107,0,"offline_idle",new Channel[]{new Channel("eyes.height",new double[]{0.82},null,false)},0,"",20.0,2400,"error","statusDot",""),
new Clip("internet_restored","Internet Restored",800,false,116,0,"idle_neutral",new Channel[]{new Channel("body.y",new double[]{0.0,-2.0,0.0},null,false),new Channel("eyes.width",new double[]{1.0,1.15,1.0},null,false)},0,"",20.0,800,"success","flashDot",""),
new Clip("update_available","Update Available",900,false,45,0,"idle_neutral",new Channel[]{},0,"",20.0,900,"ai","badge",""),
new Clip("startup_boot","Startup / Boot",1800,false,125,0,"idle_neutral",new Channel[]{new Channel("body.scale",new double[]{0.05,1.08,0.96,1.0},null,false),new Channel("body.opacity",new double[]{0.0,1.0,1.0,1.0},null,false),new Channel("eyes.height",new double[]{0.0,0.0,1.1,0.08,1.0},new double[]{0.0,0.4,0.6,0.78,1.0},false)},0,"",20.0,1800,"ai","",""),
new Clip("shutdown","Shutdown",1400,false,130,0,"none",new Channel[]{new Channel("body.scale",new double[]{1.0,1.0,0.05},null,false),new Channel("body.opacity",new double[]{1.0,1.0,0.0},null,false),new Channel("eyes.height",new double[]{1.0,0.08,0.0},null,false)},0,"",20.0,1400,"ai","",""),
new Clip("rare_stare","Rare Stare",2600,false,12,120000,"idle_neutral",new Channel[]{},0,"",20.0,2600,"ai","",""),
new Clip("rare_eye_roll","Rare Eye Roll",900,false,10,120000,"idle_neutral",new Channel[]{},0,"",20.0,900,"ai","",""),
new Clip("rare_dizzy","Rare Dizzy",1200,false,50,10000,"idle_neutral",new Channel[]{new Channel("eyes.periodMs",new double[]{400.0},null,false)},0,"",20.0,1200,"ai","",""),
new Clip("rare_particle_burst","Rare Particle Burst",1500,false,10,120000,"idle_neutral",new Channel[]{},5,"burst_then_return",24.0,1500,"neutral","",""),
new Clip("idle_toe_tap","Tiny Toe Tap",1900,false,25,30000,"idle_neutral",new Channel[]{new Channel("body.y",new double[]{0,-1,0,-1.5,0},null,false),new Channel("body.rotationDeg",new double[]{0,3,0,3,0},null,false),new Channel("eyes.y",new double[]{0,0.3,0},null,false)},0,"",0,1900,"neutral","",""),
new Clip("idle_peek_around","Peek Around",2200,false,25,35000,"idle_neutral",new Channel[]{new Channel("body.x",new double[]{0,-2,0,2,0},null,false),new Channel("eyes.x",new double[]{0,-0.7,0,0.7,0},null,false)},0,"",0,2200,"neutral","",""),
new Clip("idle_daydream","Daydream",2800,false,25,40000,"idle_neutral",new Channel[]{new Channel("body.rotationDeg",new double[]{0,-6,-6,0},null,false),new Channel("eyes.y",new double[]{0,-0.5,-0.5,0},null,false),new Channel("eyes.height",new double[]{1,0.65,0.65,1},null,false)},0,"",0,2800,"neutral","",""),
new Clip("idle_nod","Little Nod",1400,false,25,28000,"idle_neutral",new Channel[]{new Channel("body.y",new double[]{0,1.5,0,1,0},null,false),new Channel("body.scaleY",new double[]{1,0.96,1,0.98,1},null,false),new Channel("eyes.height",new double[]{1,0.5,1},null,false)},0,"",0,1400,"neutral","",""),
new Clip("idle_wiggle","Happy Wiggle",1600,false,25,35000,"idle_neutral",new Channel[]{new Channel("body.rotationDeg",new double[]{0,-5,5,-3,0},null,false),new Channel("body.scaleX",new double[]{1,1.025,1,1.025,1},null,false)},0,"",0,1600,"neutral","",""),
new Clip("idle_sway","Slow Sway",2600,false,25,40000,"idle_neutral",new Channel[]{new Channel("body.x",new double[]{0,-1.5,1.5,0},null,false),new Channel("body.rotationDeg",new double[]{0,-3,3,0},null,false)},0,"",0,2600,"neutral","",""),
new Clip("thinking_ponder","Ponder",2800,true,88,0,"idle_neutral",new Channel[]{new Channel("body.rotationDeg",new double[]{0,5,2,0},null,false),new Channel("eyes.x",new double[]{0,0.45,0.45,0},null,false),new Channel("eyes.y",new double[]{0,-0.4,-0.4,0},null,false)},1,"orbit",18,2800,"ai","",""),
new Clip("thinking_read","Read and Reflect",2200,true,88,0,"idle_neutral",new Channel[]{new Channel("eyes.x",new double[]{-0.5,0.5,-0.5,0.5,0},null,false),new Channel("eyes.y",new double[]{-0.25,0,0.25,0},null,false),new Channel("body.rotationDeg",new double[]{0,-2,0},null,false)},0,"",0,2200,"ai","statusDot",""),
new Clip("thinking_connect","Connecting Ideas",2600,true,88,0,"idle_neutral",new Channel[]{new Channel("eyes.leftHeight",new double[]{1,0.65,1,1},null,false),new Channel("eyes.rightHeight",new double[]{1,1,0.65,1},null,false),new Channel("body.rotationDeg",new double[]{0,-3,3,0},null,false)},2,"orbit",18,2600,"ai","","")
  };
  public static readonly Dictionary<string,Clip> ById=new Dictionary<string,Clip>();
  static Catalog(){foreach(var clip in All)ById.Add(clip.Id,clip);}
 }
}
