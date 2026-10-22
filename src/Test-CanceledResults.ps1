$ErrorActionPreference='Stop'
function Import-Function($file,$name){$t=$null;$e=$null;$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot $file),[ref]$t,[ref]$e);$node=$ast.Find({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name},$true);return $node.Extent.Text}
. ([scriptblock]::Create((Import-Function 'Pet-Feed.ps1' 'Sync-OfficialTaskFeed')))
. ([scriptblock]::Create((Import-Function 'File-Shelf.ps1' 'Update-OrbyShelf')))
. ([scriptblock]::Create((Import-Function 'Approval-Bridge.ps1' 'Update-OrbyApprovalBridge')))
function Canceled {$t=[Threading.Tasks.TaskCompletionSource[object]]::new();$t.SetCanceled();return $t.Task}
function Assert($ok,$why){if(-not $ok){throw $why}}
function Write-OrbitLog($message){}
$now=[datetime]::UtcNow;$script:petPollAt=$now;$script:feedPollTask=Canceled
Sync-OfficialTaskFeed $now
Assert (-not $script:feedPollTask) 'Canceled feed stayed latched'
$script:approvalPollAt=$now;$script:approvalPollTask=Canceled
Update-OrbyApprovalBridge
Assert (-not $script:approvalPollTask) 'Canceled approval poll stayed latched'
$script:orbyCopies=[Collections.Generic.List[object]]::new();$script:orbyCopies.Add((Canceled));$script:desktopControls=@{ShelfMessage=[pscustomobject]@{Text=''}}
$script:shelfPollAt=$now;$script:shelfInventoryTask=Canceled
Update-OrbyShelf
Assert ($script:orbyCopies.Count -eq 0 -and -not $script:shelfInventoryTask) 'Canceled shelf job poisoned future updates'
Assert ($script:desktopControls.ShelfMessage.Text -eq 'Copy canceled') 'Canceled copy did not resolve'
# A valid next feed can still be consumed after cancellation without changing state policy.
$script:seen=0;function Set-PetFeedSnapshot($tasks,$time,$open){$script:seen++}
$next=[Threading.Tasks.TaskCompletionSource[object[]]]::new();$next.SetResult([object[]]@([pscustomobject]@{State='idle'}));$script:feedPollTask=$next.Task
Sync-OfficialTaskFeed $now
Assert ($script:seen -eq 1 -and -not $script:feedPollTask) 'Feed did not recover after cancellation'
'PASS: canceled feed, permission poll, shelf inventory and file copy drain safely; next successful feed recovers.'
