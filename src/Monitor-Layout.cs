using System;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Threading;
public static class OrbyMonitorLayout {
 [StructLayout(LayoutKind.Sequential)] struct Rect {public int Left,Top,Right,Bottom;}
 [StructLayout(LayoutKind.Sequential)] struct MonitorInfo {public int Size;public Rect Monitor,Work;public uint Flags;}
 [DllImport("user32.dll")] static extern IntPtr MonitorFromWindow(IntPtr window,uint flags);
 [DllImport("user32.dll")] static extern bool GetMonitorInfo(IntPtr monitor,ref MonitorInfo info);
 [DllImport("user32.dll")] static extern uint GetDpiForWindow(IntPtr window);
 public static double Center(double left,double width,double windowWidth,double scale){return Math.Round((left+(width-windowWidth*scale)/2)/scale*scale)/scale;}
 public static double AvailableWidth(Window window){var handle=new WindowInteropHelper(window).Handle;var info=new MonitorInfo();info.Size=Marshal.SizeOf(info);if(handle==IntPtr.Zero||!GetMonitorInfo(MonitorFromWindow(handle,2),ref info))return SystemParameters.PrimaryScreenWidth;double dpi=96;try{dpi=GetDpiForWindow(handle);}catch(EntryPointNotFoundException){}return (info.Monitor.Right-info.Monitor.Left)/Math.Max(1,dpi/96.0);}
 public static double AvailableHeight(Window window){var handle=new WindowInteropHelper(window).Handle;var info=new MonitorInfo();info.Size=Marshal.SizeOf(info);if(handle==IntPtr.Zero||!GetMonitorInfo(MonitorFromWindow(handle,2),ref info))return SystemParameters.WorkArea.Height;double dpi=96;try{dpi=GetDpiForWindow(handle);}catch(EntryPointNotFoundException){}return (info.Work.Bottom-info.Monitor.Top)/Math.Max(1,dpi/96.0);}
 public static void Position(Window window){var handle=new WindowInteropHelper(window).Handle;if(handle==IntPtr.Zero)return;var info=new MonitorInfo();info.Size=Marshal.SizeOf(info);if(!GetMonitorInfo(MonitorFromWindow(handle,2),ref info))return;double dpi=96;try{dpi=GetDpiForWindow(handle);}catch(EntryPointNotFoundException){}double scale=Math.Max(1,dpi/96.0);window.Left=Center(info.Monitor.Left,info.Monitor.Right-info.Monitor.Left,window.Width,scale);window.Top=info.Monitor.Top/scale;}
 public static void Attach(Window window,OrbyLiquidSurface surface){var src=HwndSource.FromHwnd(new WindowInteropHelper(window).Handle);src.AddHook(delegate(IntPtr hwnd,int msg,IntPtr wp,IntPtr lp,ref bool handled){if(msg==0x02E0||msg==0x007E){window.Dispatcher.BeginInvoke(DispatcherPriority.Loaded,new Action(delegate{surface.Attach(window);Position(window);window.InvalidateMeasure();window.InvalidateVisual();}));}return IntPtr.Zero;});}
}
