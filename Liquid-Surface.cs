using System;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Interop;
using System.Windows.Media;
public sealed class OrbyLiquidSurface : Decorator {
 public static readonly DependencyProperty MorphProperty=DependencyProperty.Register("Morph",typeof(double),typeof(OrbyLiquidSurface),new FrameworkPropertyMetadata(0.0,FrameworkPropertyMetadataOptions.AffectsRender,Changed));
 public static readonly DependencyProperty ExpandedHeightProperty=DependencyProperty.Register("ExpandedHeight",typeof(double),typeof(OrbyLiquidSurface),new FrameworkPropertyMetadata(194.0,FrameworkPropertyMetadataOptions.AffectsRender,Changed));
 public double ExpandedHeight{get{return (double)GetValue(ExpandedHeightProperty);}set{SetValue(ExpandedHeightProperty,value);}}
 public double Morph{get{return (double)GetValue(MorphProperty);}set{SetValue(MorphProperty,value);}}
 readonly StreamGeometry mask=new StreamGeometry();readonly Brush fill=new SolidColorBrush(Color.FromArgb(255,0,0,0));readonly Pen stroke=new Pen(new SolidColorBrush(Color.FromArgb(28,255,255,255)),1);
 readonly RadialGradientBrush artworkGlow=new RadialGradientBrush();readonly GradientStop artworkColor=new GradientStop(Colors.Transparent,0);bool artworkEnabled,artworkMotion;Color lastArtwork;
 IntPtr hwnd;double dpiX=1,dpiY=1;int lastLeft=-1,lastRight=-1,lastBottom=-1;Window owner;
 [DllImport("gdi32.dll")]static extern IntPtr CreateRoundRectRgn(int left,int top,int right,int bottom,int ew,int eh);
 [DllImport("gdi32.dll")]static extern bool DeleteObject(IntPtr region);
 [DllImport("user32.dll")]static extern int SetWindowRgn(IntPtr window,IntPtr region,bool redraw);
 public OrbyLiquidSurface(){Width=620;Height=374;Clip=mask;fill.Freeze();stroke.Freeze();artworkGlow.MappingMode=BrushMappingMode.Absolute;artworkGlow.Center=artworkGlow.GradientOrigin=new Point(425,24);artworkGlow.RadiusX=74;artworkGlow.RadiusY=46;artworkGlow.GradientStops.Add(artworkColor);artworkGlow.GradientStops.Add(new GradientStop(Colors.Transparent,1));Update();}
 static void Changed(DependencyObject target,DependencyPropertyChangedEventArgs args){((OrbyLiquidSurface)target).Update();}
 public void Attach(Window window){owner=window;hwnd=new WindowInteropHelper(window).Handle;var source=PresentationSource.FromVisual(window);if(source!=null){dpiX=source.CompositionTarget.TransformToDevice.M11;dpiY=source.CompositionTarget.TransformToDevice.M22;}Update();}
 void Update(){if(owner!=null){var source=PresentationSource.FromVisual(owner);if(source!=null){dpiX=source.CompositionTarget.TransformToDevice.M11;dpiY=source.CompositionTarget.TransformToDevice.M22;}}double p=Math.Max(0,Math.Min(1,Morph)),w=360+260*p,h=58+(ExpandedHeight-58)*p,r=14+8*p;
  double x=(620-w)/2;
  using(var ctx=mask.Open()){ctx.BeginFigure(new Point(x,0),true,true);ctx.LineTo(new Point(x+w,0),true,false);ctx.LineTo(new Point(x+w,h-r),true,false);ctx.QuadraticBezierTo(new Point(x+w,h),new Point(x+w-r,h),true,false);ctx.LineTo(new Point(x+r,h),true,false);ctx.QuadraticBezierTo(new Point(x,h),new Point(x,h-r),true,false);}

  if(hwnd!=IntPtr.Zero){var rect=mask.Bounds;int left=(int)((10+rect.Left)*dpiX),right=(int)Math.Ceiling((10+rect.Right)*dpiX),bottom=(int)Math.Ceiling(h*dpiY);if(left==lastLeft&&right==lastRight&&bottom==lastBottom)return;lastLeft=left;lastRight=right;lastBottom=bottom;var region=CreateRoundRectRgn(left,0,right,bottom,0,0);if(SetWindowRgn(hwnd,region,false)==0)DeleteObject(region);}
 }
 public void SetArtworkAccent(Color color,bool enabled,bool motion){
  if(artworkEnabled!=enabled){artworkEnabled=enabled;InvalidateVisual();}
  Color target=Color.FromArgb(68,color.R,color.G,color.B);
  if(lastArtwork!=target){lastArtwork=target;var fade=new System.Windows.Media.Animation.ColorAnimation(artworkColor.Color,target,TimeSpan.FromSeconds(.7));artworkColor.BeginAnimation(GradientStop.ColorProperty,fade);}
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
 protected override void OnRender(DrawingContext dc){dc.DrawGeometry(fill,stroke,mask);if(artworkEnabled && Morph<1){dc.PushOpacity(1-Math.Max(0,Morph));dc.PushClip(mask);dc.DrawRectangle(artworkGlow,null,new Rect(130,0,360,58));dc.Pop();dc.Pop();}}
}


