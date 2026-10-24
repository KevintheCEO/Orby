$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Approval-Bridge.ps1')
function Assert($Value,$Message){if(-not $Value){throw $Message};$script:checks++}
$now=[datetime]::UtcNow
$script:orbyActiveTasks=@([pscustomobject]@{Id='test-project';Turn='test-turn';Provider='chatgpt'})
$q=[pscustomobject]@{Id='native-1';Target='process|window';Available=$true;CanAnswer=$true;Kind='question';Title='Fixture question';Detail='Choose an answer';Choices=@('One','Two');CanReply=$true}
Update-OrbyHandoffClock $q $now
$start=$script:approvalFirstSeen
for($i=1;$i -le 151;$i++){$q.Id='native-'+$i;Update-OrbyHandoffClock $q ($now.AddSeconds(2*$i))}
Assert ($script:approvalFirstSeen -eq $start -and $script:approvalNativeRefreshes -gt 0) 'Accessibility remounts restarted the five-minute countdown'
Assert (($now.AddSeconds(302)-$script:approvalFirstSeen).TotalSeconds -ge 300) 'A continuously present question never reached five minutes'
$q.Choices[1]='Changed option';Update-OrbyHandoffClock $q ($now.AddSeconds(303))
Assert ($script:approvalFirstSeen -eq $now.AddSeconds(303)) 'A changed answer reused the previous question timer'
$q.Target='another-window';Update-OrbyHandoffClock $q ($now.AddSeconds(304))
Assert ($script:approvalFirstSeen -eq $now.AddSeconds(304)) 'An identical question in a different window reused the timer'
$script:orbyActiveTasks[0].Turn='new-turn';Update-OrbyHandoffClock $q ($now.AddSeconds(305))
Assert ($script:approvalFirstSeen -eq $now.AddSeconds(305)) 'A new task turn inherited an older question timer'
Update-OrbyHandoffClock ([pscustomobject]@{Available=$false}) ($now.AddSeconds(306))
Update-OrbyHandoffClock $q ($now.AddSeconds(307))
Assert ($script:approvalFirstSeen -eq $now.AddSeconds(305)) 'A brief unreadable scan restarted an unchanged question timer'
Update-OrbyHandoffClock ([pscustomobject]@{Available=$false}) ($now.AddSeconds(320))
Assert (-not $script:approvalFirstSeen) 'A missing question retained an active countdown'
Update-OrbyHandoffClock $q ($now.AddSeconds(321))
Assert ($script:approvalFirstSeen -eq $now.AddSeconds(321)) 'A returning question inherited an expired continuity window'
$script:approvalRequest=$q;$clockNow=$now.AddSeconds(321)
$script:phoneConfig=@{Enabled=$true;Approvals=$true;Trusted=@{fixture='test'}};$script:phoneReadyCount=1;$script:phoneConnectedAt=$clockNow
Assert ((Get-OrbyPhoneCountdown $clockNow).Text -eq 'Phone in 5:00') 'New request did not show a five-minute countdown'
$script:phoneConnectedAt=$clockNow.AddSeconds(75)
Assert ((Get-OrbyPhoneCountdown ($clockNow.AddSeconds(75))).Text -eq 'Phone in 3:45') 'Visible countdown did not follow elapsed time'
$script:phoneConnectedAt=$clockNow.AddSeconds(300)
Assert ((Get-OrbyPhoneCountdown ($clockNow.AddSeconds(300))).Text -eq 'Sending to phone...') 'Timer claimed delivery before acknowledgement'
$script:phoneReadyCount=0
Assert ((Get-OrbyPhoneCountdown ($clockNow.AddSeconds(300))).Text -eq 'Phone paused') 'Missing notification-ready phone showed a false sending countdown'
$script:phoneConfig.Approvals=$false
Assert (-not (Get-OrbyPhoneCountdown $clockNow).Visible) 'Disabled phone responses showed a live countdown'
$script:phoneConfig.Approvals=$true;$script:phoneReadyCount=1;$script:approvalAnswered=$q.Id
Assert (-not (Get-OrbyPhoneCountdown $clockNow).Visible) 'Answered question kept its countdown'
"PASS: $script:checks handoff clock checks; exact native response identity and freshness guards remain separate."
