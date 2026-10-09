using System;using System.Runtime.InteropServices;using System.Text;
public static class OrbyFullscreen {
 [StructLayout(LayoutKind.Sequential)]public struct Rect{public int Left,Top,Right,Bottom;}
 [StructLayout(LayoutKind.Sequential)]struct Info{public int Size;public Rect Monitor,Work;public uint Flags;}
 [DllImport("user32.dll")]static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")]static extern bool GetWindowRect(IntPtr hwnd,out Rect rect);
 [DllImport("user32.dll")]static extern bool IsIconic(IntPtr hwnd);
 [DllImport("user32.dll")]static extern IntPtr MonitorFromWindow(IntPtr hwnd,uint flags);
 [DllImport("user32.dll")]static extern bool GetMonitorInfo(IntPtr monitor,ref Info info);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)]static extern int GetClassName(IntPtr hwnd,StringBuilder name,int size);
 [DllImport("user32.dll")]static extern uint GetWindowThreadProcessId(IntPtr hwnd,out uint pid);
 public static bool Covers(Rect window,Rect monitor){return Math.Abs(window.Left-monitor.Left)<=2 && Math.Abs(window.Top-monitor.Top)<=2 && Math.Abs(window.Right-monitor.Right)<=2 && Math.Abs(window.Bottom-monitor.Bottom)<=2;}
 public static bool Active(){var h=GetForegroundWindow();if(h==IntPtr.Zero||IsIconic(h))return false;uint pid;GetWindowThreadProcessId(h,out pid);if(pid==(uint)System.Diagnostics.Process.GetCurrentProcess().Id)return false;var cls=new StringBuilder(128);GetClassName(h,cls,128);string c=cls.ToString();if(c=="Progman"||c=="WorkerW"||c=="Shell_TrayWnd"||c=="Shell_SecondaryTrayWnd")return false;Rect r;if(!GetWindowRect(h,out r))return false;var info=new Info();info.Size=Marshal.SizeOf(info);if(!GetMonitorInfo(MonitorFromWindow(h,2),ref info))return false;return Covers(r,info.Monitor);}
}
