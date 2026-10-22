using System;
using System.Runtime.InteropServices;
public static class OrbyDpiBoot {
 [DllImport("user32.dll")] static extern bool SetProcessDpiAwarenessContext(IntPtr context);
 [DllImport("user32.dll")] static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
 public static void Enable(){AppContext.SetSwitch("Switch.System.Windows.DoNotScaleForDpiChanges",false);AppContext.SetSwitch("Switch.System.Windows.DoNotUsePresentationDpiCapabilityTier2OrGreater",false);try{SetProcessDpiAwarenessContext(new IntPtr(-4));SetThreadDpiAwarenessContext(new IntPtr(-4));}catch(EntryPointNotFoundException){}}
}
