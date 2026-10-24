using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;
using System.Runtime.InteropServices;
using System.Windows.Automation;
public sealed class OrbyApprovalRequest {
 public string Id="",Title="",Detail="",Status="No accessible permission request";
 public string Kind="permission",Target="";public string[] Choices=new string[0];
 public bool Available,CanAnswer,CanReply; internal AutomationElement Allow,Deny,Send,ReplyInput;internal AutomationElement[] ChoiceControls=new AutomationElement[0];
}
public sealed class OrbyApprovalReply {public bool Submitted,Resolved;public string Message;}
public static class OrbyApprovalWorker {
 delegate bool ChildVisitor(IntPtr hwnd,IntPtr parameter);
 [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr parent,ChildVisitor visitor,IntPtr parameter);
 static IEnumerable<AutomationElement> WindowRoots(AutomationElement window){
  var roots=new List<AutomationElement>{window};int count=0;bool exceeded=false;
  IntPtr handle=new IntPtr(window.Current.NativeWindowHandle);
  if(handle!=IntPtr.Zero){
   ChildVisitor visitor=(child,unused)=>{if(++count>120){exceeded=true;return false;}try{var root=AutomationElement.FromHandle(child);if(root!=null&&Present(root))roots.Add(root);}catch{}return true;};
   EnumChildWindows(handle,visitor,IntPtr.Zero);GC.KeepAlive(visitor);
  }
  if(exceeded)throw new InvalidOperationException("Child window scan exceeded the safe bound");return roots;
 }
 public static OrbyApprovalRequest InspectRoots(IEnumerable<AutomationElement> roots){
  var matches=new List<OrbyApprovalRequest>();var seen=new HashSet<string>();
  foreach(var root in roots){var q=InspectRoot(root);if(q.Status.StartsWith("Several"))return q;if(q.Available&&seen.Add(q.Id))matches.Add(q);}
  return matches.Count==1?matches[0]:new OrbyApprovalRequest{Status=matches.Count>1?"Several requests are visible. Select the chat to approve.":"Permission controls are not exposed by this window"};
 }
 static string Name(AutomationElement e){try{return (e.Current.Name??"").Trim();}catch{return "";}}
 static bool Visible(AutomationElement e){try{return !e.Current.IsOffscreen && e.Current.IsEnabled;}catch{return false;}}
 static bool Present(AutomationElement e){try{return !e.Current.IsOffscreen && !e.Current.BoundingRectangle.IsEmpty;}catch{return false;}}
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
    var request=new OrbyApprovalRequest{Available=true,CanAnswer=true,Title=title,Detail=detail,Allow=allow,Deny=deny};request.Id=Identity(panel,title,detail);
    if(seen.Add(request.Id))candidates.Add(request);break;
   }
  }
  foreach(var question in InspectQuestions(root)){if(seen.Add(question.Id))candidates.Add(question);}
  if(candidates.Count==1)return candidates[0];
  return new OrbyApprovalRequest{Status=candidates.Count>1?"Several requests are visible. Select the chat to approve.":"Permission controls are not exposed by this window"};
 }
 static string ChoiceName(string name){return Regex.Replace(name,@"^\s*\d{1,2}[\s\.\):]+","").Trim();}
 static bool Selectable(AutomationElement e){object p;return Visible(e)&&(e.TryGetCurrentPattern(SelectionItemPattern.Pattern,out p)||e.TryGetCurrentPattern(InvokePattern.Pattern,out p));}
 static IEnumerable<OrbyApprovalRequest> InspectQuestions(AutomationElement root){
  var found=new List<OrbyApprovalRequest>();var seen=new HashSet<string>();
  foreach(var skip in Nodes(root,5000)){
   if(!Button(skip)||!Visible(skip)||!Regex.IsMatch(Name(skip),@"^Skip(?: question)?$",RegexOptions.IgnoreCase))continue;
   var panel=skip;
   for(int depth=0;depth<7;depth++){
    panel=TreeWalker.ControlViewWalker.GetParent(panel);if(panel==null||panel==root)break;
    var nodes=Nodes(panel,500);AutomationElement send=null,input=null;int submits=0,skips=0,inputs=0;bool marker=false;
    var texts=new List<string>();var choices=new List<string>();var controls=new List<AutomationElement>();
    foreach(var node in nodes){
     if(!Present(node))continue;string name=Name(node);var type=node.Current.ControlType;
     if(name=="Question")marker=true;
     if(type==ControlType.Edit&&Regex.IsMatch(name,@"(?:write|type|enter).*(?:response|answer)|(?:response|answer).*(?:write|type|enter)",RegexOptions.IgnoreCase)){object value;if(node.TryGetCurrentPattern(ValuePattern.Pattern,out value)&&!((ValuePattern)value).Current.IsReadOnly){input=node;inputs++;}continue;}
     if(Button(node)&&Regex.IsMatch(name,@"^(Send|Submit answers?|Send answers?)$",RegexOptions.IgnoreCase)){send=node;submits++;continue;}
     if(Button(node)&&Regex.IsMatch(name,@"^Skip(?: question)?$",RegexOptions.IgnoreCase)){skips++;continue;}
     if(type==ControlType.RadioButton||type==ControlType.ListItem||Button(node)){
      if(name.Length==0||Regex.IsMatch(name,@"^(Close|Dismiss|Back|Next|Previous|Cancel|Help)(?:\b|$)",RegexOptions.IgnoreCase))continue;
      string label=ChoiceName(name);
      if(label.Length>0&&label.Length<=500&&Selectable(node)&&!choices.Contains(label)){choices.Add(label);controls.Add(node);}continue;
     }
     if(type==ControlType.Text&&name.Length>0&&name.Length<=6000&&name!="Question"&&!Regex.IsMatch(name,@"^(Or write your own response|Write your own response)$",RegexOptions.IgnoreCase)&&!texts.Contains(name))texts.Add(name);
    }
    if(!marker||submits!=1||skips!=1||texts.Count==0)continue;
    texts.RemoveAll(x=>choices.Contains(ChoiceName(x))||Regex.IsMatch(x,@"^\d+$"));
    string prompt=string.Join("\n",texts.ToArray());if(prompt.Length==0||prompt.Length>6000)break;
    // A form with multiple questions/submit buttons or ambiguous choices stays in ChatGPT.
    bool canReply=inputs==1;
    var request=new OrbyApprovalRequest{Kind="question",Available=true,CanAnswer=choices.Count<=8&&(choices.Count>0||canReply),CanReply=canReply,ReplyInput=canReply?input:null,Title=prompt,Detail=canReply?"Choose an answer or write your response, then send it.":"Choose an answer, then send it. Open ChatGPT for a custom response.",Choices=choices.ToArray(),ChoiceControls=controls.ToArray(),Send=send};
    request.Id=Identity(panel,prompt,string.Join("\n",request.Choices)+"\ncustom:"+canReply);
    if(seen.Add(request.Id))found.Add(request);break;
   }
  }
  return found;
 }
 static OrbyApprovalRequest Find(){
  var found=new List<OrbyApprovalRequest>();
  try{var windows=AutomationElement.RootElement.FindAll(TreeScope.Children,Condition.TrueCondition);
   foreach(AutomationElement window in windows){if(!Visible(window))continue;string process="";try{process=Process.GetProcessById(window.Current.ProcessId).ProcessName;}catch{continue;}
    if(!Regex.IsMatch(process,@"^(ChatGPT|Codex)$",RegexOptions.IgnoreCase))continue;
    var candidate=InspectRoots(WindowRoots(window));if(candidate.Available){candidate.Target=window.Current.ProcessId+"|"+window.Current.NativeWindowHandle;found.Add(candidate);}else if(candidate.Status.StartsWith("Several"))return candidate;
   }
  }catch{return new OrbyApprovalRequest{Status="Permission controls could not be read"};}
  return found.Count==1?found[0]:new OrbyApprovalRequest{Status=found.Count>1?"Several requests are visible. Select the chat to approve.":"Waiting for accessible permission controls"};
 }
 public static Task<OrbyApprovalRequest> Poll(){return Task.Run(()=>Find());}
 public static Task<OrbyApprovalRequest> PollStop(string project){return Task.Run(()=>FindStop(project));}
 public static OrbyApprovalRequest InspectStopRoot(AutomationElement root,string project){
  if(String.IsNullOrWhiteSpace(project)||project.Length<2||!Visible(root)||Name(root).IndexOf(project,StringComparison.OrdinalIgnoreCase)<0)return new OrbyApprovalRequest();
  var buttons=new List<AutomationElement>();foreach(var node in Nodes(root,5000))if(Button(node)&&Invokable(node)&&Regex.IsMatch(Name(node),@"^(Stop|Stop streaming|Stop generating|Stop response|Stop task|Interrupt)$",RegexOptions.IgnoreCase))buttons.Add(node);
  if(buttons.Count!=1)return new OrbyApprovalRequest();return new OrbyApprovalRequest{Id=Identity(root,project,string.Join(",",buttons[0].GetRuntimeId())),Kind="stop",Target=project,Available=true,CanAnswer=true,Title="Stop current task: "+project,Detail="Stop only the currently visible ChatGPT/Codex task in "+project+". This does not delete the project.",Allow=buttons[0]};
 }
 static OrbyApprovalRequest FindStop(string project){
  var matches=new List<OrbyApprovalRequest>();try{foreach(AutomationElement root in AutomationElement.RootElement.FindAll(TreeScope.Children,Condition.TrueCondition)){
   string process;try{process=Process.GetProcessById(root.Current.ProcessId).ProcessName;}catch{continue;}
   if(!Regex.IsMatch(process,@"^(ChatGPT|Codex)$",RegexOptions.IgnoreCase))continue;var q=InspectStopRoot(root,project);if(q.Available)matches.Add(q);
  }}catch{return new OrbyApprovalRequest();}return matches.Count==1?matches[0]:new OrbyApprovalRequest();
 }
 public static Task<OrbyApprovalReply> Stop(string id,string project){return Task.Run(()=>Stop(()=>FindStop(project),id));}
 public static OrbyApprovalReply StopToRoot(AutomationElement root,string id,string project){return Stop(()=>InspectStopRoot(root,project),id);}
 static OrbyApprovalReply Stop(Func<OrbyApprovalRequest> discover,string id){
  try{var q=discover();object invoke;if(!q.Available||q.Id!=id||!q.Allow.TryGetCurrentPattern(InvokePattern.Pattern,out invoke))return new OrbyApprovalReply{Message="The visible task changed; nothing was stopped."};
   ((InvokePattern)invoke).Invoke();for(int i=0;i<8;i++){Thread.Sleep(150);var next=discover();if(!next.Available||next.Id!=id)return new OrbyApprovalReply{Submitted=true,Resolved=true,Message="Stop requested"};}return new OrbyApprovalReply{Submitted=true,Message="Stop submitted. Check the task status."};
  }catch{return new OrbyApprovalReply{Message="Could not stop this task. Check it on the PC."};}
 }
 public static OrbyApprovalReply RespondToRoot(AutomationElement root,string expectedId,bool allow){return Respond(()=>InspectRoot(root),expectedId,allow);}
 public static Task<OrbyApprovalReply> Respond(string expectedId,bool allow){return Task.Run(()=>Respond(()=>Find(),expectedId,allow));}
 public static Task<OrbyApprovalReply> Answer(string expectedId,int choice){return Task.Run(()=>Answer(()=>Find(),expectedId,choice));}
 public static Task<OrbyApprovalReply> Reply(string expectedId,string text){return Task.Run(()=>Reply(()=>Find(),expectedId,text));}
 public static OrbyApprovalReply ReplyToRoot(AutomationElement root,string expectedId,string text){return Reply(()=>InspectRoot(root),expectedId,text);}
 static OrbyApprovalReply Reply(Func<OrbyApprovalRequest> discover,string expectedId,string text){
  try{var q=discover();if(!q.Available||q.Kind!="question"||q.Id!=expectedId||!q.CanReply||String.IsNullOrWhiteSpace(text)||text.Length>2000)return new OrbyApprovalReply{Message="The current question cannot accept this response."};
   object value;if(!q.ReplyInput.TryGetCurrentPattern(ValuePattern.Pattern,out value)||((ValuePattern)value).Current.IsReadOnly)return new OrbyApprovalReply{Message="The response field is not accessible."};
   ((ValuePattern)value).SetValue(text);Thread.Sleep(120);var current=discover();object send;
   if(!current.Available||current.Id!=expectedId||!current.CanReply||!current.ReplyInput.TryGetCurrentPattern(ValuePattern.Pattern,out value)||((ValuePattern)value).Current.Value!=text||!Invokable(current.Send)||!current.Send.TryGetCurrentPattern(InvokePattern.Pattern,out send))return new OrbyApprovalReply{Message="The question changed or Send is unavailable. No response was sent."};
   ((InvokePattern)send).Invoke();for(int i=0;i<8;i++){Thread.Sleep(150);var next=discover();if(!next.Available||next.Id!=expectedId)return new OrbyApprovalReply{Submitted=true,Resolved=true,Message="Response sent"};}
   return new OrbyApprovalReply{Submitted=true,Message="Response sent. Checking confirmation."};
  }catch{return new OrbyApprovalReply{Message="Could not send the response. Review it in ChatGPT."};}
 }
 public static OrbyApprovalReply AnswerToRoot(AutomationElement root,string expectedId,int choice){return Answer(()=>InspectRoot(root),expectedId,choice);}
 static OrbyApprovalReply Answer(Func<OrbyApprovalRequest> discover,string expectedId,int choice){
  try{
   var current=discover();if(!current.Available||current.Kind!="question"||!current.CanAnswer||current.Id!=expectedId||choice<0||choice>=current.ChoiceControls.Length)return new OrbyApprovalReply{Message="The question changed. Review it again before sending."};
   var target=current.ChoiceControls[choice];object pattern;
   if(!Selectable(target))return new OrbyApprovalReply{Message="This answer is no longer accessible."};
   if(target.TryGetCurrentPattern(SelectionItemPattern.Pattern,out pattern))((SelectionItemPattern)pattern).Select();
   else if(target.TryGetCurrentPattern(InvokePattern.Pattern,out pattern))((InvokePattern)pattern).Invoke();
   else return new OrbyApprovalReply{Message="Choose this answer in ChatGPT."};
   Thread.Sleep(120);var selected=discover();
   if(!selected.Available)return new OrbyApprovalReply{Submitted=true,Resolved=true,Message="Answer sent"};
   if(selected.Id!=expectedId)return new OrbyApprovalReply{Message="The form changed after selecting. Review it in ChatGPT."};
   if(!Invokable(selected.Send)||!selected.Send.TryGetCurrentPattern(InvokePattern.Pattern,out pattern))return new OrbyApprovalReply{Message="ChatGPT has not enabled Send. Review your answer there."};
   ((InvokePattern)pattern).Invoke();
   for(int i=0;i<8;i++){Thread.Sleep(150);var next=discover();if(!next.Available||next.Id!=expectedId)return new OrbyApprovalReply{Submitted=true,Resolved=true,Message="Answer sent"};}
   return new OrbyApprovalReply{Submitted=true,Message="Answer sent. Waiting for ChatGPT to confirm."};
  }catch{return new OrbyApprovalReply{Message="Could not send the answer. Review it in ChatGPT."};}
 }
 static OrbyApprovalReply Respond(Func<OrbyApprovalRequest> discover,string expectedId,bool allow){
  try{var current=discover();if(!current.Available||current.Kind!="permission"||current.Id!=expectedId)return new OrbyApprovalReply{Message="The request changed. Review the new permission."};
   var target=allow?current.Allow:current.Deny;object action;if(!Invokable(target)||!target.TryGetCurrentPattern(InvokePattern.Pattern,out action))return new OrbyApprovalReply{Message="The permission button is no longer accessible."};
   ((InvokePattern)action).Invoke();
   for(int i=0;i<8;i++){Thread.Sleep(150);var next=discover();if(!next.Available||next.Id!=expectedId)return new OrbyApprovalReply{Submitted=true,Resolved=true,Message=allow?"Allowed once":"Denied"};}
   return new OrbyApprovalReply{Submitted=true,Message="Response sent. Waiting for ChatGPT to confirm."};
  }catch{return new OrbyApprovalReply{Message="Could not submit the response. Review it in ChatGPT."};}
 }
}

