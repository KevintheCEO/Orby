using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Shapes;
public sealed partial class OrbyAvatarRenderer {
 Canvas waterBottle; Image liquidImage; Ellipse waterReflection; TextBlock waterPercent;
 Ellipse waterHand,waterGrip,ambientGlow,eyeGlintLeft,eyeGlintRight;
 Ellipse dryTint; Path dryCracks;
 readonly Ellipse[] droplets=new Ellipse[3];
 readonly RotateTransform waterTilt=new RotateTransform(0,7,14);
 readonly TranslateTransform waterSlide=new TranslateTransform();
 readonly RectangleGeometry waterLevel=new RectangleGeometry();
 readonly RectangleGeometry openBottle=new RectangleGeometry(new Rect(0,4,14,25));
 static readonly Geometry happyWaterLeft=Geometry.Parse("M 8,19 Q 11,11 15,19 L 13.6,19 Q 11,14.5 9.4,19 Z"),happyWaterRight=Geometry.Parse("M 21,19 Q 24.5,11 28,19 L 26.6,19 Q 24.5,14.5 22.4,19 Z");
 public double WaterProgress;
 public bool WaterVisible {get{return waterBottle!=null&&waterBottle.Visibility==Visibility.Visible;}}
 public string WaterProgressText {get{return waterPercent==null?"":waterPercent.Text;}}
 public bool RenderedWaterAssetsLoaded {get{return waterReflection!=null&&liquidImage!=null;}}
 public void StopWater(){if(active!=null&&active.Id.StartsWith("water_")){active=OrbyPack.Catalog.ById[baseId];clipStart=time.Elapsed.TotalSeconds;overrideUntil=0;Draw(clipStart);}}
 static RadialGradientBrush Light(Color color,double opacity){
  var brush=new RadialGradientBrush();brush.GradientStops.Add(new GradientStop(Color.FromArgb((byte)(255*opacity),color.R,color.G,color.B),0));brush.GradientStops.Add(new GradientStop(Color.FromArgb(0,color.R,color.G,color.B),1));brush.Freeze();return brush;
 }
 void BuildRenderedDetails(Canvas face){
  dryTint=new Ellipse{Width=36,Height=36,Fill=new SolidColorBrush(Color.FromRgb(206,183,147)),Opacity=0,IsHitTestVisible=false};face.Children.Insert(0,dryTint);
  dryCracks=new Path{Data=Geometry.Parse("M 5,25 L 9,22 L 8,18 M 9,22 L 12,25 M 30,25 L 27,28 L 29,32 M 27,28 L 24,29"),Stroke=new SolidColorBrush(Color.FromRgb(143,127,103)),StrokeThickness=.45,Opacity=0,IsHitTestVisible=false};face.Children.Add(dryCracks);
  arms.Stroke=new LinearGradientBrush(Colors.White,Color.FromRgb(177,190,196),90);arms.StrokeThickness=3;arms.StrokeStartLineCap=arms.StrokeEndLineCap=PenLineCap.Round;
  cup.Background=new LinearGradientBrush(Color.FromRgb(253,254,251),Color.FromRgb(142,164,174),0);cup.BorderBrush=Brushes.WhiteSmoke;cup.BorderThickness=new Thickness(.35);
  var reflection=new RadialGradientBrush();reflection.Center=reflection.GradientOrigin=new Point(.85,.85);reflection.RadiusX=reflection.RadiusY=.75;reflection.GradientStops.Add(new GradientStop(Color.FromArgb(125,27,194,239),0));reflection.GradientStops.Add(new GradientStop(Color.FromArgb(0,27,194,239),1));reflection.Freeze();waterReflection=new Ellipse{Fill=reflection,Width=36,Height=36,Opacity=0,IsHitTestVisible=false};face.Children.Insert(0,waterReflection);
  ambientGlow=new Ellipse{Width=47,Height=9,Fill=Light(Color.FromRgb(80,167,193),.3),IsHitTestVisible=false,Opacity=.35};Canvas.SetLeft(ambientGlow,3.5);Canvas.SetTop(ambientGlow,45);root.Children.Insert(0,ambientGlow);
  left.Fill=right.Fill=new SolidColorBrush(Color.FromRgb(17,18,18));
  eyeGlintLeft=new Ellipse{Width=.85,Height=1.1,Fill=Brushes.White,Opacity=0,IsHitTestVisible=false,RenderTransform=left.RenderTransform};Canvas.SetLeft(eyeGlintLeft,11.7);Canvas.SetTop(eyeGlintLeft,15.4);face.Children.Add(eyeGlintLeft);
  eyeGlintRight=new Ellipse{Width=.85,Height=1.1,Fill=Brushes.White,Opacity=0,IsHitTestVisible=false,RenderTransform=right.RenderTransform};Canvas.SetLeft(eyeGlintRight,24.7);Canvas.SetTop(eyeGlintRight,15.4);face.Children.Add(eyeGlintRight);
 }
 void BuildWaterBottle(){
  waterBottle=new Canvas{Width=14,Height=29,IsHitTestVisible=false,Visibility=Visibility.Collapsed};
  // Rendered glass and water are separate layers: intake changes the liquid mask, never the glass.
  var glass=new Image{Source=OrbyRenderedAssets.Image("bottle-empty"),Width=14,Height=29,Stretch=Stretch.Fill};RenderOptions.SetBitmapScalingMode(glass,BitmapScalingMode.HighQuality);waterBottle.Children.Add(glass);
  liquidImage=new Image{Source=OrbyRenderedAssets.Image("bottle-water"),Width=14,Height=29,Stretch=Stretch.Fill,Clip=waterLevel};RenderOptions.SetBitmapScalingMode(liquidImage,BitmapScalingMode.HighQuality);waterBottle.Children.Add(liquidImage);
  waterPercent=new TextBlock{Width=14,TextAlignment=TextAlignment.Center,FontSize=4.7,FontWeight=FontWeights.SemiBold,Foreground=Brushes.White};Canvas.SetTop(waterPercent,14);waterBottle.Children.Add(waterPercent);
  var transforms=new TransformGroup();transforms.Children.Add(waterTilt);transforms.Children.Add(waterSlide);waterBottle.RenderTransform=transforms;
  root.Children.Add(waterBottle);Canvas.SetLeft(waterBottle,39);Canvas.SetTop(waterBottle,15);
  var handFill=new RadialGradientBrush(Color.FromRgb(255,255,252),Color.FromRgb(176,187,190));handFill.GradientOrigin=new Point(.3,.2);handFill.Freeze();
  waterHand=new Ellipse{Width=5.6,Height=5.6,Fill=handFill,Visibility=Visibility.Collapsed,IsHitTestVisible=false};root.Children.Add(waterHand);
  waterGrip=new Ellipse{Width=5,Height=4,Fill=handFill,Visibility=Visibility.Collapsed,IsHitTestVisible=false};root.Children.Add(waterGrip);
  var dropFill=new RadialGradientBrush(Color.FromRgb(218,255,255),Color.FromRgb(27,181,233));dropFill.GradientOrigin=new Point(.25,.2);dropFill.Freeze();
  for(int i=0;i<3;i++){droplets[i]=new Ellipse{Width=1.1,Height=1.7,Fill=dropFill,Visibility=Visibility.Collapsed,IsHitTestVisible=false};root.Children.Add(droplets[i]);}
 }
 static double Smooth(double p){p=Math.Max(0,Math.Min(1,p));return p*p*(3-2*p);}
 void DrawWater(double elapsed,double p){
  if(waterBottle==null)BuildWaterBottle();
  bool water=active.Id.StartsWith("water_");bool happy=water&&(active.Id=="water_sip"||active.Id=="water_progress");
  dryTint.Opacity=dryCracks.Opacity=0;
  Visible(eyeGlintLeft,false);Visible(eyeGlintRight,false);
  bool bottle=active.Id=="water_reveal"||active.Id=="water_sip"||active.Id=="water_progress";
  Visible(waterBottle,bottle);Visible(waterHand,bottle);Visible(waterGrip,false);foreach(var drop in droplets)Visible(drop,false);
  if(active.Id=="water_skip"){
   waterReflection.Opacity=ambientGlow.Opacity=0;
   double amount=Math.Sin(Math.PI*p);dryTint.Opacity=.3*amount;dryCracks.Opacity=.6*amount;lidLeft.ScaleY=lidRight.ScaleY=.55;eyeLeftMove.Y=eyeRightMove.Y=1.5;
   return;
  }
  if(!water){waterReflection.Opacity=0;ambientGlow.Opacity=0;return;}
  double reflectedLight=0,ambient=0;
  foreach(var particle in particles)Visible(particle,false);VisibleParticleCount=0;led.Opacity=0;
  double fraction=Math.Max(0,Math.Min(1,WaterProgress));waterPercent.Text=Math.Round(fraction*100)+"%";
  double level=28-15*fraction;waterLevel.Rect=new Rect(0,level,14,29-level);liquidImage.Opacity=1;
  waterSlide.X=waterSlide.Y=0;waterTilt.Angle=0;waterBottle.Opacity=1;waterBottle.Clip=null;Canvas.SetZIndex(waterBottle,1);
  Canvas.SetLeft(waterHand,47);Canvas.SetTop(waterHand,34);waterHand.Opacity=1;
  if(active.Id=="water_reminder"||active.Id=="water_wait"){
   waterReflection.Opacity=0;ambientGlow.Opacity=0;
   // Two brief tiny droplet glints, then a quiet wait; no slow looping bounce.
   if(active.Id=="water_reminder"&&!ReducedMotion&&p<.22){for(int i=0;i<2;i++){Visible(droplets[i],true);Canvas.SetLeft(droplets[i],44+i*3);Canvas.SetTop(droplets[i],13-i*3-2*Math.Sin(p*9*Math.PI));droplets[i].Opacity=Math.Sin(Math.PI*p/.22);}}
   return;
  }
  if(active.Id=="water_reveal"){
   double q=ReducedMotion?1:Smooth(p);waterSlide.X=-16*(1-q);waterSlide.Y=4*(1-q);waterBottle.Opacity=q;
   Canvas.SetZIndex(waterBottle,p<.35?-1:1);Canvas.SetLeft(waterHand,8+39*q);Canvas.SetTop(waterHand,28+6*q);
   // A full prop for the sip. Daily intake appears only in the final progress stage.
   waterLevel.Rect=new Rect(0,0,14,29);waterPercent.Text="";reflectedLight=.18*q;ambient=.35*q;
  }else{
   left.Data=happyWaterLeft;right.Data=happyWaterRight;lidLeft.ScaleY=lidRight.ScaleY=1;eyeLeftMove.X=eyeRightMove.X=eyeLeftMove.Y=eyeRightMove.Y=0;
   if(active.Id=="water_sip"){
    // Fast lift, a short hold at the mouth, then a gentle return; all transforms render-paced.
    double sip=p<.22?Smooth(p/.22):p>.78?1-Smooth((p-.78)/.22):1;
    if(ReducedMotion)sip=.85;
    waterTilt.Angle=-76*sip;waterSlide.X=-5*sip;waterSlide.Y=-2*sip;
    waterBottle.Clip=openBottle;
    waterLevel.Rect=new Rect(0,0,14,29);waterPercent.Text="";Canvas.SetLeft(waterHand,47-3*sip);Canvas.SetTop(waterHand,34-9*sip);
    Visible(waterGrip,true);Canvas.SetLeft(waterGrip,40-4*sip);Canvas.SetTop(waterGrip,19-2*sip);
    reflectedLight=.85*sip;ambient=.7*sip;
    if(!ReducedMotion&&p>.25&&p<.82){for(int i=0;i<3;i++){
     double q=((p-.25)*2.5+i*.27)%1;Visible(droplets[i],true);Canvas.SetLeft(droplets[i],39+4*i+2*q);Canvas.SetTop(droplets[i],27+9*q*q);droplets[i].Opacity=.75*Math.Sin(Math.PI*q);
    }}
   }else if(active.Id=="water_progress"){
    double fade=p<.82?1:1-Smooth((p-.82)/.18);waterBottle.Opacity=waterHand.Opacity=fade;waterSlide.Y=2*(1-fade);reflectedLight=.28*fade;ambient=.45*fade;
    // Calm meniscus movement, under half a pixel even at the largest notch size.
    if(!ReducedMotion){double wave=Math.Sin(elapsed*4.5)*.22;waterLevel.Rect=new Rect(0,level+wave,14,Math.Max(0,29-level-wave));}
   }
  }
  waterReflection.Opacity=reflectedLight;ambientGlow.Opacity=ambient;
 }
}
