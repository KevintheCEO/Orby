# PowerShell 5.1. No UI dependencies: replayable state machine.
$script:eventFloor = [datetime]::UtcNow
$script:eventClock = $script:eventFloor
$script:eventSequence = 0L
$script:activeStartClock = [datetime]::MinValue
$script:activeStartSequence = 0L
$script:lastActiveActivity = [datetime]::UtcNow
$script:closedTurns = @{}
$script:logReaders = @{}
$script:watchdogSeconds = 600
$script:watchdogAbsentAt = [datetime]::MinValue

function Get-ChatLogField {
    param([string]$Line, [string]$Field)
    $pattern = '(?i)(?:^|[\s,{])"?' + [regex]::Escape($Field) + '"?\s*[:=]\s*(?:"([^"\r\n]*)"|([^\s,}\]]+))'
    $m = [regex]::Match($Line, $pattern)
    if ($m.Success) {
        $value = $m.Groups[1].Value
        if (-not $m.Groups[1].Success) { $value = $m.Groups[2].Value }
        if ($value -notin @('null','undefined')) { return $value }
    }
    return ''
}

function Write-StateEvent {
    param($Event, [string]$Old, [string]$Reason)
    $record = [ordered]@{timestamp=[datetime]::UtcNow.ToString('o'); eventTime=$Event.Time.ToString('o'); position=$Event.Position; source=$Event.Source; conversationId=$Event.Conversation; turnId=$Event.Turn; activeConversationId=$script:chatLogActiveConversation; activeTurnId=$script:chatLogActiveTurn; event=$Event.Kind; oldState=$Old; newState=$script:chatLogState; reason=$Reason}
    Write-OrbitLog ('EVENT ' + ($record | ConvertTo-Json -Compress))
}

function Set-ChatLogState {
    param([string]$State, [string]$Message, [string]$Evidence='')
    $old = $script:chatLogState
    $script:chatLogState = $State
    $script:chatLogMessage = $Message
    $script:chatLogEvidence = $Evidence
    $script:chatLogStateAt = Get-Date
    $script:chatLogSourceSeen = $true
    if ($State -in @('success','stopped','error')) {
        if ($script:chatLogActiveTurn) { $script:closedTurns[$script:chatLogActiveConversation + '|' + $script:chatLogActiveTurn] = $true }
        $script:chatLogPendingCompleteAt = [datetime]::MinValue
    }
    if ($old -ne $State) {
        $e = [pscustomobject]@{Time=$script:eventClock; Position=$script:eventSequence; Source='state'; Conversation=$script:chatLogActiveConversation; Turn=$script:chatLogActiveTurn; Kind=$Evidence}
        Write-StateEvent $e $old $Evidence
    }
}

