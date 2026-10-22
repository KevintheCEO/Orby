using System;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Interop;
using System.Windows.Media;
public sealed class OrbyLiquidSurface : Decorator {
 public static readonly DependencyProperty ExpandedWidthProperty=DependencyProperty.Register("ExpandedWidth",typeof(double),typeof(OrbyLiquidSurface),new FrameworkPropertyMetadata(620.0,FrameworkPropertyMetadataOptions.AffectsRender,Changed));
 public double ExpandedWidth{get{return (double)GetValue(ExpandedWidthProperty);}set{SetValue(ExpandedWidthProperty,value);}}
 public static readonly DependencyProperty MiniModeProperty=DependencyProperty.Register("MiniMode",typeof(bool),typeof(OrbyLiquidSurface),new FrameworkPropertyMetadata(false,FrameworkPropertyMetadataOptions.AffectsRender,Changed));
 public bool MiniMode{get{return (bool)GetValue(MiniModeProperty);}set{SetValue(MiniModeProperty,value);}}
 public static readonly DependencyProperty MiniWidthProperty=DependencyProperty.Register("MiniWidth",typeof(double),typeof(OrbyLiquidSurface),new FrameworkPropertyMetadata(200.0,FrameworkPropertyMetadataOptions.AffectsRender,Changed));
 public double MiniWidth{get{return (double)GetValue(MiniWidthProperty);}set{SetValue(MiniWidthProperty,value);}}
 public static readonly DependencyProperty MorphProperty=DependencyProperty.Register("Morph",typeof(double),typeof(OrbyLiquidSurface),new FrameworkPropertyMetadata(0.0,FrameworkPropertyMetadataOptions.AffectsRender,Changed));
 public static readonly DependencyProperty ExpandedHeightProperty=DependencyProperty.Register("ExpandedHeight",typeof(double),typeof(OrbyLiquidSurface),new FrameworkPropertyMetadata(194.0,FrameworkPropertyMetadataOptions.AffectsRender,Changed));
 public double ExpandedHeight{get{return (double)GetValue(ExpandedHeightProperty);}set{SetValue(ExpandedHeightProperty,value);}}
 public double Morph{get{return (double)GetValue(MorphProperty);}set{SetValue(MorphProperty,value);}}
 public static readonly DependencyProperty CompactWidthProperty=DependencyProperty.Register("CompactWidth",typeof(double),typeof(OrbyLiquidSurface),new FrameworkPropertyMetadata(360.0,FrameworkPropertyMetadataOptions.AffectsRender,Changed));
 public double CompactWidth{get{return (double)GetValue(CompactWidthProperty);}set{SetValue(CompactWidthProperty,value);}}
 public const double Shoulder=18,WindowPadding=24;
 public void ReserveWidth(double width){Width=Math.Max(620,width);if(owner!=null)owner.Width=Width+2*WindowPadding;Update();}
 readonly StreamGeometry mask=new StreamGeometry();readonly Brush fill=new SolidColorBrush(Color.FromArgb(255,0,0,0));readonly Pen stroke=new Pen(new SolidColorBrush(Color.FromArgb(28,255,255,255)),1);
 readonly RadialGradientBrush artworkGlow=new RadialGradientBrush();readonly GradientStop artworkColor=new GradientStop(Colors.Transparent,0);bool artworkEnabled,artworkMotion;Color lastArtwork;
 IntPtr hwnd;double dpiX=1,dpiY=1;int lastLeft=-1,lastRight=-1,lastBottom=-1;double lastMorph=double.NaN;Window owner;
 double shapeW=double.NaN,shapeH,shapeR,shapeShoulder,shapeX;NativePoint[] lastPolygon;
 public int GeometryUpdates{get;private set;}public int NativeRegionUpdates{get;private set;}
 [StructLayout(LayoutKind.Sequential)]struct NativePoint{public int X,Y;public NativePoint(int x,int y){X=x;Y=y;}}
 [DllImport("gdi32.dll")]static extern IntPtr CreatePolygonRgn([In]NativePoint[] points,int count,int mode);
 [DllImport("gdi32.dll")]static extern bool DeleteObject(IntPtr region);
 [DllImport("user32.dll")]static extern int SetWindowRgn(IntPtr window,IntPtr region,bool redraw);
 public OrbyLiquidSurface(){Width=620;Height=374;Clip=mask;fill.Freeze();stroke.Freeze();artworkGlow.MappingMode=BrushMappingMode.Absolute;artworkGlow.Center=artworkGlow.GradientOrigin=new Point(425,24);artworkGlow.RadiusX=74;artworkGlow.RadiusY=46;artworkGlow.GradientStops.Add(artworkColor);artworkGlow.GradientStops.Add(new GradientStop(Colors.Transparent,1));Update();}
 static void Changed(DependencyObject target,DependencyPropertyChangedEventArgs args){((OrbyLiquidSurface)target).Update();}
 public void Attach(Window window){owner=window;window.Width=Width+2*WindowPadding;hwnd=new WindowInteropHelper(window).Handle;var source=PresentationSource.FromVisual(window);if(source!=null){dpiX=source.CompositionTarget.TransformToDevice.M11;dpiY=source.CompositionTarget.TransformToDevice.M22;}lastMorph=double.NaN;shapeW=double.NaN;lastPolygon=null;Update();}
 void Update(){if(owner!=null){var source=PresentationSource.FromVisual(owner);if(source!=null){dpiX=source.CompositionTarget.TransformToDevice.M11;dpiY=source.CompositionTarget.TransformToDevice.M22;}}double p=Math.Max(0,Math.Min(1,Morph));double jelly=Math.Sin(Math.PI*p);double widthProgress=Math.Min(1,p+0.065*jelly),heightProgress=Math.Max(0,Math.Min(1.035,Morph-0.035*jelly));double w=360+260*widthProgress,h=58+(ExpandedHeight-58)*heightProgress,r=14+8*p+3*jelly;
  double compactWidth=MiniMode?MiniWidth:CompactWidth,compactHeight=MiniMode?20:58;
  w=compactWidth+(ExpandedWidth-compactWidth)*widthProgress;h=compactHeight+(ExpandedHeight-compactHeight)*heightProgress;
  double shoulder=MiniMode?6+12*p:Shoulder;r=(MiniMode?6:14)+(MiniMode?16:8)*p+3*jelly;
  double x=(Width-w)/2;
  if(w==shapeW && h==shapeH && r==shapeR && shoulder==shapeShoulder && x==shapeX)return;
  shapeW=w;shapeH=h;shapeR=r;shapeShoulder=shoulder;shapeX=x;GeometryUpdates++;
  using(var ctx=mask.Open()){
   // Outward shoulders attach the notch to the screen; body/content widths stay unchanged.
   ctx.BeginFigure(new Point(x-shoulder,0),true,true);ctx.LineTo(new Point(x+w+shoulder,0),true,false);
   ctx.BezierTo(new Point(x+w+shoulder*.448,0),new Point(x+w,shoulder*.448),new Point(x+w,shoulder),true,false);
   ctx.LineTo(new Point(x+w,h-r),true,false);ctx.QuadraticBezierTo(new Point(x+w,h),new Point(x+w-r,h),true,false);
   ctx.LineTo(new Point(x+r,h),true,false);ctx.QuadraticBezierTo(new Point(x,h),new Point(x,h-r),true,false);
   ctx.LineTo(new Point(x,shoulder),true,false);
   ctx.BezierTo(new Point(x,shoulder*.448),new Point(x-shoulder*.448,0),new Point(x-shoulder,0),true,false);
  }

  if(hwnd!=IntPtr.Zero){var rect=mask.Bounds;double offset=(owner.Width-Width)/2;int left=(int)((offset+rect.Left)*dpiX),right=(int)Math.Ceiling((offset+rect.Right)*dpiX),bottom=(int)Math.Ceiling(h*dpiY);if(left==lastLeft&&right==lastRight&&bottom==lastBottom&&lastMorph==Morph)return;lastLeft=left;lastRight=right;lastBottom=bottom;lastMorph=Morph;
   var points=new System.Collections.Generic.List<NativePoint>();
   foreach(var figure in mask.GetFlattenedPathGeometry(.25,ToleranceType.Absolute).Figures){
    points.Add(new NativePoint((int)Math.Round((offset+figure.StartPoint.X)*dpiX),(int)Math.Round(figure.StartPoint.Y*dpiY)));
    foreach(var segment in figure.Segments){var poly=segment as PolyLineSegment;if(poly!=null)foreach(Point pt in poly.Points)points.Add(new NativePoint((int)Math.Round((offset+pt.X)*dpiX),(int)Math.Round(pt.Y*dpiY)));var line=segment as LineSegment;if(line!=null)points.Add(new NativePoint((int)Math.Round((offset+line.Point.X)*dpiX),(int)Math.Round(line.Point.Y*dpiY)));}
   }
   var polygon=points.ToArray();bool same=lastPolygon!=null && polygon.Length==lastPolygon.Length;
   if(same)for(int i=0;i<polygon.Length;i++)if(polygon[i].X!=lastPolygon[i].X||polygon[i].Y!=lastPolygon[i].Y){same=false;break;}
   if(!same){var region=CreatePolygonRgn(polygon,polygon.Length,1);if(region!=IntPtr.Zero){if(SetWindowRgn(hwnd,region,false)==0)DeleteObject(region);else{lastPolygon=polygon;NativeRegionUpdates++;}}}
  }
 }
 public void SetArtworkAccent(Color color,bool enabled,bool motion){
  enabled=enabled && color.A>0;
  if(artworkEnabled!=enabled){artworkEnabled=enabled;InvalidateVisual();}
  Color target=Color.FromArgb((byte)Math.Min(68,color.A*68.0/110),color.R,color.G,color.B);
  if(lastArtwork!=target){lastArtwork=target;var from=Color.FromArgb(artworkColor.Color.A,target.R,target.G,target.B);var fade=new System.Windows.Media.Animation.ColorAnimation(from,target,TimeSpan.FromSeconds(.7));artworkColor.BeginAnimation(GradientStop.ColorProperty,fade);}
  bool run=enabled&&motion;
  if(run!=artworkMotion){artworkMotion=run;artworkGlow.BeginAnimation(RadialGradientBrush.CenterProperty,null);artworkGlow.BeginAnimation(RadialGradientBrush.GradientOriginProperty,null);artworkGlow.BeginAnimation(RadialGradientBrush.RadiusXProperty,null);
   if(run){var ease=new System.Windows.Media.Animation.SineEase{EasingMode=System.Windows.Media.Animation.EasingMode.EaseInOut};
    var drift=new System.Windows.Media.Animation.PointAnimation(new Point(425,24),new Point(432,27),TimeSpan.FromSeconds(18)){AutoReverse=true,RepeatBehavior=System.Windows.Media.Animation.RepeatBehavior.Forever,EasingFunction=ease};
    artworkGlow.BeginAnimation(RadialGradientBrush.CenterProperty,drift);artworkGlow.BeginAnimation(RadialGradientBrush.GradientOriginProperty,drift);
    var breathe=new System.Windows.Media.Animation.DoubleAnimation(74,80,TimeSpan.FromSeconds(12)){AutoReverse=true,RepeatBehavior=System.Windows.Media.Animation.RepeatBehavior.Forever,EasingFunction=ease};artworkGlow.BeginAnimation(RadialGradientBrush.RadiusXProperty,breathe);
   }
  }
 }
 public bool ArtworkAccentVisible{get{return artworkEnabled;}}
 protected override void OnRender(DrawingContext dc){dc.DrawGeometry(fill,stroke,mask);if(artworkEnabled && Morph<1){dc.PushOpacity(1-Math.Max(0,Morph));dc.PushClip(mask);dc.PushTransform(new TranslateTransform((Width-620)/2+(MiniMode?-29+(MiniWidth-200)/2:(CompactWidth-360)/2),0));dc.DrawRectangle(artworkGlow,null,new Rect(130,0,360,58));dc.Pop();dc.Pop();dc.Pop();}}
}



