$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,UIAutomationClient,UIAutomationTypes
Add-Type -Path @((Join-Path $PSScriptRoot 'Approval-Worker.cs'),(Join-Path $PSScriptRoot 'Test-Input-Harness.cs')) -ReferencedAssemblies @('UIAutomationClient','UIAutomationTypes','WindowsBase','PresentationCore','PresentationFramework','System.Xaml','System.Core')
[OrbyInputHarness]::Run()
. (Join-Path $PSScriptRoot 'UI-Input-Classification.ps1')
function Set-ChatLogState($State,$Message,$Source){$script:chatLogState=$State;$script:chatLogMessage=$Message}
$snapshot=[pscustomobject]@{Working=$true;InputRequest=''}
$script:chatLogState='working'
Apply-OrbyBlockingInput $snapshot ([OrbyApprovalRequest]@{Available=$true;Kind='question';Title='Choose an answer'}) $true
if($snapshot.Working -or $snapshot.InputRequest -ne 'Choose an answer' -or $script:chatLogState -ne 'attention'){throw 'Visible question lost to background spinner'}
$snapshot.Working=$true;$snapshot.InputRequest='';$script:chatLogState='working'
Apply-OrbyBlockingInput $snapshot ([OrbyApprovalRequest]@{Available=$true;Kind='question';Title='Old question'}) $false
if(-not $snapshot.Working -or $script:chatLogState -ne 'working'){throw 'Stale request overrode current work'}
'PASS: current question outranks working feed; stale request does not'