function Process-ChatGptLogLine {
    param([string]$Line, [string]$Source='direct', [long]$Position=0)
    if (-not $Line) { return }
    $script:eventSequence++
    $time = $script:eventClock
    $stamp = [regex]::Match($Line, '\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})')
    if ($stamp.Success) { try { $time = [datetimeoffset]::Parse($stamp.Value).UtcDateTime } catch {} }
    $c = Get-ChatLogField $Line 'conversationId'
    if (-not $c) { $c = Get-ChatLogField $Line 'threadId' }
    $t = Get-ChatLogField $Line 'turnId'
    if (-not $t) { $t = Get-ChatLogField $Line 'latestTurnId' }
    # Structured notifications may embed thread/turn objects.
    if (-not $t -and $Line -match '"turn"\s*:\s*\{\s*"id"\s*:\s*"([^"]+)"') { $t = $Matches[1] }
    if (-not $c -and $t -and $t -eq $script:chatLogActiveTurn) { $c=$script:chatLogActiveConversation }
    $status = Get-ChatLogField $Line 'latestTurnStatus'
    if (-not $status) { $status = Get-ChatLogField $Line 'turnStatus' }
    if (-not $status -and ($t -or $Line -match 'turn[/_-]')) { $status = Get-ChatLogField $Line 'status' }
    $method = Get-ChatLogField $Line 'method'
    $kind = 'activity'
    # Terminal wins even if the same snapshot still says markedStreaming=true.
    if ($status -match '^(interrupted|cancelled|canceled|stopped|paused)$' -or $Line -match 'turn/(interrupted|cancelled|canceled)\b|kind=turn-cancelled|(?:interrupted|cancelled|canceled|stopped|paused)_by_user') { $kind='stop' }
    elseif ($status -match '^(failed|error)$' -or $Line -match 'turn/(failed|error)\b|structured turn failed:') { $kind='fail' }
    elseif ($status -match '^(completed|finished|done)$' -or $Line -match 'turn/(completed|complete|finished)\b|kind=turn-complete\b|\[desktop-notifications\] received turn-complete') { $kind='done' }
    elseif (($Line -match 'thread_stream_view_activity_changed' -and (Get-ChatLogField $Line 'active') -eq 'false') -or (Get-ChatLogField $Line 'markedStreaming') -eq 'false') { $kind='stream-end' }
    elseif ($Line -match 'request_user_input.{0,60}(response|result)|user_input_received') { $kind='resume' }
    elseif ($Line -match 'request_user_input|kind=question') { $kind='need' }
    elseif (($method -eq 'turn/start' -and (Get-ChatLogField $Line 'errorCode') -in @('','null')) -or $Line -match 'turn/started\b|kind=turn-start\b' -or $status -match '^(inprogress|running)$') { $kind='start' }
    $e = [pscustomobject]@{Time=$time; Position=$Position; Source=$Source; Conversation=$c; Turn=$t; Kind=$kind}
    $old = $script:chatLogState
    $reason = 'unrelated'
    if ($time -lt $script:eventFloor -or $time -lt $script:eventClock) { Write-StateEvent $e $old 'stale-timestamp'; return }
    # Only related events advance the state clock; background telemetry must not
    # make a delayed current-turn completion obsolete.
    $belongs = ($c -and $c -eq $script:chatLogActiveConversation) -or ($t -and $t -eq $script:chatLogActiveTurn)
    if ($c -and $script:chatLogActiveConversation -and $c -ne $script:chatLogActiveConversation) { $belongs=$false }
    if ($t -and $script:chatLogActiveTurn -and $t -ne $script:chatLogActiveTurn) { $belongs=$false }
    if (-not $c -and -not $t) {
        # Source identity alone cannot associate general telemetry with a turn.
        $belongs = $kind -ne 'activity' -and $Source -eq $script:activeLogSource -and $script:chatLogState -in @('working','attention')
    }
    if ($kind -eq 'activity' -and -not $t) { $belongs=$false }
    if ($kind -eq 'start') {
        $closed = $t -and $script:closedTurns.ContainsKey($c + '|' + $t)
        $sameClosed = $c -eq $script:chatLogActiveConversation -and (-not $t -or $t -eq $script:chatLogActiveTurn) -and $script:chatLogState -in @('success','error','stopped','idle')
        if ($closed -or ($sameClosed -and $time -le $script:eventClock)) { $reason='closed-turn-start-rejected' }
        elseif (-not $c -and -not $t -and -not $belongs) { $reason='unscoped-start-rejected' }
        else {
            $same = $belongs -and $script:chatLogState -in @('working','attention')
            if (-not $same) { $script:chatLogActiveConversation=$c; $script:chatLogActiveTurn=$t; $script:activeStartClock=$time; $script:activeStartSequence=$script:eventSequence; $script:chatTaskTitle='' }
            elseif ($t -and -not $script:chatLogActiveTurn) { $script:chatLogActiveTurn=$t }
            $script:activeLogSource=$Source
            $script:eventClock=$time
            $script:lastActiveActivity=[datetime]::UtcNow
            $script:watchdogAbsentAt=[datetime]::MinValue
            $script:chatLogPendingCompleteAt=[datetime]::MinValue
            Set-ChatLogState 'working' 'ChatGPT is working...' 'turn-start'
            $reason='current-start'
        }
    } elseif ($belongs) {
        $script:eventClock=$time
        if ($t -and -not $script:chatLogActiveTurn -and $script:chatLogState -in @('working','attention')) { $script:chatLogActiveTurn=$t }
        $script:lastActiveActivity=[datetime]::UtcNow
        $script:watchdogAbsentAt=[datetime]::MinValue
        $reason='current-' + $kind
        switch ($kind) {
            stop { Set-ChatLogState 'stopped' 'ChatGPT stopped' 'turn-interrupted' }
            fail { Set-ChatLogState 'error' 'ChatGPT task failed' 'turn-failed' }
            done { if ($script:chatLogState -notin @('stopped','error')) { Set-ChatLogState 'success' 'ChatGPT finished' 'turn-complete' } }
            stream-end { if ($script:chatLogState -eq 'working' -and $script:chatLogPendingCompleteAt -eq [datetime]::MinValue) { $script:chatLogPendingCompleteAt=Get-Date; $script:chatLogPendingCompleteEvidence='stream-ended' } }
            need { if ($script:chatLogState -eq 'working') { $script:chatLogPendingCompleteAt=[datetime]::MinValue; Set-ChatLogState 'attention' 'ChatGPT needs you' 'request-user-input' } }
            resume { if ($script:chatLogState -eq 'attention') { Set-ChatLogState 'working' 'ChatGPT is working...' 'input-response' } }
            activity { Update-ChatLogActivityFromLine $Line.ToLowerInvariant() }
        }
    }
    Write-StateEvent $e $old $reason
}