// Lightweight, non-interactive music perimeter; starts at twelve o'clock.
public sealed class OrbyArtworkProgress : FrameworkElement {
 public static readonly DependencyProperty ProgressProperty=DependencyProperty.Register("Progress",typeof(double),typeof(OrbyArtworkProgress),new FrameworkPropertyMetadata(0.0,FrameworkPropertyMetadataOptions.AffectsRender));
 public double Progress{get{return (double)GetValue(ProgressProperty);}set{SetValue(ProgressProperty,value);}}
 readonly Point[] samples=new Point[161];readonly Pen pen;
 public OrbyArtworkProgress(){
  IsHitTestVisible=false;Opacity=.6;
  var brush=new SolidColorBrush(Color.FromRgb(184,184,184));brush.Freeze();
  pen=new Pen(brush,1.25){StartLineCap=PenLineCap.Round,EndLineCap=PenLineCap.Round,LineJoin=PenLineJoin.Round};pen.Freeze();
  var path=new StreamGeometry();using(var c=path.Open()){
   c.BeginFigure(new Point(16,-3),true,false);c.LineTo(new Point(26,-3),true,false);c.ArcTo(new Point(35,6),new Size(9,9),0,false,SweepDirection.Clockwise,true,false);
   c.LineTo(new Point(35,26),true,false);c.ArcTo(new Point(26,35),new Size(9,9),0,false,SweepDirection.Clockwise,true,false);
   c.LineTo(new Point(6,35),true,false);c.ArcTo(new Point(-3,26),new Size(9,9),0,false,SweepDirection.Clockwise,true,false);
   c.LineTo(new Point(-3,6),true,false);c.ArcTo(new Point(6,-3),new Size(9,9),0,false,SweepDirection.Clockwise,true,false);c.LineTo(new Point(16,-3),true,false);
  }var perimeter=path.GetFlattenedPathGeometry(.05,ToleranceType.Absolute);perimeter.Freeze();
  for(int i=0;i<samples.Length;i++){Point point,tangent;perimeter.GetPointAtFractionLength(i/160.0,out point,out tangent);samples[i]=point;}
 }
 public Point PointAt(double fraction){double step=Math.Max(0,Math.Min(1,fraction))*160;int i=Math.Min(159,(int)step);double mix=step-i;return new Point(samples[i].X+(samples[i+1].X-samples[i].X)*mix,samples[i].Y+(samples[i+1].Y-samples[i].Y)*mix);}
 protected override void OnRender(DrawingContext dc){
  double p=Progress;if(double.IsNaN(p)||double.IsInfinity(p)||p<=0)return;p=Math.Min(1,p);
  var trace=new StreamGeometry();using(var c=trace.Open()){
   c.BeginFigure(PointAt(0),false,false);int steps=Math.Max(1,(int)Math.Ceiling(160*p));for(int i=1;i<=steps;i++)c.LineTo(PointAt(p*i/steps),true,false);
  }trace.Freeze();dc.DrawGeometry(null,pen,trace);
 }
}
