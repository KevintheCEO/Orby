using System;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Automation;
// Resolve UIA on the MTA thread itself. Sharing an STA proxy with a background
// task can deadlock when the coordinator waits for an owned modal file picker.
public static class OrbyDropUIA {
 delegate bool EnumChild(IntPtr child,IntPtr context);
 [DllImport("user32.dll")]static extern bool EnumChildWindows(IntPtr parent,EnumChild callback,IntPtr context);
 [DllImport("user32.dll")]static extern int GetDlgCtrlID(IntPtr control);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)]static extern int GetClassName(IntPtr h,StringBuilder text,int count);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)]static extern IntPtr SendMessageTimeout(IntPtr h,uint msg,IntPtr w,string text,uint flags,uint timeout,out IntPtr result);
 [DllImport("user32.dll")]static extern bool PostMessage(IntPtr h,uint msg,IntPtr w,IntPtr l);
 public static IntPtr PickerControl(IntPtr dialog,int id){
  IntPtr found=IntPtr.Zero;
  EnumChildWindows(dialog,(h,p)=>{if(GetDlgCtrlID(h)==id){found=h;return false;}return true;},IntPtr.Zero);return found;
 }
 public static bool SetPickerFiles(IntPtr dialog,string files){
  var field=PickerControl(dialog,1148);var button=PickerControl(dialog,1);
  if(field==IntPtr.Zero || button==IntPtr.Zero)return false;
  var name=new StringBuilder(128);GetClassName(field,name,128);
  if(!name.ToString().StartsWith("ComboBox",StringComparison.OrdinalIgnoreCase) && !name.ToString().Equals("Edit",StringComparison.OrdinalIgnoreCase))return false;
  IntPtr result;
  return SendMessageTimeout(field,12,IntPtr.Zero,files,2,2000,out result)!=IntPtr.Zero;
 }
 public static void ClosePicker(IntPtr dialog){PostMessage(dialog,0x10,IntPtr.Zero,IntPtr.Zero);}
 public static bool AcceptPicker(IntPtr dialog){var button=PickerControl(dialog,1);return button!=IntPtr.Zero && PostMessage(button,0xF5,IntPtr.Zero,IntPtr.Zero);}
 [StructLayout(LayoutKind.Sequential)]struct Point {public int X,Y;}
 [StructLayout(LayoutKind.Sequential)]struct MouseInput {public int X,Y;public uint Data,Flags,Time;public IntPtr Extra;}
 [StructLayout(LayoutKind.Sequential)]struct Input {public uint Type;public MouseInput Mouse;}
 [DllImport("user32.dll")]static extern bool GetCursorPos(out Point point);
 [DllImport("user32.dll")]static extern bool SetCursorPos(int x,int y);
 [DllImport("user32.dll")]static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")]static extern IntPtr WindowFromPoint(Point point);
 [DllImport("user32.dll")]static extern IntPtr GetAncestor(IntPtr window,uint flags);
 [DllImport("user32.dll")]static extern IntPtr GetWindow(IntPtr window,uint command);
 static bool BelongsTo(IntPtr window,IntPtr root){for(int i=0;window!=IntPtr.Zero && i<16;i++,window=GetWindow(window,4)){if(window==root || GetAncestor(window,2)==root)return true;}return false;}
 [DllImport("user32.dll")]static extern uint SendInput(uint count,Input[] inputs,int size);
 // Chromium's upload command may require trusted mouse input to open its chooser.
 // Re-resolve the button, and reject occlusion or focus changes before clicking.
 public static Task ClickAsync(AutomationElement element,IntPtr rootHandle){
  return ActAsync(element,rootHandle,true);
 }
 public static Task InvokeAsync(AutomationElement element, IntPtr rootHandle) {
  return ActAsync(element,rootHandle,false);
 }
 static Task ActAsync(AutomationElement element,IntPtr rootHandle,bool click) {
  int[] id=element.GetRuntimeId();
  return Task.Run(() => {
   var root=AutomationElement.FromHandle(rootHandle);
   foreach(AutomationElement node in root.FindAll(TreeScope.Descendants,Condition.TrueCondition)) {
    if(node.GetRuntimeId().SequenceEqual(id)){
     if(click){
      if(GetForegroundWindow()!=rootHandle || node.Current.IsOffscreen || !node.Current.IsEnabled)throw new InvalidOperationException("The upload button lost focus.");
      var area=node.Current.BoundingRectangle;
      if(area.IsEmpty || area.Width<1 || area.Height<1)throw new InvalidOperationException("The upload button has no visible bounds.");
      var point=new Point{X=(int)(area.Left+area.Width/2),Y=(int)(area.Top+area.Height/2)};
      var at=WindowFromPoint(point);
      if(!BelongsTo(at,rootHandle))throw new InvalidOperationException("The upload button is covered by another window.");
      Point saved;GetCursorPos(out saved);
      try{
       if(!SetCursorPos(point.X,point.Y) || GetForegroundWindow()!=rootHandle)throw new InvalidOperationException("The upload button lost focus.");
       var inputs=new[]{new Input{Type=0,Mouse=new MouseInput{Flags=2}},new Input{Type=0,Mouse=new MouseInput{Flags=4}}};
       if(SendInput(2,inputs,Marshal.SizeOf(typeof(Input)))!=2)throw new InvalidOperationException("Windows did not accept the upload click.");
      }finally{SetCursorPos(saved.X,saved.Y);}
      return;
     }
     object action;
     if(node.TryGetCurrentPattern(InvokePattern.Pattern,out action)){((InvokePattern)action).Invoke();return;}
     if(node.TryGetCurrentPattern(ExpandCollapsePattern.Pattern,out action)){
      var expand=(ExpandCollapsePattern)action;
      if(expand.Current.ExpandCollapseState!=ExpandCollapseState.Expanded)expand.Expand();return;
     }
     throw new InvalidOperationException("Attachment control exposes no supported action.");
    }
   }
   throw new InvalidOperationException("Attachment control changed before it could be opened.");
  });
 }
}