function Update-ChatGptLogWatcher {
    $now = [datetime]::UtcNow
    if ($now -gt $script:chatLogLastSearchAt.AddSeconds(3)) {
        $script:chatLogLastSearchAt=$now
        foreach ($root in $script:chatLogRoots) {
            foreach ($file in @(Get-ChildItem -LiteralPath $root -File -Recurse -Filter '*.log' -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTimeUtc -gt $script:eventFloor.AddMinutes(-10) })) {
                if (-not $script:logReaders.ContainsKey($file.FullName)) {
                    # Never replay a newly discovered old file; timestamp floor
                    # rejects its historical records, including after rotation.
                    $script:logReaders[$file.FullName]=@{Cursor=0L; Carry=''; InitialLength=$file.Length; Decoder=[Text.Encoding]::UTF8.GetDecoder()}
                }
            }
        }
    }
    $batch=New-Object System.Collections.Generic.List[object]
    foreach ($path in @($script:logReaders.Keys | Sort-Object)) {
        $r=$script:logReaders[$path]
        try {
            $fs=[IO.File]::Open($path,'Open','Read','ReadWrite')
            try {
                if ($fs.Length -lt $r.Cursor) { $r.Cursor=0L; $r.Carry=''; $r.InitialLength=$fs.Length; $r.Decoder.Reset() }
                [void]$fs.Seek($r.Cursor,'Begin')
                $count=[int][Math]::Min(1048576, $fs.Length-$r.Cursor)
                if ($count -le 0) { continue }
                $bytes=New-Object byte[] $count
                $read=$fs.Read($bytes,0,$count)
                $r.Cursor += $read
                $chars=New-Object char[] ([Text.Encoding]::UTF8.GetMaxCharCount($read))
                $n=$r.Decoder.GetChars($bytes,0,$read,$chars,0,$false)
                $r.Carry += [string]::new($chars,0,$n)
                $lines=$r.Carry -split "`n"
                for ($i=0; $i -lt $lines.Count-1; $i++) {
                    $line=$lines[$i].TrimEnd("`r")
                    $stamp=[regex]::Match($line,'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})')
                    $time=$script:eventClock
                    if ($stamp.Success) { try { $time=[datetimeoffset]::Parse($stamp.Value).UtcDateTime } catch {} }
                    if ($time -ge $script:eventFloor -and ($stamp.Success -or $r.Cursor -gt $r.InitialLength)) { $batch.Add([pscustomobject]@{Line=$line; Time=$time; Source=$path; Position=$r.Cursor; Index=$i}) }
                }
                $r.Carry=$lines[$lines.Count-1]
            } finally { $fs.Dispose() }
        } catch { Write-OrbitLog ('LOG read warning: ' + $_.Exception.Message) }
    }
    foreach ($item in @($batch | Sort-Object Time,Source,Position,Index)) { Process-ChatGptLogLine $item.Line $item.Source ($item.Position + $item.Index) }
}

