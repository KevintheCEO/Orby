using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Automation;
public sealed class OrbyApprovalRequest {
 public string Id="",Title="",Detail="",Status="No accessible permission request";
 public bool Available; internal AutomationElement Allow,Deny;
}
public sealed class OrbyApprovalReply {public bool Submitted,Resolved;public string Message;}
public static class OrbyApprovalWorker {
 static string Name(AutomationElement e){try{return (e.Current.Name??"").Trim();}catch{return "";}}
 static bool Visible(AutomationElement e){try{return !e.Current.IsOffscreen && e.Current.IsEnabled;}catch{return false;}}
 static bool AllowLabel(string s){return Regex.IsMatch(s,@"^Allow once(?:\s+(?:Enter|Return|↵|⏎))?$",RegexOptions.IgnoreCase);}
 static bool DenyLabel(string s){return Regex.IsMatch(s,@"^Deny(?:\s+(?:Esc|Escape))?$",RegexOptions.IgnoreCase);}
 static bool Button(AutomationElement e){try{return e.Current.ControlType==ControlType.Button;}catch{return false;}}
 static bool Invokable(AutomationElement e){object p;return Visible(e)&&e.TryGetCurrentPattern(InvokePattern.Pattern,out p);}
 static List<AutomationElement> Nodes(AutomationElement root,int cap){
  var list=new List<AutomationElement>();var queue=new Queue<AutomationElement>();queue.Enqueue(root);
  while(queue.Count>0 && list.Count<cap){var node=queue.Dequeue();list.Add(node);try{var child=TreeWalker.ControlViewWalker.GetFirstChild(node);while(child!=null && queue.Count+list.Count<cap){queue.Enqueue(child);child=TreeWalker.ControlViewWalker.GetNextSibling(child);}}catch{}}
  if(queue.Count>0)throw new InvalidOperationException("Accessibility tree exceeded the safe scan bound");return list;
 }
 static string Identity(AutomationElement panel,string title,string detail){
  string key=panel.Current.ProcessId+"|"+string.Join(",",panel.GetRuntimeId())+"|"+title+"|"+detail;
  using(var hash=SHA256.Create()){return Convert.ToBase64String(hash.ComputeHash(Encoding.UTF8.GetBytes(key)));}
 }
 // Reads one visible card, including its actual request text, rather than inferring consent from logs.
 public static OrbyApprovalRequest InspectRoot(AutomationElement root){
  var candidates=new List<OrbyApprovalRequest>();var seen=new HashSet<string>();
  foreach(var element in Nodes(root,5000)){
   if(!Button(element)||!Visible(element)||!AllowLabel(Name(element)))continue;
   var panel=element;
   for(int depth=0;depth<7;depth++){
    panel=TreeWalker.ControlViewWalker.GetParent(panel);if(panel==null||panel==root)break;
    var nodes=Nodes(panel,500);AutomationElement deny=null,allow=null;var text=new List<string>();string title="";int allowCount=0,denyCount=0;
    foreach(var node in nodes){if(!Visible(node))continue;string name=Name(node);
     if(Button(node)){if(AllowLabel(name)){allow=node;allowCount++;}if(DenyLabel(name)){deny=node;denyCount++;}continue;}
     if(name.Length>0 && name.Length<3000 && !text.Contains(name))text.Add(name);
     if(Regex.IsMatch(name,@"^Allow\s+(?:ChatGPT|Codex)\b",RegexOptions.IgnoreCase)&&title.Length==0)title=name;
    }
    if(allow==null||deny==null||title.Length==0||allowCount!=1||denyCount!=1)continue;
    if(!Invokable(allow)||!Invokable(deny))break;
    text.Remove(title);text.RemoveAll(x=>x=="Permissions"||x=="Permission");
    // Container names can duplicate all child text; keep the request-specific leaf text.
    text.RemoveAll(x=>x.Contains(title));string detail=string.Join("\n",text.ToArray());
    var request=new OrbyApprovalRequest{Available=true,Title=title,Detail=detail,Allow=allow,Deny=deny};request.Id=Identity(panel,title,detail);
    if(seen.Add(request.Id))candidates.Add(request);break;
   }
  }
  if(candidates.Count==1)return candidates[0];
  return new OrbyApprovalRequest{Status=candidates.Count>1?"Several requests are visible. Select the chat to approve.":"Permission controls are not exposed by this window"};
 }
 static OrbyApprovalRequest Find(){
  var found=new List<OrbyApprovalRequest>();
  try{var windows=AutomationElement.RootElement.FindAll(TreeScope.Children,Condition.TrueCondition);
   foreach(AutomationElement window in windows){if(!Visible(window))continue;string process="";try{process=Process.GetProcessById(window.Current.ProcessId).ProcessName;}catch{continue;}
    if(!Regex.IsMatch(process,@"^(ChatGPT|Codex)$",RegexOptions.IgnoreCase))continue;
    var candidate=InspectRoot(window);if(candidate.Available)found.Add(candidate);else if(candidate.Status.StartsWith("Several"))return candidate;
   }
  }catch{return new OrbyApprovalRequest{Status="Permission controls could not be read"};}
  return found.Count==1?found[0]:new OrbyApprovalRequest{Status=found.Count>1?"Several requests are visible. Select the chat to approve.":"Waiting for accessible permission controls"};
 }
 public static Task<OrbyApprovalRequest> Poll(){return Task.Run(()=>Find());}
 public static OrbyApprovalReply RespondToRoot(AutomationElement root,string expectedId,bool allow){return Respond(()=>InspectRoot(root),expectedId,allow);}
 public static Task<OrbyApprovalReply> Respond(string expectedId,bool allow){return Task.Run(()=>Respond(()=>Find(),expectedId,allow));}
 static OrbyApprovalReply Respond(Func<OrbyApprovalRequest> discover,string expectedId,bool allow){
  try{var current=discover();if(!current.Available||current.Id!=expectedId)return new OrbyApprovalReply{Message="The request changed. Review the new permission."};
   var target=allow?current.Allow:current.Deny;object action;if(!Invokable(target)||!target.TryGetCurrentPattern(InvokePattern.Pattern,out action))return new OrbyApprovalReply{Message="The permission button is no longer accessible."};
   ((InvokePattern)action).Invoke();
   for(int i=0;i<8;i++){Thread.Sleep(150);var next=discover();if(!next.Available||next.Id!=expectedId)return new OrbyApprovalReply{Submitted=true,Resolved=true,Message=allow?"Allowed once":"Denied"};}
   return new OrbyApprovalReply{Submitted=true,Message="Response sent. Waiting for ChatGPT to confirm."};
  }catch{return new OrbyApprovalReply{Message="Could not submit the response. Review it in ChatGPT."};}
 }
}

