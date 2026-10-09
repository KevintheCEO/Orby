# Read-only Windows SQLite metadata and append-only task lifecycle evidence.
$script:chatTaskTitle=''
$script:taskEvidenceAt=[datetime]::MinValue
$script:taskMetadataCache=@{}
$script:taskTailCache=@{}
$script:codexDataRoot=Join-Path $env:USERPROFILE '.codex'
if ($env:CODEX_HOME) { $script:codexDataRoot=$env:CODEX_HOME }
try {
    if (-not ('OrbitReadOnlyTasks' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class OrbitReadOnlyTasks {
 [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_open_v2(byte[] p, out IntPtr db, int flags, IntPtr vfs);
 [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_close(IntPtr db);
 [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_prepare_v2(IntPtr db, byte[] sql, int len, out IntPtr stmt, IntPtr tail);
 [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_step(IntPtr stmt);
 [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)] static extern IntPtr sqlite3_column_text(IntPtr stmt,int col);
 [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_column_bytes(IntPtr stmt,int col);
 [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_finalize(IntPtr stmt);
 static byte[] Utf8(string s) {return Encoding.UTF8.GetBytes(s+"\0");}
 static string Text(IntPtr stmt,int col) {IntPtr p=sqlite3_column_text(stmt,col); int n=sqlite3_column_bytes(stmt,col); if(p==IntPtr.Zero)return ""; byte[] b=new byte[n]; Marshal.Copy(p,b,0,n);return Encoding.UTF8.GetString(b);}
 public static string[] Get(string path,string id) {
  IntPtr db=IntPtr.Zero,stmt=IntPtr.Zero;
  try {
   if(sqlite3_open_v2(Utf8(path),out db,1,IntPtr.Zero)!=0)return null;
   string sql="SELECT COALESCE(NULLIF(name,''),title),rollout_path FROM threads WHERE id='"+id.Replace("'","''")+"' LIMIT 1";
   if(sqlite3_prepare_v2(db,Utf8(sql),-1,out stmt,IntPtr.Zero)!=0) {
    sql="SELECT title,rollout_path FROM threads WHERE id='"+id.Replace("'","''")+"' LIMIT 1";
    if(stmt!=IntPtr.Zero){sqlite3_finalize(stmt);stmt=IntPtr.Zero;}
    if(sqlite3_prepare_v2(db,Utf8(sql),-1,out stmt,IntPtr.Zero)!=0)return null;
   }
   if(sqlite3_step(stmt)!=100)return null;
   return new string[]{Text(stmt,0),Text(stmt,1)};
  } finally {if(stmt!=IntPtr.Zero)sqlite3_finalize(stmt);if(db!=IntPtr.Zero)sqlite3_close(db);}
 }
}
'@
    }
} catch { Write-OrbitLog ('Task metadata reader unavailable: ' + $_.Exception.Message) }

function Get-LocalTaskMetadata {
    param([string]$Conversation)
    if (-not $Conversation -or $Conversation -notmatch '^[a-zA-Z0-9_-]+$') {return $null}
    $cached=$script:taskMetadataCache[$Conversation]
    if ($cached -and ([datetime]::UtcNow-$cached.At).TotalSeconds -lt 30) {return $cached}
    foreach ($db in @(Get-ChildItem -LiteralPath $script:codexDataRoot -Filter 'state_*.sqlite' -ErrorAction SilentlyContinue | Sort-Object LastWriteTimeUtc -Descending)) {
        try {
            $row=[OrbitReadOnlyTasks]::Get($db.FullName,$Conversation)
            if ($row -and $row.Length -eq 2) {
                $title=($row[0] -replace '\s+',' ').Trim()
                if ($title.Length -gt 100) {$title=$title.Substring(0,97)+'...'}
                $path=$row[1]
                if ($path.StartsWith('\\?\')) {$path=$path.Substring(4)}
                $meta=[pscustomobject]@{At=[datetime]::UtcNow;Title=$title;Path=$path}
                $script:taskMetadataCache[$Conversation]=$meta
                return $meta
            }
        } catch {}
    }
    return $null
}

function Get-TaskTail {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {return @()}
    $info=Get-Item -LiteralPath $Path
    $cache=$script:taskTailCache[$Path]
    if ($cache -and $cache.Length -eq $info.Length -and $cache.Modified -eq $info.LastWriteTimeUtc) {return $cache.Events}
    $events=New-Object System.Collections.Generic.List[object]
    $fs=[IO.File]::Open($Path,'Open','Read','ReadWrite')
    try {
        $offset=[Math]::Max(0,$fs.Length-2097152)
        [void]$fs.Seek($offset,'Begin')
        $reader=New-Object IO.StreamReader($fs,[Text.Encoding]::UTF8)
        try {
            if ($offset -gt 0) {[void]$reader.ReadLine()}
            while (-not $reader.EndOfStream) {
                $line=$reader.ReadLine()
                # Parse only lifecycle, turn context and function-call records.
                if ($line -notmatch '"type"\s*:\s*"(event_msg|response_item)"' -or $line -notmatch 'task_started|task_complete|turn_aborted|task_failed|function_call') {continue}
                try {
                    $j=$line | ConvertFrom-Json
                    $kind=$j.payload.type
                    if ($kind -notin @('task_started','task_complete','turn_aborted','task_failed','function_call','function_call_output')) {continue}
                    $name=[string]$j.payload.name
                    if ($name -match '(^|\.)exec$') {
                        $tool=[regex]::Match([string]$j.payload.arguments,'exec_command|write_stdin|apply_patch|imagegen|web__run|request_user_input|view_image|read_thread|wait_threads')
                        if ($tool.Success) {$name=$tool.Value}
                    }
                    $events.Add([pscustomobject]@{Time=[datetimeoffset]::Parse($j.timestamp).UtcDateTime;Kind=$kind;Turn=[string]$j.payload.turn_id;Name=$name})
                } catch {}
            }
        } finally {$reader.Dispose()}
    } finally {$fs.Dispose()}
    $script:taskTailCache[$Path]=@{Length=$info.Length;Modified=$info.LastWriteTimeUtc;Events=@($events.ToArray())}
    return $events.ToArray()
}

function Get-TaskAction {
    param([string]$Name)
    switch -Regex ($Name) {
        'exec_command|write_stdin|shell_command' {return 'Running command'}
        'apply_patch|write_file|edit_file' {return 'Editing files'}
        'web.*run|search_query' {return 'Searching / reading the web'}
        'imagegen' {return 'Creating image'}
        'request_user_input' {return 'Waiting for your input'}
        'read_thread|wait_threads' {return 'Checking task progress'}
        'view_image' {return 'Inspecting image'}
        'clock.*sleep|wait_agent' {return 'Waiting'}
        default {if($Name){return 'Using tool'};return 'Thinking'}
    }
}

function Update-LocalTaskEvidence {
    param([datetime]$Now=[datetime]::UtcNow)
    if (($Now-$script:taskEvidenceAt).TotalSeconds -lt 2 -or -not $script:chatLogActiveConversation) {return}
    $script:taskEvidenceAt=$Now
    $meta=Get-LocalTaskMetadata $script:chatLogActiveConversation
    if (-not $meta) {return}
    $script:chatTaskTitle=$meta.Title
    try {$events=@(Get-TaskTail $meta.Path)} catch {return}
    $start=$events | Where-Object {$_.Kind -eq 'task_started'} | Select-Object -Last 1
    if (-not $start) {return}
    # Exact latest task lifecycle can correct view/subscription events. Never
    # let a prior turn's completion end a new start still awaiting its journal.
    if ($script:chatLogActiveTurn -and $start.Turn -ne $script:chatLogActiveTurn) {return}
    if (-not $script:chatLogActiveTurn -and $start.Time -lt $script:activeStartClock.AddSeconds(-2)) {return}
    if (-not $script:chatLogActiveTurn) {$script:chatLogActiveTurn=$start.Turn}
    $terminal=$events | Where-Object {$_.Turn -eq $start.Turn -and $_.Kind -in @('task_complete','turn_aborted','task_failed') -and $_.Time -ge $start.Time} | Select-Object -Last 1
    if ($terminal -and $script:chatLogState -in @('working','attention')) {
        switch ($terminal.Kind) {
            task_complete {Set-ChatLogState 'success' 'Task finished' 'session-task-complete'}
            turn_aborted {Set-ChatLogState 'stopped' 'Task stopped' 'session-turn-aborted'}
            task_failed {Set-ChatLogState 'error' 'Task failed' 'session-task-failed'}
        }
        return
    }
    if ($script:chatLogState -eq 'working') {
        $action=$events | Where-Object {$_.Kind -in @('function_call','function_call_output') -and $_.Time -ge $start.Time} | Select-Object -Last 1
        $message='Thinking'
        if ($action -and $action.Kind -eq 'function_call') {$message=Get-TaskAction $action.Name}
        $script:chatLogMessage=$message
        $last=$events | Where-Object {$_.Time -ge $start.Time} | Select-Object -Last 1
        if ($last -and $last.Time -gt $script:lastActiveActivity) {$script:lastActiveActivity=$last.Time}
    }
}

function Get-NotchTaskTitle {
    param([string]$Fallback='ChatGPT is working')
    if (-not [string]::IsNullOrWhiteSpace($script:chatTaskTitle)) {return $script:chatTaskTitle}
    return $Fallback
}
