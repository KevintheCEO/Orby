param([string]$Fixture,[string]$SourceRoot)
$ErrorActionPreference='Stop'
Add-Type -Path (Join-Path $SourceRoot 'Phone-Link.cs') -ReferencedAssemblies System.Net.Http,System.Web.Extensions,System.Security
Add-Type -TypeDefinition @'
using System.Threading.Tasks;
public class PhoneTestReply {public bool Resolved=true;public bool Submitted=true;}
public static class OrbyApprovalWorker {public static int Calls;public static string LastStop="";public static Task<PhoneTestReply> Stop(string id,string project){Calls++;LastStop=project;return Task.FromResult(new PhoneTestReply());}public static string LastAnswerId="";public static int LastChoice=-1;public static string LastReply="";public static Task<PhoneTestReply> Answer(string id,int choice){Calls++;LastAnswerId=id;LastChoice=choice;return Task.FromResult(new PhoneTestReply());}public static Task<PhoneTestReply> Reply(string id,string text){Calls++;LastReply=text;return Task.FromResult(new PhoneTestReply());} public static Task<PhoneTestReply> Respond(string id,bool allow){Calls++;return Task.FromResult(new PhoneTestReply());}}
'@
$f=Get-Content -LiteralPath $Fixture -Raw|ConvertFrom-Json
function Assert($condition,[string]$reason){if(-not $condition){throw $reason};$script:count++}
Assert ([OrbyPhoneClient]::Fingerprint($f.key) -ceq $f.fingerprint) 'Relay fingerprint differs from Windows raw-key fingerprint'
$argsVerify=@($f.key,$f.deviceId,$f.requestId,$f.revision,'allow',$f.nonce,[long]$f.expiresAt,$f.signature)
Assert ([OrbyPhoneClient]::Verify.Invoke($argsVerify)) 'Node to Windows P256 signature did not verify'
$webSignature=[Convert]::ToBase64String([Convert]::FromBase64String($f.web.signature.Replace('-','+').Replace('_','/').PadRight($f.web.signature.Length+(4-$f.web.signature.Length%4)%4,'=')))
$argsWeb=@($f.webKey,$f.deviceId,$f.requestId,$f.revision,'allow',$f.nonce,[long]$f.expiresAt,$webSignature,$f.webOrigin,$f.web.clientDataJSON,$f.web.authenticatorData)
Assert ([OrbyPhoneClient]::VerifyWeb.Invoke($argsWeb)) 'WebAuthn signature did not verify on Windows'
$argsWeb[4]='deny';Assert (-not [OrbyPhoneClient]::VerifyWeb.Invoke($argsWeb)) 'WebAuthn approved a changed decision';$argsWeb[4]='allow'
$argsWeb[8]='https://other.example.test';Assert (-not [OrbyPhoneClient]::VerifyWeb.Invoke($argsWeb)) 'WebAuthn accepted another origin';$argsWeb[8]=$f.webOrigin
foreach($bad in @($f.webNoUV,$f.webCrossOrigin)){$argsWeb[9]=$bad.clientDataJSON;$argsWeb[10]=$bad.authenticatorData;$s=$bad.signature.Replace('-','+').Replace('_','/');$argsWeb[7]=[Convert]::ToBase64String([Convert]::FromBase64String($s.PadRight($s.Length+(4-$s.Length%4)%4,'=')));Assert (-not [OrbyPhoneClient]::VerifyWeb.Invoke($argsWeb)) 'Unsafe WebAuthn context verified'}
$argsWeb[7]=$webSignature;$argsWeb[9]=$f.web.clientDataJSON;$argsWeb[10]=$f.web.authenticatorData
$argsVerify[4]='deny';Assert (-not [OrbyPhoneClient]::Verify.Invoke($argsVerify)) 'Changed decision verified'
$argsVerify[4]='allow';$argsVerify[2]=[guid]::NewGuid().ToString();Assert (-not [OrbyPhoneClient]::Verify.Invoke($argsVerify)) 'Changed request verified'
$protected=Join-Path (Split-Path $Fixture) 'test.dpapi';[OrbyPhoneClient]::Save($protected,'{"test":"synthetic-value"}')
Assert ([OrbyPhoneClient]::Load($protected) -ceq '{"test":"synthetic-value"}') 'DPAPI round trip failed'
Assert (-not ([Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($protected))).Contains('synthetic-value')) 'Protected credential is plaintext'
$rejected=$false;try{$client=[OrbyPhoneClient]::new('http://example.com','x'*43,$false)}catch{$rejected=$true};Assert $rejected 'Plain HTTP remote address accepted'
$rejected=$false;try{$client=[OrbyPhoneClient]::new('https://example.com/path','x'*43,$false)}catch{$rejected=$true};Assert $rejected 'Non-root relay address accepted'
$tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $SourceRoot 'Phone-Link.ps1'),[ref]$tokens,[ref]$errors)
Assert ($errors.Count -eq 0) 'Windows phone module did not parse'
foreach($name in @('Get-OrbyPhoneReviewText','Test-OrbyPhoneHandoff','Test-OrbyPhoneHandoffDelivered','Get-OrbyPhoneReviewWaiting','Confirm-OrbyPhoneHandoffResponse','Write-OrbyPhoneHandoffStatus','Get-OrbyPhoneRequestBinding','Get-OrbyPhoneActiveTaskToken','Get-OrbyPhoneStopRequest','Get-OrbyPhoneRequest','Invoke-OrbyPhoneDecision','Invoke-OrbyPhoneTick','Read-OrbyPhoneConfigChange')){$node=$ast.FindAll({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst]},$true)|Where-Object Name -eq $name|Select-Object -First 1;. ([scriptblock]::Create($node.Extent.Text))}
$clockAst=[Management.Automation.Language.Parser]::ParseFile((Join-Path $SourceRoot 'Approval-Bridge.ps1'),[ref]$tokens,[ref]$errors)
$clockNode=$clockAst.FindAll({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst]},$true)|Where-Object Name -eq 'Get-OrbyApprovalClockKey'|Select-Object -First 1;. ([scriptblock]::Create($clockNode.Extent.Text))
$script:phoneNoNetwork=$true
function Update-OrbyApprovalView {}
$script:phoneConfig=@{Enabled=$true;Approvals=$true;Trusted=@{}};$script:phoneConfig.Trusted[$f.deviceId]=$f.key
$script:approvalRequest=[pscustomobject]@{Available=$true;CanAnswer=$true;Kind='permission';Id='native-fixture';Title='Test permission';Detail='Harmless fixture only'}
$script:approvalRequestAt=[datetime]::UtcNow;$script:phoneRequestStarted=[datetime]::UtcNow;$script:phoneConsumed=@{}
$script:phoneLocalRequest=@{id=$f.requestId;nativeId='native-fixture';provider='ChatGPT';reviewText=$f.review;revision=$f.revision}
$d=[pscustomobject]@{id=$f.requestId;nativeId='native-fixture';revision=$f.revision;deviceId=$f.deviceId;decision='allow';nonce=$f.nonce;expiresAt=$f.expiresAt;signature=$f.signature}
$script:approvalRequest.Detail='Changed after phone review';Invoke-OrbyPhoneDecision $d;Assert ([OrbyApprovalWorker]::Calls -eq 0) 'Changed prompt was clicked'
$script:approvalRequest.Detail='Harmless fixture only';$script:approvalRequestAt=[datetime]::UtcNow.AddSeconds(-9);Invoke-OrbyPhoneDecision $d;Assert ([OrbyApprovalWorker]::Calls -eq 0) 'Old UI snapshot was clicked'
$script:approvalRequestAt=[datetime]::UtcNow;$script:phoneConfig.Approvals=$false;Invoke-OrbyPhoneDecision $d;Assert ([OrbyApprovalWorker]::Calls -eq 0) 'Disabled approvals clicked'
$script:phoneConfig.Approvals=$true;$script:phoneConfig.Trusted.Clear();Invoke-OrbyPhoneDecision $d;Assert ([OrbyApprovalWorker]::Calls -eq 0) 'Untrusted key clicked'
$script:phoneConfig.Trusted[$f.deviceId]=$f.key;$script:phoneRequestStarted=[datetime]::UtcNow.AddSeconds(-121);Invoke-OrbyPhoneDecision $d;Assert ([OrbyApprovalWorker]::Calls -eq 0) 'Expired local request was clicked'
$script:phoneRequestStarted=[datetime]::UtcNow;Invoke-OrbyPhoneDecision $d;Assert ([OrbyApprovalWorker]::Calls -eq 1) 'Current exact signed fixture did not reach responder'
Invoke-OrbyPhoneDecision $d;Assert ([OrbyApprovalWorker]::Calls -eq 1) 'Decision clicked twice'
Assert ((Get-OrbyPhoneRequest).id -ceq $f.requestId) 'In-flight native response lost request binding'
$script:approvalReplyTask=$null;$script:phoneSubmission=$null;$script:phoneConsumed=@{};$script:phoneConfig.Origin=$f.webOrigin;$script:phoneConfig.Trusted[$f.deviceId]=$f.webKey
$d|Add-Member NoteProperty method 'webauthn';$d|Add-Member NoteProperty clientDataJSON $f.web.clientDataJSON;$d|Add-Member NoteProperty authenticatorData $f.web.authenticatorData;$d.signature=$webSignature
Invoke-OrbyPhoneDecision $d;Assert ([OrbyApprovalWorker]::Calls -eq 2) 'WebAuthn request did not reach exact native responder'
Invoke-OrbyPhoneDecision $d;Assert ([OrbyApprovalWorker]::Calls -eq 2) 'WebAuthn response clicked twice'
# Questions wait five minutes, preserve exact choices and bind dictated text.
$script:approvalReplyTask=$null;$script:phoneSubmission=$null;$script:phoneConsumed=@{};$script:approvalAnswered=''
$script:approvalRequest=[pscustomobject]@{Available=$true;CanAnswer=$true;CanReply=$true;Kind='question';Id='native-question';Title='Question fixture';Detail='Choose an answer or write your response, then send it.';Choices=@('First','Second')}
$script:phoneConnectedAt=[datetime]::UtcNow;$script:phoneReadyCount=1;$script:approvalRequestAt=[datetime]::UtcNow;$script:approvalFirstSeen=[datetime]::UtcNow.AddSeconds(-299)
Assert (-not (Get-OrbyPhoneRequest)) 'Question handed off before five minutes'
$script:approvalRequest|Add-Member NoteProperty Target 'fixture-window';$script:orbyActiveTasks=@();$script:approvalClockEpisode='native-question';$script:approvalClockKey=Get-OrbyApprovalClockKey $script:approvalRequest
$script:approvalFirstSeen=[datetime]::UtcNow.AddSeconds(-301);$hand=Get-OrbyPhoneRequest
Assert ($hand.kind -eq 'question' -and $hand.handoff -and $hand.choices.Count -eq 2 -and $hand.reviewText -ceq $f.questionReview) 'Question handoff lost its exact choices'
Assert (-not (Test-OrbyPhoneHandoffDelivered)) 'PC question hid before the relay accepted it'
Confirm-OrbyPhoneHandoffResponse ([pscustomobject]@{requests=@([pscustomobject]@{id=$hand.id;status='pending'})})
Assert (Test-OrbyPhoneHandoffDelivered) 'Relay acceptance did not complete the visible handoff'
$script:phoneHandoffAckRevision='changed';Assert (-not (Test-OrbyPhoneHandoffDelivered)) 'Changed review inherited the prior handoff acknowledgement'
$script:phoneHandoffAckRevision=$hand.revision
Assert (Get-OrbyPhoneReviewWaiting) 'Pending PC question was not marked as waiting'