function Normalize-TransientLogState {
    $now=Get-Date
    if ($script:chatLogPendingCompleteAt -ne [datetime]::MinValue -and $now -gt $script:chatLogPendingCompleteAt.AddMilliseconds(900)) {
        if ($script:chatLogState -eq 'working') { Set-ChatLogState 'success' 'ChatGPT finished' 'stream-ended' }
        $script:chatLogPendingCompleteAt=[datetime]::MinValue
    }
    $seconds=0
    switch ($script:chatLogState) { success {$seconds=3} stopped {$seconds=3.2} error {$seconds=5} }
    # Retain IDs and tombstones after returning idle.
    if ($seconds -gt 0 -and $now -gt $script:chatLogStateAt.AddSeconds($seconds)) { Set-ChatLogState 'idle' '' 'terminal-display-expired' }
}

function Invoke-ChatWatchdog {
    param([string]$UiResult, [datetime]$Now=[datetime]::UtcNow)
    if ($script:chatLogState -ne 'working' -or ($Now-$script:lastActiveActivity).TotalSeconds -lt $script:watchdogSeconds) { return }
    $e=[pscustomobject]@{Time=$script:eventClock; Position=$script:eventSequence; Source='watchdog'; Conversation=$script:chatLogActiveConversation; Turn=$script:chatLogActiveTurn; Kind='watchdog'}
    if ($UiResult -ne 'absent') { $script:watchdogAbsentAt=[datetime]::MinValue; Write-StateEvent $e $script:chatLogState ('ui-' + $UiResult + '-keep-live'); return }
    if ($script:watchdogAbsentAt -eq [datetime]::MinValue) { $script:watchdogAbsentAt=$Now; Write-StateEvent $e $script:chatLogState 'first-readable-no-stop'; return }
    if (($Now-$script:watchdogAbsentAt).TotalSeconds -ge 30) { Set-ChatLogState 'success' 'ChatGPT finished' 'watchdog-two-readable-no-stop-checks' }
}

function Get-WatchdogUiResult {
    param($Chat)
    if ($null -eq $Chat) { return 'unknown' }
    try {
        if ($Chat.Current.IsOffscreen -or $Chat.Current.BoundingRectangle.IsEmpty) { return 'unknown' }
        $items=@(Get-NamedControls $Chat ([System.Windows.Automation.ControlType]::Button) 1600)
        $readable=0; $unnamed=0
        foreach ($item in $items) {
            if ($item.IsOffscreen -or -not $item.IsEnabled) { continue }
            $signal=([string]$item.Name + ' ' + [string]$item.AutomationId + ' ' + [string]$item.HelpText).Trim()
            if (-not $signal) { $unnamed++; continue }
            $readable++
            if ($signal -match '(?i)\bstop\b|\binterrupt\b|stop[_-]?(response|streaming|generating)|\bcancel (response|generation|task)\b') { return 'present' }
        }
        # Empty trees and unidentified buttons are not proof of completion.
        if ($readable -lt 3 -or $unnamed -gt 0) { return 'unknown' }
        $composer=$false
        foreach ($edit in @(Get-NamedControls $Chat ([System.Windows.Automation.ControlType]::Edit) 500)) {
            if ($edit.IsOffscreen -or -not $edit.IsEnabled) { continue }
            $label=([string]$edit.Name + ' ' + [string]$edit.AutomationId + ' ' + [string]$edit.HelpText)
            if ($label -match '(?i)prompt|message|ask anything|ask a follow') { $composer=$true }
        }
        if (-not $composer) { return 'unknown' }
        return 'absent'
    } catch { return 'unknown' }
}
