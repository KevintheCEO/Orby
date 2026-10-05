using System;
using OrbyPack;
using System.Collections;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Shapes;
public sealed class OrbyAvatarRenderer : IDisposable {
 public OrbyAvatarRenderer SyncWith;
 public void DrawSyncedFrame(){
  var source=SyncWith;if(source==null)return;
  active=source.active;baseId=source.baseId;clipStart=source.clipStart;state=source.state;stateKey=source.stateKey;action=source.action;
  blinkStart=source.blinkStart;nextBlink=source.nextBlink;overrideUntil=source.overrideUntil;
  ReducedMotion=source.ReducedMotion;MusicPlaying=source.MusicPlaying;CursorX=source.CursorX;CursorY=source.CursorY;
  Progress=source.Progress;AudioEnvelope=source.AudioEnvelope;Draw(source.TimeSeconds);
 }
 readonly RotateTransform rotation=new RotateTransform(); readonly ScaleTransform scale=new ScaleTransform();readonly TranslateTransform translate=new TranslateTransform();
 readonly ScaleTransform lidLeft=new ScaleTransform(1,1,11,18),lidRight=new ScaleTransform(1,1,24,18);
 readonly TranslateTransform eyeLeftMove=new TranslateTransform(),eyeRightMove=new TranslateTransform();
 readonly Ellipse[] particles=new Ellipse[6];readonly FrameworkElement body;readonly Canvas root;
 readonly Ellipse listeningRing=new Ellipse{Width=42,Height=42,Stroke=Brushes.DodgerBlue,StrokeThickness=1};
 readonly Path arms=new Path{Stroke=Brushes.LightSlateGray,StrokeThickness=1.4};readonly Canvas headphone=CreateHeadphones();
 readonly Border cup=new Border{Width=7,Height=6,Background=Brushes.LightSlateGray,CornerRadius=new CornerRadius(1)};
 [StructLayout(LayoutKind.Sequential)]struct InputStamp{public uint Size,Tick;}
 [StructLayout(LayoutKind.Sequential)]struct Pointer{public int X,Y;}
 [DllImport("user32.dll")]static extern bool GetLastInputInfo(ref InputStamp stamp);
 [DllImport("user32.dll")]static extern bool GetCursorPos(out Pointer point);
 double inputPoll,nextIdleAt;bool sleeping;string lastIdleId="";
 readonly Random personality=new Random(Guid.NewGuid().GetHashCode());
 public static readonly string[] IdleGestures={"curious_tilt","look_left_right","look_up_down","blink_double","eye_peek","tiny_arms","bored_idle","playful_bounce","idle_shuffle","idle_stretch","idle_ponder","idle_double_hop","idle_toe_tap","idle_peek_around","idle_daydream","idle_nod","idle_wiggle","idle_sway"};
 public static readonly string[] ThinkingGestures={"thinking_basic","thinking_deep","thinking_ponder","thinking_read","thinking_connect"};
 double nextThinkingAt;
 public double NextThinkingAt{get{return nextThinkingAt;}}
 public void AdvanceThinking(double now){
  if(ReducedMotion || state!="working" || !(action.Contains("thinking")||action.Contains("reasoning")) || now<nextThinkingAt || overrideUntil>now)return;
  int i=personality.Next(ThinkingGestures.Length);
  if(ThinkingGestures[i]==active.Id)i=(i+1)%ThinkingGestures.Length;
  baseId=ThinkingGestures[i];active=Catalog.ById[baseId];clipStart=now;nextThinkingAt=now+12+personality.NextDouble()*12;ClearParticles();
 }
 public double NextIdleAt{get{return nextIdleAt;}}
 readonly Pose pose=new Pose();Clip active;string baseId="idle_neutral";double clipStart,blinkStart=-100,nextBlink=3,overrideUntil;string stateKey="";
 readonly System.Collections.Generic.Dictionary<string,double> cooldowns=new System.Collections.Generic.Dictionary<string,double>();
 public bool MusicPlaying;public bool HeadphonesVisible{get{return headphone.Visibility==Visibility.Visible;}}
 readonly TranslateTransform headphoneMove=new TranslateTransform();double headphonesHiddenUntil;
 public void PetClicked(){headphonesHiddenUntil=time.Elapsed.TotalSeconds+2;}
 public bool PetHovered;
 public bool ReducedMotion;public double Progress=-1,CursorX,CursorY,AudioEnvelope=double.NaN;public string ActiveId{get{return active==null?"idle_neutral":active.Id;}}public int VisibleParticleCount;
 static Canvas CreateHeadphones(){
  var canvas=new Canvas{Width=54,Height=40,IsHitTestVisible=false};
  var blue=new SolidColorBrush(Color.FromRgb(52,157,245));blue.Freeze();
  var band=Geometry.Parse("M 9,20 C 9,-6 45,-6 45,20");band.Freeze();
  canvas.Children.Add(new Path{Data=band,Stroke=blue,StrokeThickness=3.5,StrokeStartLineCap=PenLineCap.Round,StrokeEndLineCap=PenLineCap.Round});
  foreach(double x in new double[]{5.5,41.5}){
   var ear=new Border{Width=7,Height=13,CornerRadius=new CornerRadius(3.2),Background=blue};
   Canvas.SetLeft(ear,x);Canvas.SetTop(ear,14);canvas.Children.Add(ear);
  }
  return canvas;
 }
 static readonly Geometry armPeek=Geometry.Parse("M 8,23 Q 3,23 3,19 M 45,23 Q 50,23 50,19"),armWave=Geometry.Parse("M 8,23 Q 3,23 3,19 M 45,23 Q 50,18 49,13");
 readonly Path left,right,pattern;readonly FrameworkElement white,black,led,check,ask;readonly Stopwatch time=Stopwatch.StartNew();
 string state="idle",action="";TimeSpan last=TimeSpan.MinValue;public long Frames;public double MaxFrameGapMs;double prev;double started;readonly double[] gaps=new double[4096];int gapCount;
 static readonly Geometry[] geometries=new Geometry[]{
  Geometry.Parse("M 11,15 A 2.4,3.5 0 1 1 11,22 A 2.4,3.5 0 1 1 11,15 Z"),
  Geometry.Parse("M 24,15 A 2.4,3.5 0 1 1 24,22 A 2.4,3.5 0 1 1 24,15 Z"),
  Geometry.Parse("M 9,13 A 2,4.5 0 1 1 9,22 A 2,4.5 0 1 1 9,13 Z M 18,11 A 2.5,6.5 0 1 1 18,24 A 2.5,6.5 0 1 1 18,11 Z M 27,13 A 2,4.5 0 1 1 27,22 A 2,4.5 0 1 1 27,13 Z"),
  Geometry.Parse("M 8,18 Q 11,16 15,16 L 14,20 Q 10,22 8,18 Z"),
  Geometry.Parse("M 22,16 Q 26,16 29,18 Q 27,22 23,20 Z"),
  Geometry.Parse("M 12,12 A 2.3,4.5 0 1 1 12,21 A 2.3,4.5 0 1 1 12,12 Z"),
  Geometry.Parse("M 23,12 A 2.3,4.5 0 1 1 23,21 A 2.3,4.5 0 1 1 23,12 Z"),
  Geometry.Parse("M 18,5 A 5.4,5.4 0 1 1 18,15.8 A 5.4,5.4 0 1 1 18,5 Z M 12,17 A 5.4,5.4 0 1 1 12,27.8 A 5.4,5.4 0 1 1 12,17 Z M 24,17 A 5.4,5.4 0 1 1 24,27.8 A 5.4,5.4 0 1 1 24,17 Z"),
  Geometry.Parse("M 18,0 A 18,18 0 0 1 18,36 A 9,9 0 0 1 18,18 A 9,9 0 0 0 18,0 Z"),
  Geometry.Parse("M 11,12 A 2.8,5 0 1 1 11,22 A 2.8,5 0 1 1 11,12 Z"),
  Geometry.Parse("M 24,12 A 2.8,5 0 1 1 24,22 A 2.8,5 0 1 1 24,12 Z"),
  Geometry.Parse("M 7,16 Q 11,21 15,16 Q 14,23 11,23 Q 8,23 7,16 Z"),
  Geometry.Parse("M 21,16 Q 25,21 29,16 Q 28,23 25,23 Q 22,23 21,16 Z"),
  Geometry.Parse("M 8,14 L 10,14 L 15,21 L 13,22 Z M 13,14 L 15,14 L 10,22 L 8,21 Z"),
  Geometry.Parse("M 21,14 L 23,14 L 28,21 L 26,22 Z M 26,14 L 28,14 L 23,22 L 21,21 Z"),
  Geometry.Parse("M 8,18 Q 11,17 15,18 L 15,19 Q 11,20 8,19 Z"),
  Geometry.Parse("M 21,18 Q 25,17 28,18 L 28,19 Q 25,20 21,19 Z"),
 };
 static OrbyAvatarRenderer(){foreach(var g in geometries)g.Freeze();}
 public OrbyAvatarRenderer(IDictionary parts){
  body=(FrameworkElement)parts["OrbBody"];root=(Canvas)parts["Root"];var face=(FrameworkElement)parts["OrbFace"];
  left=(Path)parts["OrbEyeL"];right=(Path)parts["OrbEyeR"];var lg=new TransformGroup();lg.Children.Add(lidLeft);lg.Children.Add(eyeLeftMove);left.RenderTransform=lg;
  var rg=new TransformGroup();rg.Children.Add(lidRight);rg.Children.Add(eyeRightMove);right.RenderTransform=rg;pattern=(Path)parts["OrbPattern"];
  white=(FrameworkElement)parts["OrbWhiteDot"];black=(FrameworkElement)parts["OrbBlackDot"];led=(FrameworkElement)parts["OrbLed"];check=(FrameworkElement)parts["OrbCheck"];ask=(FrameworkElement)parts["OrbAsk"];
  var group=new TransformGroup();group.Children.Add(scale);group.Children.Add(translate);body.RenderTransform=group;face.RenderTransform=rotation;
  for(int i=0;i<particles.Length;i++){particles[i]=new Ellipse{Width=3.2,Height=3.2,Fill=Brushes.DodgerBlue,Visibility=Visibility.Collapsed};root.Children.Add(particles[i]);}
  arms.Visibility=cup.Visibility=headphone.Visibility=Visibility.Collapsed;root.Children.Add(headphone);root.Children.Add(listeningRing);Canvas.SetLeft(listeningRing,6);Canvas.SetTop(listeningRing,7);listeningRing.Visibility=Visibility.Collapsed;root.Children.Add(arms);root.Children.Add(cup);Canvas.SetLeft(cup,38);Canvas.SetTop(cup,34);Canvas.SetTop(arms,9);Canvas.SetTop(headphone,9);
  headphone.RenderTransform=headphoneMove;root.PreviewMouseLeftButtonDown+=(sender,args)=>PetClicked();
  active=Catalog.ById["startup_boot"];clipStart=time.Elapsed.TotalSeconds;nextIdleAt=clipStart+8+personality.NextDouble()*8;
  CompositionTarget.Rendering+=Render;
 }
 public void SetState(string value,string text){
  // Open and idle share the same pet state; detector polls must not restart its rest timer.
  if(value=="open")value="idle";
  string key=value+"|"+(text??"");if(key==stateKey)return;stateKey=key;state=value;action=(text??"").ToLowerInvariant();
  switch(state){
   case "working":baseId=action.Contains("thinking")||action.Contains("reasoning")?ThinkingGestures[personality.Next(ThinkingGestures.Length)]:action.Contains("search")||action.Contains("read")||action.Contains("inspect")?"thinking_search":action.Contains("command")?"working_fast":"working_normal";break;
   case "attention":baseId="waiting_user";break;case "success":baseId="task_complete";break;case "error":baseId="error_failure";break;
   case "stopped":baseId="stopped_cancelled";break;case "paused":baseId="paused_idle";break;case "offline":baseId="offline_idle";break;
   case "music":baseId="music_mode";break;case "notification":baseId="notification";break;default:baseId="idle_neutral";break;
  }
  sleeping=false;overrideUntil=0;active=Catalog.ById[baseId];clipStart=time.Elapsed.TotalSeconds;nextIdleAt=clipStart+8+personality.NextDouble()*8;nextThinkingAt=clipStart+10+personality.NextDouble()*8;ClearParticles();
 }
 public bool Trigger(string id){return TriggerAt(id,time.Elapsed.TotalSeconds);}
 bool TriggerAt(string id,double now){
  Clip next;if(!Catalog.ById.TryGetValue(id,out next))return false;
  if(state=="working"||state=="attention"||state=="error"||state=="success"||state=="stopped"||state=="paused"||state=="offline"){if(next.Priority<Catalog.ById[baseId].Priority)return false;}
  double lastTime;if(cooldowns.TryGetValue(id,out lastTime) && (now-lastTime)*1000<next.Cooldown)return false;
  cooldowns[id]=now;active=next;clipStart=now;overrideUntil=now+Math.Max(0.001,next.Duration/1000.0);ClearParticles();return true;
 }
 public void Preview(string id){active=Catalog.ById[id];clipStart=time.Elapsed.TotalSeconds;overrideUntil=0;state="preview";ClearParticles();}
 static void Visible(UIElement element,bool value){var visibility=value?Visibility.Visible:Visibility.Collapsed;if(element.Visibility!=visibility)element.Visibility=visibility;}
 void ClearParticles(){foreach(var particle in particles)Visible(particle,false);Visible(arms,false);Visible(cup,false);Visible(headphone,false);Visible(listeningRing,false);VisibleParticleCount=0;}
 public void Draw(double t){
  if(active==null)return;double elapsed=Math.Max(0,t-clipStart),duration=Math.Max(0.001,active.Duration/1000.0);
  if(!active.Loop && elapsed>duration && state!="preview"){
   string next=overrideUntil>0?baseId:active.Exit;
   if(!Catalog.ById.ContainsKey(next))next="idle_neutral";active=Catalog.ById[next];clipStart=t;overrideUntil=0;elapsed=0;duration=Math.Max(0.001,active.Duration/1000.0);
  }
  double p=active.Loop?(elapsed%duration)/duration:Math.Min(1,elapsed/duration);
  pose.Reset();pose.Apply(active,p);
  if(state!="preview" && baseId=="idle_neutral" && active.Id=="idle_neutral"){pose.EyeX=CursorX*0.4;pose.EyeY=CursorY*0.3;}

  double cursorX=CursorX,cursorY=CursorY,audio=AudioEnvelope;
  if(state=="preview"){cursorX=Math.Sin(elapsed*2);cursorY=Math.Cos(elapsed*1.3)*0.6;if(double.IsNaN(audio))audio=0.5+0.5*Math.Sin(elapsed*8);}
  if(active.Id=="drag_orbit"||active.Id=="dragged_too_fast"){pose.X=cursorX*3;pose.Y=cursorY*2;pose.Rotation=cursorX*6;pose.EyeX=cursorX*0.65;pose.EyeY=cursorY*0.45;}
  if(active.Id=="window_appears"||active.Id=="window_close"||active.Id=="volume_change"){pose.EyeX=cursorX==0?0.5:cursorX;pose.EyeY=cursorY;}

  if(active.Id=="cursor_follow"||active.Id=="rare_stare"){pose.EyeX=cursorX;pose.EyeY=cursorY;}
  if(active.Id=="tool_use"){pose.EyeX=0.45;pose.EyeY=-0.15;}
  bool listening=MusicPlaying && (state=="music" || state=="idle" || state=="open");
  if(listening && !ReducedMotion){pose.Y+=Math.Sin(t*3.1)*0.8;pose.Rotation+=Math.Sin(t*1.55)*2;pose.EyeHeight*=0.92;}
  if(active.Id=="music_mode" && !double.IsNaN(audio)){pose.ScaleY=0.99+0.03*Math.Max(0,Math.Min(1,audio));pose.EyeY=-0.15+0.3*audio;}
  if(active.Id=="rare_eye_roll"){pose.EyeX=Math.Cos(p*Math.PI*2)*0.6;pose.EyeY=Math.Sin(p*Math.PI*2)*0.4;}
  if(active.Id=="rare_dizzy"){pose.EyeX=Math.Cos(elapsed*Math.PI*5)*0.7;pose.LeftY=Math.Sin(elapsed*Math.PI*5)*0.4;pose.RightY=-pose.LeftY;}
  if(t>=nextBlink && active.Id!="rare_stare" && active.Id!="sleep_afk"){blinkStart=t;nextBlink=t+3.0+0.8*((Frames/17)%5);}
  double blink=1;if(t-blinkStart<0.18)blink=Catalog.ById["blink_natural"].Channels[0].Value((t-blinkStart)/0.18);
  if(left.Data!=geometries[0])left.Data=geometries[0];if(right.Data!=geometries[1])right.Data=geometries[1];Visible(left,true);Visible(right,true);Visible(pattern,false);Visible(white,false);Visible(black,false);
  lidLeft.ScaleX=lidRight.ScaleX=Math.Max(0.05,pose.EyeWidth);lidLeft.ScaleY=Math.Max(0.02,pose.EyeHeight*pose.LeftHeight*blink);lidRight.ScaleY=Math.Max(0.02,pose.EyeHeight*pose.RightHeight*blink);
  eyeLeftMove.X=eyeRightMove.X=Math.Max(-1,Math.Min(1,pose.EyeX))*4.3;eyeLeftMove.Y=(pose.EyeY+pose.LeftY)*3.6;eyeRightMove.Y=(pose.EyeY+pose.RightY)*3.6;
  rotation.Angle=ReducedMotion?Math.Max(-2,Math.Min(2,pose.Rotation)):pose.Rotation;
  scale.ScaleX=ReducedMotion?1:pose.ScaleX;scale.ScaleY=ReducedMotion?1:pose.ScaleY;
  translate.X=ReducedMotion?Math.Max(-2,Math.Min(2,pose.X)):pose.X;translate.Y=ReducedMotion?Math.Max(-2,Math.Min(2,pose.Y)):pose.Y;body.Opacity=pose.Opacity;
  Brush color=active.Color=="success"?Brushes.MediumSeaGreen:active.Color=="warning"?Brushes.Goldenrod:active.Color=="error"?Brushes.Coral:active.Color=="neutral"?Brushes.LightSlateGray:Brushes.DodgerBlue;
  double radius=active.Radius*0.78;VisibleParticleCount=ReducedMotion?0:Math.Min(6,active.Count);
  for(int i=0;i<6;i++){
   var particle=particles[i];Visible(particle,i<VisibleParticleCount);if(i>=VisibleParticleCount)continue;
   double a=elapsed*2*Math.PI/Math.Max(0.1,active.Period/1000.0)+i*2*Math.PI/Math.Max(1,active.Count),distance=radius,opacity=1;
   if(active.ParticleMode.Contains("burst")){a=i*2*Math.PI/Math.Max(1,active.Count);distance=radius*Math.Sin(p*Math.PI);opacity=Math.Sin(p*Math.PI);}
   if(active.ParticleMode=="dart_away_then_vanish"){a=-0.5;distance=radius*(0.2+p);opacity=1-p;}
   if(active.ParticleMode=="progressOrbit" && Progress>=0){a=-Math.PI/2+2*Math.PI*Math.Max(0,Math.Min(1,Progress));}
   particle.Fill=color;particle.Opacity=opacity;Canvas.SetLeft(particle,25.4+Math.Cos(a)*distance);Canvas.SetTop(particle,26.4+Math.Sin(a)*distance);
   if(active.Id=="orbiting_dot_game"||active.Id=="catch_dot"){eyeLeftMove.X=eyeRightMove.X=Math.Cos(a)*3;eyeLeftMove.Y=eyeRightMove.Y=Math.Sin(a)*2;}
  }
  Visible(arms,active.Indicator=="optionalArms");if(arms.Visibility==Visibility.Visible){arms.Data=active.Pose=="wave"?armWave:armPeek;arms.RenderTransform=rotation;arms.Opacity=Math.Sin(p*Math.PI);}
  Visible(listeningRing,active.Indicator=="ring");listeningRing.Opacity=0.45+0.3*Math.Sin(elapsed*4);
  Visible(cup,active.Pose=="tiny_cup");Visible(headphone,false);
  headphoneMove.X=ReducedMotion?0:pose.X;headphoneMove.Y=ReducedMotion?0:pose.Y;
  check.Opacity=state=="success"?1:0;ask.Opacity=state=="attention"?1:0;
  bool indicator=active.Indicator.Length>0 && active.Indicator!="optionalArms" && active.Indicator!="prop";
  led.Opacity=indicator||state=="working"||state=="attention"||state=="error"?1:0;((Shape)led).Fill=state=="error"?Brushes.Coral:state=="attention"?Brushes.Goldenrod:color;
 }
 void Render(object sender,EventArgs args){var rendering=(RenderingEventArgs)args;if(rendering.RenderingTime==last)return;last=rendering.RenderingTime;
  if(SyncWith!=null){DrawSyncedFrame();return;}
  double now=time.Elapsed.TotalSeconds;if(prev>0){double gap=(now-prev)*1000;MaxFrameGapMs=Math.Max(MaxFrameGapMs,gap);gaps[gapCount%gaps.Length]=gap;gapCount++;}else started=now;prev=now;Frames++;
  if(now-inputPoll>=0.1){inputPoll=now;Pointer cursor;
   if(GetCursorPos(out cursor) && PresentationSource.FromVisual(root)!=null){var center=root.PointToScreen(new Point(27,28));CursorX=Math.Max(-1,Math.Min(1,(cursor.X-center.X)/140));CursorY=Math.Max(-1,Math.Min(1,(cursor.Y-center.Y)/140));}
   var input=new InputStamp{Size=8};bool afk=GetLastInputInfo(ref input) && unchecked((uint)Environment.TickCount-input.Tick)>300000;
   AdvanceIdle(now,afk);AdvanceThinking(now);
  }
  Draw(now);
 }
 // One brief gesture followed by a randomized rest. Never impersonates a task state.
 public void AdvanceIdle(double now,bool afk){
  if((state!="idle" && state!="open") || baseId!="idle_neutral")return;
  if(afk && !sleeping){sleeping=true;active=Catalog.ById["sleep_afk"];clipStart=now;overrideUntil=0;ClearParticles();return;}
  if(!afk && sleeping){sleeping=false;active=Catalog.ById["wake_up"];clipStart=now;overrideUntil=0;nextIdleAt=now+18+personality.NextDouble()*20;return;}
  if(sleeping || ReducedMotion || active.Id!="idle_neutral" || now<nextIdleAt)return;
  int first=personality.Next(IdleGestures.Length);
  for(int i=0;i<IdleGestures.Length;i++){
   string id=IdleGestures[(first+i)%IdleGestures.Length];
   if(id==lastIdleId)continue;
   if(TriggerAt(id,now)){lastIdleId=id;break;}
  }
  nextIdleAt=now+18+personality.NextDouble()*20;
 }
 public double TimeSeconds{get{return time.Elapsed.TotalSeconds;}}
 public double ObservedFps{get{return (Frames-1)/Math.Max(0.001,time.Elapsed.TotalSeconds-started);}}
 public double P95FrameMs{get{int n=Math.Min(gapCount,gaps.Length);if(n==0)return 0;var copy=new double[n];Array.Copy(gaps,copy,n);Array.Sort(copy);return copy[(int)((n-1)*0.95)];}}
 public void Dispose(){CompositionTarget.Rendering-=Render;}
}
public static class OrbyDisplay {
 [DllImport("user32.dll",CharSet=CharSet.Unicode)]static extern bool EnumDisplaySettings(string name,int mode,IntPtr settings);
 public static int RefreshHz(string device){IntPtr ptr=Marshal.AllocHGlobal(220);try{Marshal.Copy(new byte[220],0,ptr,220);Marshal.WriteInt16(ptr,68,220);if(!EnumDisplaySettings(device,-1,ptr))return 0;return Marshal.ReadInt32(ptr,184);}finally{Marshal.FreeHGlobal(ptr);}}
}


