$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'UI-Input-Classification.ps1')
. (Join-Path $PSScriptRoot 'Normal-Chat-Tracker.ps1')
function Buttons([string[]]$values){foreach($value in $values){[pscustomobject]@{Name=$value}}}
function Check($ok,$label){if(-not $ok){throw $label};$script:passed++}
$passed=0
foreach($message in @('Time to drink water. Did you have a glass?','Scheduled task completed: please confirm you saw this','Your daily science briefing is ready. Would you like more details?','Please choose when to read this reminder','Reminder: waiting for your response')){
 $input=Get-OrbyUiInputRequest @($message) @(Buttons @('Continue','Open chat','Dismiss'))
 Check ([string]::IsNullOrEmpty($input)) ('Reminder is content: '+$message)
 $script:normalChatLastWorking=$true;$script:normalChatState='working'
 [void](Update-OrbyNormalChatTracker ([pscustomobject]@{}) ([pscustomobject]@{Mode='CHAT';Working=$false;Failure=$false;Stopped=$false;InputRequest=$input}))
 Check ($script:normalChatState -eq 'success') 'Finished scheduled response is not awaiting approval'
}
Check ((Get-OrbyUiInputRequest @('Allow ChatGPT to view the contents of project?') @(Buttons @('Deny Esc','Allow once'))) -match '^Allow ChatGPT') 'Actual file permission retained'
Check ((Get-OrbyUiInputRequest @('Allow ChatGPT to connect to the internet?','Scheduled reminders') @(Buttons @('Deny','Allow once'))) -match '^Allow ChatGPT') 'Reminder wording cannot hide a real permission'
Check ([string]::IsNullOrEmpty((Get-OrbyUiInputRequest @('Allow ChatGPT to view files?') @(Buttons @('Continue'))))) 'Old permission text without live controls ignored'
Check ([string]::IsNullOrEmpty((Get-OrbyUiInputRequest @('Allow notifications') @(Buttons @('Deny','Allow'))))) 'Notification opt-in is not task approval'
Check ((Get-OrbyUiInputRequest @('Waiting for your answer') @(Buttons @('Submit answers'))) -eq 'Waiting for your answer') 'Dedicated answer form retained'
'PASS: '+$passed+' reminder versus blocking-input checks.'
