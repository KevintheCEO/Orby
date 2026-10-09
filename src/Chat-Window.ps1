Add-Type -TypeDefinition @"
using System;using System.Collections.Generic;using System.Runtime.InteropServices;
public static class OrbyChatWindow {
 public delegate bool Child(IntPtr h,IntPtr p);
 [DllImport("user32.dll")]public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")]public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")]public static extern bool IsIconic(IntPtr h);
 [DllImport("user32.dll")]public static extern bool ShowWindowAsync(IntPtr h,int n);
 [DllImport("user32.dll")]static extern bool EnumChildWindows(IntPtr h,Child callback,IntPtr p);
 public static IntPtr[] Children(IntPtr h){var list=new List<IntPtr>();EnumChildWindows(h,(child,p)=>{list.Add(child);return true;},IntPtr.Zero);return list.ToArray();}
 [DllImport("user32.dll")]static extern IntPtr GetWindow(IntPtr h,uint cmd);
 [DllImport("user32.dll")]static extern IntPtr GetAncestor(IntPtr h,uint flags);
 public static bool OwnedBy(IntPtr h,IntPtr app){for(int i=0;i<16 && h!=IntPtr.Zero;i++){h=GetWindow(h,4);if(h==app || GetAncestor(h,2)==app)return true;}return false;}
 public static bool Activate(IntPtr h){if(IsIconic(h))ShowWindowAsync(h,9);return SetForegroundWindow(h);}
}
"@
function Get-OrbyChatRoots {
 param($Root)
 $roots=New-Object Collections.Generic.List[object];$roots.Add($Root)
 foreach($handle in [OrbyChatWindow]::Children($script:chatHwnd)){
  try{$element=[Windows.Automation.AutomationElement]::FromHandle($handle);if($element){$roots.Add($element)}}catch{}
 }
 return $roots.ToArray()
}
