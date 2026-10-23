param([string]$Fixture,[string]$SourceRoot)
$ErrorActionPreference='Stop'
Add-Type -Path (Join-Path $SourceRoot 'Phone-Link.cs') -ReferencedAssemblies System.Net.Http,System.Web.Extensions,System.Security
Add-Type -TypeDefinition @'
using System.Threading.Tasks;
public class PhoneTestReply {public bool Resolved=true;public bool Submitted=true;}
public static class OrbyApprovalWorker {public static int Calls; public static Task<PhoneTestReply> Respond(string id,bool allow){Calls++;return Task.FromResult(new PhoneTestReply());}}
'@
$f=Get-Content -LiteralPath $Fixture -Raw|ConvertFrom-Json
function Assert($condition,[string]$reason){if(-not $condition){throw $reason};$script:count++}
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
foreach($name in @('Get-OrbyPhoneRequest','Invoke-OrbyPhoneDecision','Invoke-OrbyPhoneTick','Read-OrbyPhoneConfigChange')){$node=$ast.FindAll({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst]},$true)|Where-Object Name -eq $name|Select-Object -First 1;. ([scriptblock]::Create($node.Extent.Text))}
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
"PASS: $script:count Windows checks: signature interoperability, protected credentials, exact prompt binding, replay, expiry/freshness, acknowledgement batching and disabled connection. No real permission was clicked."