$script:phoneLocalRequest.id=$f.questionId;$script:phoneRequestStarted=[datetime]::UtcNow
function QuestionDecision($b){$signature=$b.proof.signature.Replace('-','+').Replace('_','/');[pscustomobject]@{id=$f.questionId;nativeId='native-question';revision=$f.questionRevision;deviceId=$f.deviceId;decision=$b.decision;answer=$b.answer;nonce=$b.nonce;expiresAt=$b.expiresAt;method='webauthn';signature=[Convert]::ToBase64String([Convert]::FromBase64String($signature.PadRight($signature.Length+(4-$signature.Length%4)%4,'=')));clientDataJSON=$b.proof.clientDataJSON;authenticatorData=$b.proof.authenticatorData}}
$qdecision=QuestionDecision $f.questionChoice
$script:approvalRequest.Target='another-window';Invoke-OrbyPhoneDecision $qdecision;Assert ([OrbyApprovalWorker]::Calls -eq 2) 'A matching prompt in another window accepted an old phone review';$script:approvalRequest.Target='fixture-window'
$script:orbyActiveTasks=@([pscustomobject]@{Id='other-task';Turn='new-turn';Provider='chatgpt'});Invoke-OrbyPhoneDecision $qdecision;Assert ([OrbyApprovalWorker]::Calls -eq 2) 'A newer journal turn accepted an old phone review';$script:orbyActiveTasks=@()
$stableId=$script:phoneLocalRequest.id;$script:approvalRequest.Id='remounted-native-question'
Assert ((Get-OrbyPhoneRequest).id -ceq $stableId) 'An unchanged question remount replaced the phone review'

