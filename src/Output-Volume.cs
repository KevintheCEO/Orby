using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
[ComImport,Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]class AudioEnumerator{}
[ComImport,Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]interface AudioDevices{[PreserveSig]int EnumAudioEndpoints(int flow,int mask,out AudioCollection devices);[PreserveSig]int GetDefaultAudioEndpoint(int flow,int role,out AudioDevice device);}
[ComImport,Guid("0BD7A1BE-7A1A-44DB-8397-CC5392387B5E"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]interface AudioCollection{[PreserveSig]int GetCount(out uint count);[PreserveSig]int Item(uint index,out AudioDevice device);}
[ComImport,Guid("D666063F-1587-4E43-81F1-B948E807363F"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]interface AudioDevice{[PreserveSig]int Activate(ref Guid id,int context,IntPtr parameters,[MarshalAs(UnmanagedType.IUnknown)]out object result);}
[ComImport,Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]interface SessionManager{[PreserveSig]int GetAudioSessionControl(ref Guid id,uint flags,out IntPtr control);[PreserveSig]int GetSimpleAudioVolume(ref Guid id,uint flags,out IntPtr volume);[PreserveSig]int GetSessionEnumerator(out SessionEnumerator sessions);}
[ComImport,Guid("E2F5BB11-0570-40CA-ACDD-3AA01277DEE8"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]interface SessionEnumerator{[PreserveSig]int GetCount(out int count);[PreserveSig]int GetSession(int index,out SessionControl session);}
[ComImport,Guid("BFB7FF88-7239-4FC9-8FA2-07C950BE9C6D"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]interface SessionControl{
[PreserveSig]int GetState(out int state);[PreserveSig]int GetDisplayName([MarshalAs(UnmanagedType.LPWStr)]out string name);[PreserveSig]int SetDisplayName([MarshalAs(UnmanagedType.LPWStr)]string name,ref Guid context);[PreserveSig]int GetIconPath([MarshalAs(UnmanagedType.LPWStr)]out string path);[PreserveSig]int SetIconPath([MarshalAs(UnmanagedType.LPWStr)]string path,ref Guid context);[PreserveSig]int GetGroupingParam(out Guid group);[PreserveSig]int SetGroupingParam(ref Guid group,ref Guid context);[PreserveSig]int RegisterAudioSessionNotification(IntPtr p);[PreserveSig]int UnregisterAudioSessionNotification(IntPtr p);[PreserveSig]int GetSessionIdentifier([MarshalAs(UnmanagedType.LPWStr)]out string id);[PreserveSig]int GetSessionInstanceIdentifier([MarshalAs(UnmanagedType.LPWStr)]out string id);[PreserveSig]int GetProcessId(out uint pid);[PreserveSig]int IsSystemSoundsSession();[PreserveSig]int SetDuckingPreference([MarshalAs(UnmanagedType.Bool)]bool optOut);
}
[ComImport,Guid("87CE5498-68D6-44E5-9215-6DA47EF883D8"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]interface SimpleVolume{[PreserveSig]int SetMasterVolume(float level,ref Guid context);[PreserveSig]int GetMasterVolume(out float level);[PreserveSig]int SetMute([MarshalAs(UnmanagedType.Bool)]bool mute,ref Guid context);[PreserveSig]int GetMute([MarshalAs(UnmanagedType.Bool)]out bool mute);}
// App-specific audio sessions only. Browser and unknown sources never fall back to master volume.
public static class OrbyOutputVolume{
public static bool IsSpotify(string name){return string.Equals(name,"Spotify",StringComparison.OrdinalIgnoreCase);}
static void Release(object o){if(o!=null && Marshal.IsComObject(o))Marshal.ReleaseComObject(o);}
static double Visit(double? value,string target){object e=null;AudioCollection devices=null;int matches=0;double result=0;
try{e=new AudioEnumerator();Marshal.ThrowExceptionForHR(((AudioDevices)e).EnumAudioEndpoints(0,1,out devices));uint count;Marshal.ThrowExceptionForHR(devices.GetCount(out count));
for(uint d=0;d<count;d++){AudioDevice device=null;object manager=null;SessionEnumerator sessions=null;try{Marshal.ThrowExceptionForHR(devices.Item(d,out device));Guid id=typeof(SessionManager).GUID;Marshal.ThrowExceptionForHR(device.Activate(ref id,23,IntPtr.Zero,out manager));Marshal.ThrowExceptionForHR(((SessionManager)manager).GetSessionEnumerator(out sessions));int n;Marshal.ThrowExceptionForHR(sessions.GetCount(out n));
for(int i=0;i<n;i++){SessionControl session=null;try{Marshal.ThrowExceptionForHR(sessions.GetSession(i,out session));uint pid;Marshal.ThrowExceptionForHR(session.GetProcessId(out pid));bool spotify=false;try{using(var process=Process.GetProcessById((int)pid))spotify=string.Equals(process.ProcessName,target,StringComparison.OrdinalIgnoreCase);}catch{}if(!spotify)continue;int state;Marshal.ThrowExceptionForHR(session.GetState(out state));if(state==2)continue;
var volume=(SimpleVolume)session;Guid context=Guid.Empty;if(value.HasValue)Marshal.ThrowExceptionForHR(volume.SetMasterVolume((float)(Math.Max(0,Math.Min(100,value.Value))/100),ref context));float level;Marshal.ThrowExceptionForHR(volume.GetMasterVolume(out level));result=level*100;matches++;
}finally{Release(session);}}
}finally{Release(sessions);Release(manager);Release(device);}}
if(matches==0)throw new InvalidOperationException("Open the selected desktop music app and play a track to enable its volume.");return result;
}finally{Release(devices);Release(e);}}
public static string ProcessForSource(string source){
 if(string.IsNullOrEmpty(source))return null;
 if(System.Text.RegularExpressions.Regex.IsMatch(source,@"(?i)chrome|msedge|brave|firefox|opera|https?[:/]|youtube|ytmusic"))return null;
 if(System.Text.RegularExpressions.Regex.IsMatch(source,@"(?i)^(Spotify(\.exe)?|SpotifyAB\.SpotifyMusic_[^!]+![^!]+)$"))return "Spotify";
 if(System.Text.RegularExpressions.Regex.IsMatch(source,@"(?i)^(AppleMusic(\.exe)?|AppleInc\.AppleMusic_[^!]+![^!]+)$"))return "AppleMusic";
 if(System.Text.RegularExpressions.Regex.IsMatch(source,@"(?i)^(AmazonMusic(\.exe)?|Amazon[^!]*\.AmazonMusic_[^!]+![^!]+)$"))return "AmazonMusic";
 return null;
}
public static double ForSource(string source,double? value){string target=ProcessForSource(source);if(target==null)throw new InvalidOperationException("Use the music app's own volume. This source has no isolated volume connection.");return Visit(value,target);}
public static double Get(){return Visit(null,"Spotify");}public static void Set(double value){Visit(value,"Spotify");}
}
// A single serialized background channel: no Core Audio enumeration on the UI thread.
public sealed class OrbyVolumeSnapshot {
 public readonly double Value;public readonly string Error;public readonly long Revision;public readonly DateTime At;
 public OrbyVolumeSnapshot(double value,string error,long revision){Value=value;Error=error;Revision=revision;At=DateTime.UtcNow;}
}
public sealed class OrbyVolumeChannel {
 readonly object gate=new object();readonly Func<double?,double> endpoint;
 bool running,readPending,writePending;double desired;long revision;
 OrbyVolumeSnapshot snapshot;
 public OrbyVolumeChannel(Func<double?,double> endpoint){this.endpoint=endpoint;}
 public OrbyVolumeSnapshot Snapshot{get{lock(gate)return snapshot;}}
 public bool Busy{get{lock(gate)return running;}}
 public void Refresh(){lock(gate){if(running)return;readPending=true;Start();}}
 public long Set(double value){lock(gate){desired=Math.Max(0,Math.Min(100,value));writePending=true;revision++;Start();return revision;}}
 void Start(){if(running)return;running=true;System.Threading.ThreadPool.QueueUserWorkItem(delegate{Run();});}
 void Run(){
  while(true){double? value;long token;
   lock(gate){if(writePending){value=desired;writePending=false;readPending=false;}else if(readPending){value=null;readPending=false;}else{running=false;return;}token=revision;}
   OrbyVolumeSnapshot next;try{next=new OrbyVolumeSnapshot(endpoint(value),null,token);}catch(Exception e){next=new OrbyVolumeSnapshot(0,e.GetBaseException().Message,token);}
   lock(gate){snapshot=next;}
  }
 }
}
public static class OrbyVolumeWorker {
 static readonly object gate=new object();
 static readonly System.Collections.Generic.Dictionary<string,OrbyVolumeChannel> channels=new System.Collections.Generic.Dictionary<string,OrbyVolumeChannel>(StringComparer.OrdinalIgnoreCase);
 public static OrbyVolumeChannel ForSource(string source){
  string target=OrbyOutputVolume.ProcessForSource(source);
  // Channel identity is immutable: pending writes cannot jump to a newly selected app.
  string key=target??"unsupported";
  lock(gate){OrbyVolumeChannel channel;if(!channels.TryGetValue(key,out channel)){string captured=source;channel=new OrbyVolumeChannel(delegate(double? value){return OrbyOutputVolume.ForSource(captured,value);});channels.Add(key,channel);}return channel;}
 }
 public static readonly OrbyVolumeChannel Channel=ForSource("Spotify");
}
