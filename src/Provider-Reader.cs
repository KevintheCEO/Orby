using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using System.Windows.Automation;
public sealed class OrbyProviderSnapshot {
 public string Provider,State="offline",Detail="Open the app to connect",Title="",Source="chat",Diagnostic="";
 public OrbyProviderUsage Usage;public bool UsagePage;
 public bool Connected,AppOpen,StatusReadable;public long Hwnd;public DateTime At=DateTime.UtcNow;
}
// Only explicit values on an allowlisted account-usage page are accepted.
// Chat messages, token/context percentages and API quota are not account limits.
public sealed class OrbyProviderUsage {
 public string Provider,SessionReset="",WeekReset="";public double? SessionRemaining,WeekRemaining;public DateTime At=DateTime.UtcNow;
 public static bool IsPage(string provider,string address){
  Uri uri;if(!Uri.TryCreate(address,UriKind.Absolute,out uri)&&!Uri.TryCreate("https://"+address,UriKind.Absolute,out uri))return false;
  if(uri.Scheme!="https"||!String.IsNullOrEmpty(uri.UserInfo)||!uri.IsDefaultPort)return false;
  string path=uri.AbsolutePath.TrimEnd('/');
  return provider=="claude"&&uri.Host=="claude.ai"&&path=="/settings/usage" || provider=="gemini"&&uri.Host=="gemini.google.com"&&(path=="/usage"||Regex.IsMatch(path,@"^/u/\d+/usage$"));
 }
 static string Window(string text,string pattern){
  var start=Regex.Match(text,pattern,RegexOptions.IgnoreCase);if(!start.Success)return "";
  string tail=text.Substring(start.Index+start.Length);
  var end=Regex.Match(tail,@"(?:current session|five[- ]hour|5[- ]hour|weekly(?: usage| limits)?|all models|sonnet only|opus only|extra usage|usage credits|context window|token usage|api usage)",RegexOptions.IgnoreCase);
  return (end.Success?tail.Substring(0,end.Index):tail).Substring(0,Math.Min(400,end.Success?end.Index:tail.Length));
 }
 static double? Remaining(string text){
  var matches=Regex.Matches(text,@"(?<![\d.,-])(\d{1,3}(?:\.\d+)?)\s*%\s*(used|remaining|left|available)\b",RegexOptions.IgnoreCase);
  double? result=null;foreach(Match match in matches){double number;if(!double.TryParse(match.Groups[1].Value,System.Globalization.NumberStyles.Float,System.Globalization.CultureInfo.InvariantCulture,out number)||number>100)return null;double remaining=match.Groups[2].Value.ToLowerInvariant()=="used"?100-number:number;if(result.HasValue&&Math.Abs(result.Value-remaining)>.01)return null;result=remaining;}return result;
 }
 static string Reset(string text){var match=Regex.Match(text,@"(?:resets?|refreshes?)(?: in| on| at)?\s+([^\r\n]{1,75})",RegexOptions.IgnoreCase);return match.Success?match.Value.Trim():"";}
 public static OrbyProviderUsage Parse(string provider,string address,string text){
  if(!IsPage(provider,address)||String.IsNullOrEmpty(text)||text.Length>100000)return null;
  if(Regex.IsMatch(text,@"(?im)^\s*(sign in|log in|sign in to continue)\s*$"))return null;
  var session=Window(text,@"(?:current session|five[- ]hour(?: usage| limit)?|5[- ]hour(?: usage| limit)?)");
  // Claude weekly pages separate an All models allowance from per-model rows.
  var week=Window(text,provider=="claude"&&Regex.IsMatch(text,@"all models",RegexOptions.IgnoreCase)?@"all models":@"weekly(?: usage| limits?)?");
  var result=new OrbyProviderUsage{Provider=provider,SessionRemaining=Remaining(session),WeekRemaining=Remaining(week),SessionReset=Reset(session),WeekReset=Reset(week)};
  return result.SessionRemaining.HasValue||result.WeekRemaining.HasValue?result:null;
 }
}
public static class OrbyProviderReader {
 public static string ProviderFor(string process,string address){
  string p=(process??"").ToLowerInvariant();if(p=="claude"||p.StartsWith("claude-"))return "claude";if(p=="gemini"||p=="googlegemini")return "gemini";if(p=="chatgpt")return "chatgpt";
  Uri u;if(!Uri.TryCreate(address,UriKind.Absolute,out u)&&!Uri.TryCreate("https://"+address,UriKind.Absolute,out u))return "";
  if(u.Scheme!="https")return "";string h=u.Host.ToLowerInvariant();return h=="claude.ai"?"claude":h=="gemini.google.com"?"gemini":h=="chatgpt.com"?"chatgpt":"";
 }
 public static string Normalize(string label){
  return Regex.Replace(Regex.Replace((label??"").Trim().ToLowerInvariant(),@"\s*\((?:ctrl|cmd|command|alt|shift|esc|escape)[^)]*\)\s*$",""),@"\s+"," ").Trim();
 }
 public static bool IsStop(string label){return new[]{"stop response","stop generating","stop generation","stop streaming","stop","stop response generation","stop generating response"}.Contains(Normalize(label));}
 public static bool IsSend(string label){return new[]{"send","send message","submit","send prompt","send to claude","send message to claude"}.Contains(Normalize(label));}
 public static bool IsPrompt(string name,string id){
  string n=Normalize(name),a=(id??"").ToLowerInvariant();
  return n.StartsWith("message claude")||n.StartsWith("reply to claude")||n.StartsWith("ask claude")||n.StartsWith("ask gemini")||n=="chat input"||a=="chat-input"||a=="prompt-textarea"||a=="chatinput";
 }
 public static string Classify(bool composer,IEnumerable<string> labels){
  var list=labels.Select(Normalize).ToArray();
  if(!composer||list.Any(x=>new[]{"sign in","log in","sign in to claude","sign in to gemini","sign in with google","continue with google","continue with apple"}.Contains(x)))return "unknown";
  if(list.Any(IsStop))return "working";
  // Words in ordinary chat are not reliable permission events.
  return "idle";
 }
 delegate bool EnumWindowProc(IntPtr hwnd,IntPtr param);
 [DllImport("user32.dll")]static extern bool EnumWindows(EnumWindowProc callback,IntPtr param);
 [DllImport("user32.dll")]static extern bool IsWindowVisible(IntPtr hwnd);
 [DllImport("user32.dll")]static extern uint GetWindowThreadProcessId(IntPtr hwnd,out uint pid);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)]static extern int GetWindowText(IntPtr hwnd,StringBuilder text,int count);
 public static OrbyProviderSnapshot[] Read(){return Read("chatgpt,claude,gemini");}
 public static OrbyProviderSnapshot[] Read(string enabled){
  var allowed=new HashSet<string>((enabled??"").Split(','));var processes=new Dictionary<int,string>();
  foreach(var p in Process.GetProcesses()){try{processes[p.Id]=p.ProcessName.ToLowerInvariant();}catch{}finally{p.Dispose();}}
  var windows=new List<KeyValuePair<IntPtr,string>>();
  EnumWindows(delegate(IntPtr hwnd,IntPtr unused){
   uint pid;GetWindowThreadProcessId(hwnd,out pid);string proc;
   if(!IsWindowVisible(hwnd)||!processes.TryGetValue((int)pid,out proc))return true;
   string provider=ProviderFor(proc,"");bool browser=new[]{"chrome","msedge","firefox","brave","opera","vivaldi"}.Contains(proc);
   if(browser||(provider!=""&&allowed.Contains(provider)))windows.Add(new KeyValuePair<IntPtr,string>(hwnd,proc));
   return true;
  },IntPtr.Zero);
  var result=new List<OrbyProviderSnapshot>();
  // Electron may own a chat window in a process other than MainWindowHandle.
  foreach(var w in windows.OrderBy(x=>ProviderFor(x.Value,"")=="claude"?0:1)){var snap=ReadWindow(w.Key,w.Value,allowed);if(snap!=null)result.Add(snap);}
  return result.ToArray();
 }
 static OrbyProviderUsage ReadUsagePage(AutomationElement root,string provider,string address){
  try{
   var cache=new CacheRequest();cache.TreeScope=TreeScope.Element;cache.Add(AutomationElement.NameProperty);cache.Add(AutomationElement.BoundingRectangleProperty);cache.Add(AutomationElement.IsOffscreenProperty);
   var text=new List<Tuple<double,double,string>>();
   using(cache.Activate()){
    var nodes=root.FindAll(TreeScope.Descendants,new PropertyCondition(AutomationElement.ControlTypeProperty,ControlType.Text));
    if(nodes.Count>500)return null;
    foreach(AutomationElement node in nodes){var c=node.Cached;if(!c.IsOffscreen&&!String.IsNullOrEmpty(c.Name)&&c.Name.Length<2000)text.Add(Tuple.Create(c.BoundingRectangle.Top,c.BoundingRectangle.Left,c.Name));}
   }
   return OrbyProviderUsage.Parse(provider,address,String.Join("\n",text.OrderBy(x=>x.Item1).ThenBy(x=>x.Item2).Select(x=>x.Item3)));
  }catch{return null;}
 }
 static OrbyProviderSnapshot ReadWindow(IntPtr hwnd,string proc,HashSet<string> allowed){
  string provider=ProviderFor(proc,"");bool browser=provider=="";var title=new StringBuilder(512);GetWindowText(hwnd,title,title.Capacity);
  var snap=new OrbyProviderSnapshot{Provider=provider,AppOpen=true,Hwnd=hwnd.ToInt64(),Title=title.ToString()};
  try{
   var root=AutomationElement.FromHandle(hwnd);var labels=new List<string>();bool editor=false,prompt=false,send=false;string address="";
   if(browser){
    var addressCache=new CacheRequest();addressCache.TreeScope=TreeScope.Element;addressCache.Add(AutomationElement.NameProperty);addressCache.Add(AutomationElement.AutomationIdProperty);
    using(addressCache.Activate()){
     var edits=root.FindAll(TreeScope.Descendants,new PropertyCondition(AutomationElement.ControlTypeProperty,ControlType.Edit));
     foreach(AutomationElement edit in edits){var info=edit.Cached;if(info.Name.IndexOf("address",StringComparison.OrdinalIgnoreCase)>=0||info.AutomationId=="addressEditBox"){
      object pattern;if(edit.TryGetCurrentPattern(ValuePattern.Pattern,out pattern))address=((ValuePattern)pattern).Current.Value;break;
     }}
    }
    string accountProvider=ProviderFor(proc,address);
    if(allowed.Contains(accountProvider)&&OrbyProviderUsage.IsPage(accountProvider,address)){
     snap.Provider=accountProvider;snap.UsagePage=true;snap.Source="usage";snap.AppOpen=false;snap.Usage=ReadUsagePage(root,accountProvider,address);snap.Connected=snap.Usage!=null;snap.State="unknown";snap.Detail="Account usage page open";snap.Diagnostic=snap.Usage!=null?"usage-readable":"usage-unavailable";return snap;
    }
   }
   var queue=new Queue<AutomationElement>();queue.Enqueue(root);var watch=Stopwatch.StartNew();int count=0;
   // Raw view includes contenteditable controls omitted by the control view.
   var walker=TreeWalker.RawViewWalker;
   while(queue.Count>0&&count++<900&&watch.ElapsedMilliseconds<700){
    var node=queue.Dequeue();try{
     var c=node.Current;if(!c.IsOffscreen){
      string name=c.Name??"";
      if(c.ControlType==ControlType.Button){labels.Add(name);send|=IsSend(name);}
      bool semanticPrompt=IsPrompt(name,c.AutomationId);
      if(c.ControlType==ControlType.Edit||semanticPrompt){
       bool url=browser&&(name.IndexOf("address",StringComparison.OrdinalIgnoreCase)>=0||c.AutomationId=="addressEditBox");
       if(url){object pattern;if(node.TryGetCurrentPattern(ValuePattern.Pattern,out pattern))address=((ValuePattern)pattern).Current.Value;}
       else if(c.IsEnabled&&!c.IsPassword&&name.IndexOf("search",StringComparison.OrdinalIgnoreCase)<0&&name.IndexOf("email",StringComparison.OrdinalIgnoreCase)<0){editor=true;prompt|=semanticPrompt;}
      }
     }
     var child=walker.GetFirstChild(node);int children=0;
     while(child!=null&&children++<100){queue.Enqueue(child);child=walker.GetNextSibling(child);}
    }catch(ElementNotAvailableException){}catch(InvalidOperationException){}
   }
   if(browser){provider=ProviderFor(proc,address);snap.Provider=provider;if(provider==""||!allowed.Contains(provider))return null;}
   if(browser && OrbyProviderUsage.IsPage(provider,address)){
    snap.UsagePage=true;snap.Source="usage";snap.AppOpen=false;
    snap.Usage=ReadUsagePage(root,provider,address);
   }
   snap.State=Classify(prompt||(editor&&send)||labels.Any(IsStop),labels);snap.StatusReadable=snap.State!="unknown";snap.Connected=snap.StatusReadable;
   snap.Detail=snap.State=="working"?(provider=="claude"?"Claude chat · generating a response":"Generating a response"):snap.State=="idle"?"Ready for your next chat":"App open · waiting for activity";
   snap.Diagnostic=snap.StatusReadable?"controls-readable":watch.ElapsedMilliseconds>=700?"scan-budget":"no-chat-controls";
  }catch(Exception){if(browser)return null;snap.State="unknown";snap.Detail="App open · waiting for activity";snap.Diagnostic="accessibility-unavailable";}
  snap.At=DateTime.UtcNow;return snap;
 }
 [DllImport("user32.dll")]static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")]static extern bool ShowWindowAsync(IntPtr h,int command);
 public static void Focus(long hwnd){var h=new IntPtr(hwnd);ShowWindowAsync(h,9);SetForegroundWindow(h);}
}