$script:approvalRequest.Choices[1]='Changed choice';Invoke-OrbyPhoneDecision $qdecision;Assert ([OrbyApprovalWorker]::Calls -eq 2) 'Changed choice list accepted an old phone response'
$script:approvalRequest.Choices[1]='Second';Invoke-OrbyPhoneDecision $qdecision;Assert ([OrbyApprovalWorker]::Calls -eq 3 -and [OrbyApprovalWorker]::LastChoice -eq 1) 'Exact phone choice did not reach native Answer'
Assert ([OrbyApprovalWorker]::LastAnswerId -ceq 'remounted-native-question') 'Phone answer used a stale accessibility control identity'
$script:approvalReplyTask=$null;$script:phoneSubmission=$null;$script:phoneConsumed=@{};$qdecision=QuestionDecision $f.questionReply;$qdecision.answer='Changed after signing'
Invoke-OrbyPhoneDecision $qdecision;Assert ([OrbyApprovalWorker]::Calls -eq 3) 'Changed dictated response was accepted'
$qdecision.answer=$f.questionAnswer;Invoke-OrbyPhoneDecision $qdecision;Assert ([OrbyApprovalWorker]::Calls -eq 4 -and [OrbyApprovalWorker]::LastReply -ceq $f.questionAnswer) 'Exact dictated response did not reach native Reply'
$script:approvalReplyTask=$null;$script:phoneSubmission=$null;$script:phoneConsumed=@{};$script:phoneStopAt=[datetime]::UtcNow
$script:orbyActiveTasks=@([pscustomobject]@{Id='fixture-task';Turn='fixture-turn';Started='fixed-start';State='working';Provider='chatgpt';Title='Fixture project'})
$script:phoneStopRequest=[pscustomobject]@{TaskToken=(Get-OrbyPhoneActiveTaskToken);NativeStopId='fixture-ui-stop';Id='native-stop';Kind='stop';Target='Fixture project';Available=$true;CanAnswer=$true;Title='Stop current task: Fixture project';Detail='Stop only this task.'}
$script:phoneLocalRequest=@{id=$f.stopId;nativeId='native-stop';kind='stop';revision=$f.stopRevision};$script:phoneRequestStarted=[datetime]::UtcNow
$stopDecision=QuestionDecision $f.stopDecision;$stopDecision.id=$f.stopId;$stopDecision.nativeId='native-stop';$stopDecision.revision=$f.stopRevision
$script:orbyActiveTasks[0].Turn='new-turn';Invoke-OrbyPhoneDecision $stopDecision;Assert ([OrbyApprovalWorker]::Calls -eq 4) 'Old Stop response targeted a newer turn';$script:orbyActiveTasks[0].Turn='fixture-turn'
Invoke-OrbyPhoneDecision $stopDecision;Assert ([OrbyApprovalWorker]::Calls -eq 5 -and [OrbyApprovalWorker]::LastStop -ceq 'Fixture project') 'Signed Stop did not target the exact current project'
Invoke-OrbyPhoneDecision $stopDecision;Assert ([OrbyApprovalWorker]::Calls -eq 5) 'Stop was replayed'
$script:approvalAnswered=$script:approvalRequest.Id;$script:phoneSubmission=$null;Assert (-not (Get-OrbyPhoneRequest)) 'An answered question was offered again'
# A new acknowledgement arriving while an older HTTP batch is in flight must survive.
$script:phoneSubmission=$null;$script:phoneConfig.Enabled=$true;$script:phoneClient=$null
$script:phoneAcks=@(@{id='old';result='resolved'},@{id='new';result='resolved'});$script:phoneSentAcks=@(@{id='old';result='resolved'})
$script:phoneExchange=[Threading.Tasks.Task]::FromResult('{"decisions":[],"phoneCount":1}')
function Reset-OrbyPhoneClient {$script:phoneClient=[pscustomobject]@{};$script:phoneClient|Add-Member ScriptMethod Exchange {param($instance,$body)$script:testPayload=$body;return [Threading.Tasks.Task]::FromResult('{}')}}
function Get-OrbyPhoneTaskSnapshot {return @()}
Invoke-OrbyPhoneTick
Assert ($script:phoneAcks.Count -eq 1 -and $script:phoneAcks[0].id -ceq 'new') 'Unsent acknowledgement was erased'
$script:phoneConfig.Enabled=$false;$script:phoneClient=$null;$script:testPayload='unchanged';Invoke-OrbyPhoneTick
Assert ($script:testPayload -ceq 'unchanged') 'Disabled link started an exchange'
$script:phoneConfigPath=Join-Path (Split-Path $Fixture) 'reload.dpapi';$script:phoneConfigStamp=[datetime]::MinValue
[OrbyPhoneClient]::Save($script:phoneConfigPath,'{"Enabled":false,"Approvals":false,"Origin":"https://fresh.example.test","Token":"","Trusted":{}}')
$before=$script:phoneConfig.Origin;Read-OrbyPhoneConfigChange;Assert ($script:phoneConfig.Origin -ceq $before) 'No-network mode reloaded connection config'
$script:phoneNoNetwork=$false;Read-OrbyPhoneConfigChange;Assert ($script:phoneConfig.Origin -ceq 'https://fresh.example.test') 'Updated connection address was not reloaded'
[IO.File]::WriteAllText($script:phoneConfigPath,'not-protected');[IO.File]::SetLastWriteTimeUtc($script:phoneConfigPath,[datetime]::UtcNow.AddSeconds(1));Read-OrbyPhoneConfigChange;Assert (-not $script:phoneConfig.Enabled) 'Corrupt connection config did not fail closed'
# Local troubleshooting output must explain a blocked handoff without copying request content.
$script:logDir=Split-Path $Fixture;$script:phoneDiagnosticAt=$null
$script:phoneConfig=@{Enabled=$true;Approvals=$true;Trusted=@{fixture='key'}}
$script:phoneReadyCount=1;$script:phoneConnectedAt=[datetime]::UtcNow
$script:approvalRequest=[pscustomobject]@{Available=$false;CanAnswer=$false;Kind='question';Status='Permission controls are not exposed by this window';Title='PRIVATE-PROMPT-SENTINEL';Detail='PRIVATE-ANSWER-SENTINEL'}
Write-OrbyPhoneHandoffStatus
$diagnostic=Get-Content -LiteralPath (Join-Path $script:logDir 'phone-handoff-status.json') -Raw
Assert (($diagnostic|ConvertFrom-Json).reason -ceq 'waiting-for-accessible-question') 'Blocked handoff diagnostic lost its reason'
Assert ($diagnostic -notmatch 'PRIVATE-(PROMPT|ANSWER)-SENTINEL') 'Handoff diagnostic copied private request content'
"PASS: $script:count Windows checks: signature interoperability, protected credentials, exact prompt binding, replay, expiry/freshness, acknowledgement batching and disabled connection. No real permission was clicked."
