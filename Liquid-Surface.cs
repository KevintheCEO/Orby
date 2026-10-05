using System;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Interop;
using System.Windows.Media;
public sealed class OrbyLiquidSurface : Decorator {
 public static readonly DependencyProperty MorphProperty=DependencyProperty.Register("Morph",typeof(double),typeof(OrbyLiquidSurface),new FrameworkPropertyMetadata(0.0,FrameworkPropertyMetadataOptions.AffectsRender,Changed));
 public double Morph{get{return (double)GetValue(MorphProperty);}set{SetValue(MorphProperty,value);}}
 readonly StreamGeometry mask=new StreamGeometry();readonly Brush fill=new SolidColorBrush(Color.FromArgb(244,8,8,10));readonly Pen stroke=new Pen(new SolidColorBrush(Color.FromArgb(43,255,255,255)),1);
 IntPtr hwnd;double dpiX=1,dpiY=1;
 [DllImport("gdi32.dll")]static extern IntPtr CreateRoundRectRgn(int left,int top,int right,int bottom,int ew,int eh);
 [DllImport("gdi32.dll")]static extern bool DeleteObject(IntPtr region);
 [DllImport("user32.dll")]static extern int SetWindowRgn(IntPtr window,IntPtr region,bool redraw);
 public OrbyLiquidSurface(){Width=620;Height=374;Clip=mask;fill.Freeze();stroke.Freeze();Update();}
 static void Changed(DependencyObject target,DependencyPropertyChangedEventArgs args){((OrbyLiquidSurface)target).Update();}
 public void Attach(Window window){hwnd=new WindowInteropHelper(window).Handle;var source=PresentationSource.FromVisual(window);if(source!=null){dpiX=source.CompositionTarget.TransformToDevice.M11;dpiY=source.CompositionTarget.TransformToDevice.M22;}Update();}
 void Update(){double p=Math.Max(0,Math.Min(1,Morph)),w=360+260*p,h=58+172*p,r=14+8*p;
  double x=(620-w)/2;
  using(var ctx=mask.Open()){ctx.BeginFigure(new Point(x,0),true,true);ctx.LineTo(new Point(x+w,0),true,false);ctx.LineTo(new Point(x+w,h-r),true,false);ctx.QuadraticBezierTo(new Point(x+w,h),new Point(x+w-r,h),true,false);ctx.LineTo(new Point(x+r,h),true,false);ctx.QuadraticBezierTo(new Point(x,h),new Point(x,h-r),true,false);}

  if(hwnd!=IntPtr.Zero){var rect=mask.Bounds;var region=CreateRoundRectRgn((int)((10+rect.Left)*dpiX),0,(int)Math.Ceiling((10+rect.Right)*dpiX),(int)Math.Ceiling(h*dpiY),0,0);if(SetWindowRgn(hwnd,region,false)==0)DeleteObject(region);}
 }
 protected override void OnRender(DrawingContext dc){dc.DrawGeometry(fill,stroke,mask);}
}
