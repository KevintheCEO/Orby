param([string]$InstalledRoot='',[string]$ReportPath='')
$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent
if(-not $InstalledRoot){$InstalledRoot=Join-Path $env:USERPROFILE 'Documents/Codex/Orby'}
if(-not $ReportPath){$ReportPath=Join-Path (Split-Path $root -Parent) 'outputs/iPhone-connection-check.json'}
Add-Type -Path (Join-Path $InstalledRoot 'Phone-Link.cs') -ReferencedAssemblies System.Net.Http,System.Web.Extensions,System.Security
$private=Join-Path $root '.desktop-data';$state=Get-Content -LiteralPath (Join-Path $private 'running.json') -Raw|ConvertFrom-Json
$pc=[OrbyPhoneClient]::Load((Join-Path $private 'pc.dpapi'))|ConvertFrom-Json
$config=[OrbyPhoneClient]::Load((Join-Path $env:LOCALAPPDATA 'Orby/phone-link.dpapi'))|ConvertFrom-Json
if(-not $config.Enabled -or $config.Origin -cne $state.Origin){throw 'The active Windows phone connection is not ready.'}
$client=[OrbyPhoneClient]::new($state.Origin,$pc.token,$false)
function Request([string]$Method,[string]$Path,$Body){$task=$client.Request($Method,$Path,$(if($null -ne $Body){$Body|ConvertTo-Json -Compress}else{$null}));$task.Wait();$task.Result|ConvertFrom-Json}
try{
 $check=Request 'POST' '/desktop/connection-check' @{}
 Write-Output 'Ready: refresh Safari on your paired iPhone, choose Deny test, and confirm the passkey prompt. No real action can run from this test.'
 $expected=[OrbyPhoneClient]::Hash("Orby connection test only.`n`nDeny this test to check the phone passkey and Windows signature verification. No command will run. No app, internet, file or computer access will be granted or changed.")
 $watch=[Diagnostics.Stopwatch]::StartNew();$finished=$false
 while($watch.Elapsed.TotalSeconds -lt 115){
  Start-Sleep -Seconds 1;$reply=Request 'GET' ('/desktop/connection-check/'+$check.id) $null
  if($reply.status -ne 'decided'){continue}
  $d=$reply.signed;$key=$config.Trusted.PSObject.Properties[[string]$d.deviceId].Value
  $valid=$key -and $d.id -ceq $check.id -and $d.decision -ceq 'deny' -and $d.revision -ceq $expected -and $reply.revision -ceq $expected -and [long]$d.expiresAt -eq [long]$check.expiresAt -and [long]$d.expiresAt -gt [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  if($valid){$valid=[OrbyPhoneClient]::VerifyWeb([string]$key,[string]$d.deviceId,[string]$d.id,[string]$d.revision,[string]$d.decision,[string]$d.nonce,[long]$d.expiresAt,[string]$d.signature,[string]$config.Origin,[string]$d.clientDataJSON,[string]$d.authenticatorData)}
  [void](Request 'POST' ('/desktop/connection-check/'+$check.id+'/ack') @{result=$(if($valid){'verified'}else{'failed'})})
  if(-not $valid){throw 'Windows could not verify the test against its pinned phone key.'}
  [IO.Directory]::CreateDirectory((Split-Path $ReportPath -Parent))|Out-Null
  [ordered]@{CheckedAt=[datetime]::UtcNow.ToString('o');Result='passed';PhonePasskeySignature=$true;UserVerificationRequired=$true;WindowsPinnedKeyVerification=$true;ExactTestDenial=$true;WindowsAcknowledgement=$true;RealPermissionExecuted=$false;AccessGranted=$false}|ConvertTo-Json|Set-Content -LiteralPath $ReportPath -Encoding UTF8
  Write-Output 'PASS: the paired phone signed the test denial, Windows independently verified its pinned key, exact decision, origin, user verification and expiry, then acknowledged it. No real permission or command was executed.'
  $finished=$true;break
 }
 if(-not $finished){throw 'Phone test expired without a verified reply. No access was granted.'}
}finally{$client.Dispose()}
