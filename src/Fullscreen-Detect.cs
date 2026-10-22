using System;
using System.Runtime.InteropServices;
using System.Text;
public static class OrbyFullscreen {
 [StructLayout(LayoutKind.Sequential)]public struct Rect{public int Left,Top,Right,Bottom;}
 [StructLayout(LayoutKind.Sequential)]struct Info{public int Size;public Rect Monitor,Work;public uint Flags;}
 [StructLayout(LayoutKind.Sequential)]struct Point{public int X,Y;}
 public sealed class Observation{public long Foreground;public bool Fullscreen,Transient;public string Geometry="";}
 [DllImport("user32.dll")]static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")]static extern bool GetWindowRect(IntPtr hwnd,out Rect rect);
 [DllImport("user32.dll")]static extern bool GetClientRect(IntPtr hwnd,out Rect rect);
 [DllImport("user32.dll")]static extern bool ClientToScreen(IntPtr hwnd,ref Point point);
 [DllImport("user32.dll")]static extern bool IsIconic(IntPtr hwnd);
 [DllImport("user32.dll")]static extern bool IsZoomed(IntPtr hwnd);
 [DllImport("user32.dll")]static extern IntPtr MonitorFromWindow(IntPtr hwnd,uint flags);
 [DllImport("user32.dll")]static extern bool GetMonitorInfo(IntPtr monitor,ref Info info);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)]static extern int GetClassName(IntPtr hwnd,StringBuilder name,int size);
 [DllImport("user32.dll")]static extern uint GetWindowThreadProcessId(IntPtr hwnd,out uint pid);
 [DllImport("user32.dll")]static extern bool SetWindowPos(IntPtr hwnd,IntPtr after,int x,int y,int cx,int cy,uint flags);
 public static long Foreground(){return GetForegroundWindow().ToInt64();}
 public static void RaiseWithoutActivation(IntPtr hwnd){if(hwnd!=IntPtr.Zero)SetWindowPos(hwnd,new IntPtr(-1),0,0,0,0,0x0013);}
 public static bool Covers(Rect window,Rect monitor){return Math.Abs(window.Left-monitor.Left)<=2 && Math.Abs(window.Top-monitor.Top)<=2 && Math.Abs(window.Right-monitor.Right)<=2 && Math.Abs(window.Bottom-monitor.Bottom)<=2;}
 public static bool IsFullscreen(Rect outer,Rect client,Rect monitor){return Covers(outer,monitor) && Covers(client,monitor);}
 public static bool ShouldHide(Rect outer,Rect client,Rect monitor,bool sameMonitor,bool maximized,bool transient){return sameMonitor && !maximized && !transient && IsFullscreen(outer,client,monitor);}
 public static bool IsTransient(string process,string cls){return String.Equals(process,"SnippingTool",StringComparison.OrdinalIgnoreCase)||String.Equals(process,"ScreenClippingHost",StringComparison.OrdinalIgnoreCase)||String.Equals(process,"GameBar",StringComparison.OrdinalIgnoreCase)||cls=="Shell_TrayWnd"||cls=="Shell_SecondaryTrayWnd";}
 public static Observation Observe(IntPtr target){
  var result=new Observation();var h=GetForegroundWindow();result.Foreground=h.ToInt64();
  if(h==IntPtr.Zero||IsIconic(h))return result;
  uint pid;GetWindowThreadProcessId(h,out pid);if(pid==(uint)System.Diagnostics.Process.GetCurrentProcess().Id)return result;
  var cls=new StringBuilder(128);GetClassName(h,cls,128);string c=cls.ToString();
  if(c=="Progman"||c=="WorkerW")return result;
  string process="";try{using(var p=System.Diagnostics.Process.GetProcessById((int)pid)){process=p.ProcessName;}}catch{}
  result.Transient=IsTransient(process,c);if(result.Transient)return result;
  var monitor=MonitorFromWindow(h,2);if(target!=IntPtr.Zero && MonitorFromWindow(target,2)!=monitor)return result;
  Rect r;if(!GetWindowRect(h,out r))return result;var info=new Info();info.Size=Marshal.SizeOf(info);if(!GetMonitorInfo(monitor,ref info))return result;
  Rect client;if(!GetClientRect(h,out client))return result;var origin=new Point();if(!ClientToScreen(h,ref origin))return result;
  client.Right+=origin.X;client.Bottom+=origin.Y;client.Left=origin.X;client.Top=origin.Y;
  result.Geometry=r.Left+","+r.Top+","+r.Right+","+r.Bottom+":"+client.Left+","+client.Top+","+client.Right+","+client.Bottom;
  result.Fullscreen=ShouldHide(r,client,info.Monitor,true,IsZoomed(h),false);return result;
 }
 public static bool Active(){return Observe(IntPtr.Zero).Fullscreen;}
}
