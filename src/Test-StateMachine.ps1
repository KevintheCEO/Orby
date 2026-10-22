$ErrorActionPreference='Stop'
$script:records=New-Object System.Collections.Generic.List[string]
function Write-OrbitLog { param($Message) $script:records.Add($Message) }
function Update-ChatLogActivityFromLine { param($Line) }
. (Join-Path $PSScriptRoot 'Chat-State.ps1')
function Reset-Test {
    $script:chatLogState='idle'; $script:chatLogMessage=''; $script:chatLogActiveConversation=''; $script:chatLogActiveTurn=''
    $script:chatLogPendingCompleteAt=[datetime]::MinValue
    $script:chatLogRoots=@(); $script:chatLogLastSearchAt=[datetime]::MinValue
    . (Join-Path $PSScriptRoot 'Chat-State.ps1')
    $script:eventFloor=([datetimeoffset]::Parse('2026-10-03T00:00:00Z').UtcDateTime); $script:eventClock=$script:eventFloor
}
function Emit { param($Text, [int]$Second=1) Process-ChatGptLogLine ('2026-10-03T00:00:' + $Second.ToString('00') + 'Z ' + $Text) 'fixture' $Second }
function Assert-State { param($Expected,$Label) if ($script:chatLogState -ne $Expected) { throw "$Label expected $Expected got $script:chatLogState" }; $script:passed++ }
$script:passed=0
foreach ($terminal in @('latestTurnStatus=completed','latestTurnStatus=interrupted','latestTurnStatus=failed','latestTurnStatus=error','latestTurnStatus=cancelled','method=turn/completed','method=turn/finished','method=turn/failed','method=turn/cancelled')) {
    Reset-Test; Emit 'method=turn/start errorCode=null conversationId=A turnId=T1'
    $expected='success'; if ($terminal -match 'interrupted|cancelled') {$expected='stopped'} elseif ($terminal -match 'failed|error') {$expected='error'}
    Emit ("conversationId=A latestTurnId=T1 $terminal") 2; Assert-State $expected $terminal
    Emit 'method=turn/started conversationId=A turnId=T1' 3; Assert-State $expected 'closed turn cannot restart'
}
foreach ($terminal in @('thread_stream_view_activity_changed conversationId=A active=false','conversationId=A markedStreaming=false')) {
    Reset-Test; Emit 'method=turn/start conversationId=A turnId=T1'; Emit $terminal 2
    $script:chatLogPendingCompleteAt=(Get-Date).AddSeconds(-2); Normalize-TransientLogState; Assert-State 'success' $terminal
}
Reset-Test; Emit 'method=turn/start conversationId=A turnId=T1'; Emit 'method=turn/start conversationId=B turnId=T2' 3
Emit 'conversationId=A turnId=T1 latestTurnStatus=completed' 4; Assert-State 'working' 'other conversation terminal'
Emit 'method=turn/start conversationId=A turnId=T1' 2; Assert-State 'working' 'stale start'; if ($script:chatLogActiveConversation -ne 'B') {throw 'stale start changed IDs'}
Emit 'conversationId=B turnId=OLD latestTurnStatus=interrupted' 5; Assert-State 'working' 'old turn same conversation'
Emit 'conversationId=B latestTurnId=T2 latestTurnStatus=completed markedStreaming=true' 6; Assert-State 'success' 'terminal beats streaming true'
Reset-Test; Emit 'method=turn/start conversationId=A'; Emit 'threadId=A turnId=T1 item=reasoning' 2
if ($script:chatLogActiveTurn -ne 'T1') {throw 'did not learn turn ID'}
Emit 'threadId=A turnId=T1 request_user_input' 3; Assert-State 'attention' 'needs user'
Emit 'threadId=A turnId=T1 user_input_received' 4; Assert-State 'working' 'resume'
Emit 'thread_stream_view_activity_changed conversationId=A active=false' 5; Emit 'conversationId=A latestTurnId=T1 latestTurnStatus=interrupted' 6
Normalize-TransientLogState; Assert-State 'stopped' 'stop beats weak completion'
Reset-Test; Emit '{"method":"turn/started","params":{"threadId":"A","turn":{"id":"T1"}}}'
Emit '{"method":"turn/completed","params":{"threadId":"A","turn":{"id":"T1","status":"completed"}}}' 2
Assert-State 'success' 'JSON nested turn'
Reset-Test; Emit 'method=turn/start conversationId=A turnId=T1'
$now=[datetime]::UtcNow
$script:lastActiveActivity=$now.AddSeconds(-599); Invoke-ChatWatchdog 'absent' $now; Assert-State 'working' 'no short timeout'
$script:lastActiveActivity=$now.AddMinutes(-11); Invoke-ChatWatchdog 'present' $now; Assert-State 'working' 'stop preserves long task'
Invoke-ChatWatchdog 'unknown' $now; Assert-State 'working' 'unreadable UI safe'
Invoke-ChatWatchdog 'absent' $now; Assert-State 'working' 'first absence'
Invoke-ChatWatchdog 'absent' $now.AddSeconds(31); Assert-State 'success' 'confirmed absence ends latch'
Reset-Test; Emit 'method=turn/start conversationId=A turnId=T1'; $script:lastActiveActivity=$now.AddMinutes(-11)
Emit 'conversationId=OTHER item=tool' 2
if ($script:lastActiveActivity -gt $now.AddMinutes(-10)) {throw 'unrelated activity refreshed watchdog'}
$script:passed++
# Wait only in this test for asynchronous directory discovery, then consume it.
function Pump-LogWatcher {
    Update-ChatGptLogWatcher
    if($script:logDiscoveryTask){$script:logDiscoveryTask.Wait();Update-ChatGptLogWatcher}
}
# Real tailing: multiple files, partial lines, rotation, and historical replay.
$fixture=Join-Path ([IO.Path]::GetTempPath()) ('orbit-state-test-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($fixture)
try {
    Reset-Test; $script:chatLogRoots=@($fixture)
    $f1=Join-Path $fixture 'main.log'; $f2=Join-Path $fixture 'worker.log'
    [IO.File]::WriteAllText($f1,"2026-10-03T00:00:01Z method=turn/start conversationId=A turnId=T1`n",[Text.Encoding]::ASCII)
    [IO.File]::WriteAllText($f2,"2026-10-03T00:00:02Z conversationId=A latestTurnId=T1 latestTurnStatus=completed`n",[Text.Encoding]::ASCII)
    Pump-LogWatcher; Assert-State 'success' 'multi-file ordered terminal'
    [IO.File]::AppendAllText($f1,'2026-10-03T00:00:03Z method=turn/start conversationId=B turnId=T2',[Text.Encoding]::ASCII)
    Pump-LogWatcher; Assert-State 'success' 'partial line held'
    [IO.File]::AppendAllText($f1,"`n",[Text.Encoding]::ASCII)
    Pump-LogWatcher; Assert-State 'working' 'completed partial start'
    [IO.File]::WriteAllText($f2,"2026-10-03T00:00:04Z conversationId=B turnId=T2 method=turn/failed`n",[Text.Encoding]::ASCII)
    Pump-LogWatcher; Assert-State 'error' 'truncated rotated terminal'
    $script:chatLogLastSearchAt=[datetime]::MinValue
    [IO.File]::WriteAllText((Join-Path $fixture 'old.log'),"2026-10-02T00:00:01Z method=turn/start conversationId=OLD`n",[Text.Encoding]::ASCII)
    Pump-LogWatcher; Assert-State 'error' 'discovered old file cannot resurrect'
} finally { [IO.Directory]::Delete($fixture,$true) }
foreach ($file in Get-ChildItem $PSScriptRoot -Filter '*.ps1') {
    $tokens=$null; $errors=$null
    [void][Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
    if ($errors.Count) {throw ($errors | Out-String)}
}
if (-not ($script:records | Where-Object {$_ -match 'oldState.*newState.*reason'})) {throw 'missing debug event records'}
Write-Output "PASS: $script:passed state assertions; all scripts parse under PowerShell $($PSVersionTable.PSVersion)."

