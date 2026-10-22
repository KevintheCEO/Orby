using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Web.Script.Serialization;

public sealed class OrbyCodeSignal {
 public int Version=1, OwnerPid;
 public string Session, Event, State;
 public long OwnerStart, AtTicks;
}
public sealed class OrbyCodeStatus {
 public bool Open, Readable;
 public int Sessions;
 public OrbyCodeTask[] Tasks=new OrbyCodeTask[0];
 public string State="unknown", Detail="Claude Code sync enabled · start a session";
}
public sealed class OrbyCodeTask {
 public string Id, State, Title, Action;
}
public static class OrbyClaudeCode {
 public static string DefaultDirectory {get{string root=Environment.GetEnvironmentVariable("CLAUDE_CONFIG_DIR");if(String.IsNullOrEmpty(root))root=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),".claude");return Path.Combine(root,"orby-bridge","state");}}
 static readonly string[] States={"idle","working","attention","error","closed"};
 static JavaScriptSerializer Serializer(){return new JavaScriptSerializer{MaxJsonLength=1024*1024,RecursionLimit=40};}
 public static string EventState(string name,string notification) {
  switch(name) {
   case "SessionStart": case "Stop": return "idle";
   case "UserPromptSubmit": case "PreToolUse": case "PostToolUse": case "PostToolUseFailure": case "ElicitationResult": return "working";
   case "PermissionRequest": case "Elicitation": return "attention";
   case "StopFailure": return "error";
   case "SessionEnd": return "closed";
   case "Notification":return notification=="permission_prompt"?"attention":notification=="idle_prompt"?"idle":null;
   default:return null;
  }
 }
 static string Field(Dictionary<string,object> data,string key){object v;return data.TryGetValue(key,out v)?Convert.ToString(v,CultureInfo.InvariantCulture):"";}
 static string Hash(string id){using(var sha=SHA256.Create())return BitConverter.ToString(sha.ComputeHash(Encoding.UTF8.GetBytes(id))).Replace("-","").ToLowerInvariant();}
 // Persist only an opaque session hash and lifecycle metadata. Never log the input JSON.
 public static bool Observe(string input,string directory,int ownerPid,long ownerStart,DateTime now) {
  var data=Serializer().Deserialize<Dictionary<string,object>>(input);
  string id=Field(data,"session_id"),ev=Field(data,"hook_event_name");
  if(id.Length==0||id.Length>512||Field(data,"agent_id").Length>0)return false;
  string state=EventState(ev,Field(data,"notification_type"));if(state==null)return false;
  string hash=Hash(id);Directory.CreateDirectory(directory);
  using(var mutex=new Mutex(false,"Local\\OrbyClaudeCode-"+hash)) {
   bool held=false;
   try {
    try{held=mutex.WaitOne(500);}catch(AbandonedMutexException){held=true;}
    if(!held)return false;
    string path=Path.Combine(directory,hash+".json");
    OrbyCodeSignal previous=null;
    try{previous=Serializer().Deserialize<OrbyCodeSignal>(File.ReadAllText(path));}catch{}
    if(previous!=null&&previous.AtTicks>now.Ticks)return false;
    // Unknown ancestry must not inherit the identity of an old resumed process.
    var signal=new OrbyCodeSignal{Session=hash,Event=ev,State=state,AtTicks=now.Ticks,OwnerPid=ownerPid,OwnerStart=ownerStart};
    string temp=path+"."+Guid.NewGuid().ToString("N")+".tmp";
    try {
     File.WriteAllText(temp,Serializer().Serialize(signal),new UTF8Encoding(false));
     if(File.Exists(path))File.Replace(temp,path,null);else File.Move(temp,path);
    }finally{if(File.Exists(temp))File.Delete(temp);}
    return true;
   }finally{if(held)mutex.ReleaseMutex();}
  }
 }
 public static bool IsOwnerAlive(int pid,long start) {
  if(pid<=0||start<=0)return false;
  try{using(var p=Process.GetProcessById(pid))return !p.HasExited&&p.StartTime.ToUniversalTime().Ticks==start;}catch{return false;}
 }
 public static OrbyCodeStatus Read(string directory) {
  var signals=new List<OrbyCodeSignal>();
  if(!Directory.Exists(directory)||!File.Exists(Path.Combine(Path.GetDirectoryName(directory),"enabled")))return new OrbyCodeStatus();
  foreach(string file in Directory.EnumerateFiles(directory,"*.json")) {
   try{if(new FileInfo(file).Length>4096)continue;signals.Add(Serializer().Deserialize<OrbyCodeSignal>(File.ReadAllText(file)));}catch{}
  }
  return Aggregate(signals,DateTime.UtcNow,IsOwnerAlive);
 }
 public static OrbyCodeStatus Aggregate(IEnumerable<OrbyCodeSignal> signals,DateTime now,Func<int,long,bool> alive) {
  var active=new List<OrbyCodeSignal>();bool unknown=false;
  foreach(var s in signals) {
   if(s==null||s.Version!=1||!States.Contains(s.State)||s.AtTicks>now.AddSeconds(5).Ticks||s.State=="closed")continue;
   if(s.OwnerPid>0&&s.OwnerStart>0){if(alive(s.OwnerPid,s.OwnerStart))active.Add(s);}
   // An unidentifiable process cannot sustain a guessed LIVE state indefinitely.
   else if(now.Ticks-s.AtTicks<TimeSpan.FromSeconds(30).Ticks)unknown=true;
  }
  if(active.Count==0)return new OrbyCodeStatus{Open=unknown,Detail=unknown?"Claude Code · process status unavailable":"Claude Code sync enabled · start a session"};
  string state=active.Any(s=>s.State=="attention")?"attention":active.Any(s=>s.State=="working")?"working":active.Any(s=>s.State=="error")?"error":"idle";
  return new OrbyCodeStatus{Open=true,Readable=true,Sessions=active.Count,State=state,
   Tasks=active.GroupBy(s=>s.Session).Select(g=>g.OrderByDescending(s=>s.AtTicks).First()).Where(s=>s.State=="working"||s.State=="attention").Select(s=>new OrbyCodeTask{Id="claude-code-"+s.Session,State=s.State,Title="Claude Code task",Action=s.State=="attention"?"Needs your input":"Working"}).ToArray(),
   Detail="Claude Code · "+(state=="attention"?"waiting for your input":state=="working"?"working":state=="error"?"turn ended with an error":"ready")+(active.Count>1?" · "+active.Count+" sessions":"")};
 }
 [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)]struct ProcessEntry {
  public uint Size,Usage,Pid;public IntPtr Heap;public uint Module,Threads,Parent;public int Priority;public uint Flags;
  [MarshalAs(UnmanagedType.ByValTStr,SizeConst=260)]public string Name;
 }
 [DllImport("kernel32.dll")]static extern IntPtr CreateToolhelp32Snapshot(uint flags,uint pid);
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,EntryPoint="Process32FirstW")]static extern bool Process32First(IntPtr h,ref ProcessEntry entry);
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,EntryPoint="Process32NextW")]static extern bool Process32Next(IntPtr h,ref ProcessEntry entry);
 [DllImport("kernel32.dll")]static extern bool CloseHandle(IntPtr h);
 public static int FindOwner() {
  var entries=new Dictionary<int,ProcessEntry>();IntPtr h=CreateToolhelp32Snapshot(2,0);
  if(h==new IntPtr(-1))return 0;
  try {var e=new ProcessEntry{Size=(uint)Marshal.SizeOf(typeof(ProcessEntry))};
   if(Process32First(h,ref e)){do{entries[(int)e.Pid]=e;}while(Process32Next(h,ref e));}
  }finally{CloseHandle(h);}
  int current=Process.GetCurrentProcess().Id;
  for(int i=0;i<16;i++) {
   ProcessEntry e;if(!entries.TryGetValue(current,out e))break;current=(int)e.Parent;
   ProcessEntry parent;if(!entries.TryGetValue(current,out parent))break;
   string name=(parent.Name??"").ToLowerInvariant();
   if(name=="claude.exe"||name.StartsWith("claude-")||name=="node.exe")return current;
  }
  return 0;
 }
 // This observer always exits zero and emits no permission decision or context.
 public static void Main(string[] args) {
  try {
   if(!File.Exists(Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"enabled")))return;
   string directory=Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"state");int owner=FindOwner();long start=0;
   if(owner>0){try{using(var p=Process.GetProcessById(owner))start=p.StartTime.ToUniversalTime().Ticks;}catch{owner=0;}}
   string input=Console.In.ReadToEnd();Observe(input,directory,owner,start,DateTime.UtcNow);
  }catch{}
 }
}
