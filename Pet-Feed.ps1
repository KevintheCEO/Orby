# Mirrors local task lifecycle/item data used by the app's pet, read-only.
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
public class OrbitPetTask {
 public string Id,Title,Path,Turn,PendingCall="",State="idle",Action="Thinking";
 public DateTime Started=DateTime.MinValue,Last=DateTime.MinValue;
}
public static class OrbitPetFeed {
 [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_open_v2(byte[] p,out IntPtr db,int flags,IntPtr vfs);
 [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_close(IntPtr db);
 [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_prepare_v2(IntPtr db,byte[] sql,int len,out IntPtr stmt,IntPtr tail);
 [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_step(IntPtr stmt);
 [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)] static extern IntPtr sqlite3_column_text(IntPtr stmt,int col);
 [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_column_bytes(IntPtr stmt,int col);
 [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_finalize(IntPtr stmt);
 static byte[] Utf8(string s){return Encoding.UTF8.GetBytes(s+"\0");}
 static string Text(IntPtr stmt,int c){IntPtr p=sqlite3_column_text(stmt,c);int n=sqlite3_column_bytes(stmt,c);if(p==IntPtr.Zero)return "";byte[] b=new byte[n];Marshal.Copy(p,b,0,n);return Encoding.UTF8.GetString(b);}
 public static OrbitPetTask[] List(string path){
  var list=new List<OrbitPetTask>();IntPtr db=IntPtr.Zero,stmt=IntPtr.Zero;
  try{
   if(sqlite3_open_v2(Utf8(path),out db,1,IntPtr.Zero)!=0)throw new IOException("Cannot open read-only task database");
   string sql="SELECT id,COALESCE(NULLIF(name,''),title),rollout_path FROM threads ORDER BY updated_at DESC LIMIT 32";
   if(sqlite3_prepare_v2(db,Utf8(sql),-1,out stmt,IntPtr.Zero)!=0){
    if(stmt!=IntPtr.Zero){sqlite3_finalize(stmt);stmt=IntPtr.Zero;}
    sql="SELECT id,title,rollout_path FROM threads ORDER BY updated_at DESC LIMIT 32";
    if(sqlite3_prepare_v2(db,Utf8(sql),-1,out stmt,IntPtr.Zero)!=0)throw new IOException("Unsupported task database schema");
   }
   while(sqlite3_step(stmt)==100){string p=Text(stmt,2);if(p.StartsWith(@"\\?\"))p=p.Substring(4);list.Add(new OrbitPetTask{Id=Text(stmt,0),Title=Text(stmt,1),Path=p});}
   return list.ToArray();
  }finally{if(stmt!=IntPtr.Zero)sqlite3_finalize(stmt);if(db!=IntPtr.Zero)sqlite3_close(db);}
 }
 class Cache {public long Length;public DateTime Modified;public OrbitPetTask Task;}
 static Dictionary<string,Cache> cache=new Dictionary<string,Cache>();
 static string Field(string text,string key){var m=Regex.Match(text,"\""+key+"\"\\s*:\\s*\"([^\"]*)\"");return m.Success?m.Groups[1].Value:"";}
 public static OrbitPetTask Read(OrbitPetTask meta){
  var info=new FileInfo(meta.Path);if(!info.Exists)throw new FileNotFoundException("Task journal unavailable");
  Cache old;if(cache.TryGetValue(meta.Path,out old)&&old.Length==info.Length&&old.Modified==info.LastWriteTimeUtc){old.Task.Title=meta.Title;return old.Task;}
  var task=new OrbitPetTask{Id=meta.Id,Title=meta.Title,Path=meta.Path};
  // Scan the entire journal. A long turn can have many megabytes between its
  // start and completion; truncating to the final 2 MB loses the active turn.
  using(var fs=new FileStream(meta.Path,FileMode.Open,FileAccess.Read,FileShare.ReadWrite|FileShare.Delete))
  {
   bool newline=true;if(fs.Length>0){fs.Seek(-1,SeekOrigin.End);newline=fs.ReadByte()==10;fs.Position=0;}
   using(var reader=new StreamReader(fs,Encoding.UTF8)){
   string line;while((line=reader.ReadLine())!=null){
    if(reader.EndOfStream&&!newline)break;
    string head=line.Substring(0,Math.Min(line.Length,600));
    bool ev=Regex.IsMatch(head,"\"type\"\\s*:\\s*\"event_msg\"\\s*,\\s*\"payload\"\\s*:\\s*\\{\\s*\"type\"\\s*:");
    bool item=Regex.IsMatch(head,"\"type\"\\s*:\\s*\"response_item\"\\s*,\\s*\"payload\"\\s*:\\s*\\{\\s*\"type\"\\s*:");
    if(!ev&&!item)continue;
    int pos=head.IndexOf("\"payload\"");if(pos<0)continue;
    string payload=head.Substring(pos);string kind=Field(payload,"type");
    if(kind=="custom_tool_call")kind="function_call";
    if(kind=="custom_tool_call_output")kind="function_call_output";
    if(kind!="task_started"&&kind!="task_complete"&&kind!="turn_aborted"&&kind!="task_failed"&&kind!="function_call"&&kind!="function_call_output"&&kind!="exec_approval_request"&&kind!="apply_patch_approval_request"&&kind!="approval_request")continue;
    DateTime at;if(!DateTime.TryParse(Field(head,"timestamp"),null,System.Globalization.DateTimeStyles.AdjustToUniversal,out at))continue;
    string turn=Field(payload,"turn_id");
    if(kind=="task_started"){task.Turn=turn;task.PendingCall="";task.State="working";task.Started=at;task.Last=at;task.Action="Thinking";continue;}
    if(kind=="task_complete"||kind=="turn_aborted"||kind=="task_failed"){
     if(turn==task.Turn&&at>=task.Started){task.PendingCall="";task.State=kind=="task_complete"?"success":kind=="turn_aborted"?"stopped":"error";task.Last=at;}
     continue;
    }
    if(task.State!="working"&&task.State!="attention")continue;
    if(at<task.Started)continue;
    if(kind=="exec_approval_request"||kind=="apply_patch_approval_request"||kind=="approval_request"){
     if(turn.Length>0&&turn!=task.Turn)continue;
     task.PendingCall=Field(payload,"call_id");task.State="attention";task.Last=at;task.Action="Permission required - review in ChatGPT";continue;
    }
    task.Last=at;
    if(kind=="function_call_output"){
     if(task.State=="attention" && task.PendingCall.Length>0 && Field(payload,"call_id")!=task.PendingCall)continue;
     task.PendingCall="";task.State="working";task.Action="Thinking";continue;
    }
    string name=Field(payload,"name");
    string body=line.Substring(0,Math.Min(line.Length,12000));
    bool permission=name.EndsWith("request_permissions") || ((name.EndsWith(".exec")||name=="exec") && Regex.IsMatch(body,@"\btools\.request_permissions\s*\("));
    if(permission){
     task.PendingCall=Field(payload,"call_id");task.State="attention";
     task.Action=body.Contains("file_system")?"File access permission required - review in ChatGPT":body.Contains("network")?"Network permission required - review in ChatGPT":"Permission required - review in ChatGPT";
     continue;
    }
    if(task.State=="attention" && task.PendingCall.Length>0)continue;
    if(name.EndsWith(".exec")||name=="exec"){
     var tool=Regex.Match(line.Substring(0,Math.Min(line.Length,12000)),"exec_command|write_stdin|apply_patch|imagegen|web__run|request_user_input|view_image|read_thread|wait_threads");if(tool.Success)name=tool.Value;
    }
    if(name.Contains("request_user_input")){task.PendingCall=Field(payload,"call_id");task.State="attention";task.Action="Waiting for your input";}
    else {task.State="working";task.Action=Action(name);}
   }
   }
  }
  cache[meta.Path]=new Cache{Length=info.Length,Modified=info.LastWriteTimeUtc,Task=task};return task;
 }
 public static string Action(string name){
  if(Regex.IsMatch(name,"exec_command|write_stdin|shell_command"))return "Running command";
  if(Regex.IsMatch(name,"apply_patch|write_file|edit_file"))return "Editing files";
  if(Regex.IsMatch(name,"web.*run|search_query"))return "Searching / reading the web";
  if(name.Contains("imagegen"))return "Creating image";
  if(name.Contains("view_image"))return "Inspecting image";
  if(Regex.IsMatch(name,"read_thread|wait_threads"))return "Checking task progress";
  return name.Length==0?"Thinking":"Using tool";
 }
}
'@
$script:petPollAt=[datetime]::MinValue
$script:petFeedAvailable=$false
$script:petLastSignature=''
$script:petBootTime=[datetime]::UtcNow
try {
    $main=Get-Process ChatGPT -ErrorAction Stop | Where-Object {$null -ne $_.StartTime} | Sort-Object StartTime | Select-Object -First 1
    if ($main) {$script:petBootTime=$main.StartTime.ToUniversalTime()}
} catch {}

Add-Type -Path (Join-Path $PSScriptRoot 'Feed-Worker.cs')
$script:feedPollTask=$null
function Sync-OfficialTaskFeed {
    param([datetime]$Now=[datetime]::UtcNow)
    if($script:feedPollTask){
        if(-not $script:feedPollTask.IsCompleted){return}
        if(-not $script:feedPollTask.IsFaulted){
            $tasks=$script:feedPollTask.Result
            if($tasks.Count -gt 0){$script:petFeedAvailable=$true;Set-PetFeedSnapshot $tasks $Now (@(Get-Process ChatGPT -ErrorAction SilentlyContinue).Count -gt 0)}
        }else{Write-OrbitLog ('PET FEED unavailable: '+$script:feedPollTask.Exception.GetBaseException().Message)}
        $script:feedPollTask=$null
    }
    if (($Now-$script:petPollAt).TotalSeconds -lt 2) {return}
    $script:petPollAt=$Now
    $db=Get-ChildItem -LiteralPath $script:codexDataRoot -Filter 'state_*.sqlite' -ErrorAction SilentlyContinue | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
    if($db){$script:feedPollTask=[OrbyFeedWorker]::Poll([OrbitPetFeed],$db.FullName)}
}

function Set-PetFeedSnapshot {
    param([object[]]$Tasks,[datetime]$Now,[bool]$AppOpen=$true)
    # Recompute from present lifecycle state every poll. There is no LIVE latch.
    $running=@($Tasks | Where-Object {$_.State -in @('working','attention') -and $_.Started -ge $script:petBootTime} | Sort-Object @{Expression={if($_.State -eq 'attention'){0}else{1}};Ascending=$true},@{Expression='Started';Descending=$true})
    if(-not $AppOpen){$running=@()}
    $script:orbyActiveTasks=@($running)
    $chosen=$null
    if($running.Count){$chosen=$running[0]}
    else {$chosen=$Tasks | Where-Object {$_.Last -ge $script:petBootTime -and $_.State -in @('success','error','stopped')} | Sort-Object Last -Descending | Select-Object -First 1}
    $state='idle';$title='';$action='Waiting for a task'
    if($chosen){
        $state=$chosen.State;$title=($chosen.Title -replace '\s+',' ').Trim();$action=$chosen.Action
        if($title.Length -gt 100){$title=$title.Substring(0,97)+'...'}
        if($state -in @('success','error','stopped') -and ($Now-$chosen.Last).TotalSeconds -gt 5){$state='idle';$title='';$action='Waiting for a task'}
        if($state -in @('working','attention')) {
            $script:chatLogActiveConversation=$chosen.Id;$script:chatLogActiveTurn=$chosen.Turn
            $script:lastActiveActivity=$chosen.Last
        }
    }
    $signature="$state|$title|$action"
    $script:chatTaskTitle=$title
    if($signature -ne $script:petLastSignature){
        Set-ChatLogState $state $action 'pet-task-feed'
        Write-OrbitLog "PET FEED state=$state task=$title action=$action activeCount=$($running.Count)"
        $script:petLastSignature=$signature
    }else{$script:chatLogState=$state;$script:chatLogMessage=$action}
}
