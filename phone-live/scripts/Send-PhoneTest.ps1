param([ValidateRange(0,15)][int]$DelaySeconds=10,[string]$TestId='',[switch]$Watch,[string]$InstalledRoot='')
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent;$private=Join-Path $root '.desktop-data'
if(-not $InstalledRoot){$InstalledRoot=Join-Path $env:USERPROFILE 'Documents/Codex/Orby'}
Add-Type -Path (Join-Path $InstalledRoot 'Phone-Link.cs') -ReferencedAssemblies System.Net.Http,System.Web.Extensions,System.Security
$configPath=Join-Path $env:LOCALAPPDATA 'Orby/phone-link.dpapi'
function Read-Config {
 $config=[OrbyPhoneClient]::Load($configPath)|ConvertFrom-Json
 $runtime=Get-Content -LiteralPath (Join-Path $private 'running.json') -Raw|ConvertFrom-Json
 if(-not $config.Enabled -or $config.Origin -cne $runtime.Origin){throw 'The saved PC connection does not match the running phone service.'}
 return $config
}
$config=Read-Config
if(-not $TestId){
 $created=Invoke-RestMethod -Method Post -Uri ($config.Origin+'/desktop/phone-test') -Headers @{Authorization=('Bearer '+$config.Token)} -ContentType 'application/json' -Body (@{delaySeconds=$DelaySeconds}|ConvertTo-Json -Compress)
 $created|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $private 'direct-phone-test.json') -Encoding UTF8
 $TestId=[string]$created.id
 Write-Output ('Phone-only test created. Notification: '+$created.notification+'. No PC five-minute delay. No action will run.')
}
if(-not $Watch){return}
$deadline=[datetime]::UtcNow.AddMinutes(10)
while([datetime]::UtcNow -lt $deadline){
 try{
  $config=Read-Config
  $test=Invoke-RestMethod -Method Get -Uri ($config.Origin+'/desktop/phone-test/'+$TestId) -Headers @{Authorization=('Bearer '+$config.Token)}
  if($test.status -eq 'decided' -and $test.signed){
   $d=$test.signed;$trusted=@{};foreach($p in $config.Trusted.PSObject.Properties){$trusted[$p.Name]=[string]$p.Value};$key=$trusted[[string]$d.deviceId]
   $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
   $verified=$key -and $d.id -ceq $TestId -and $d.revision -ceq $test.revision -and [string]$d.decision -match '^choice:[0-4]$' -and [long]$d.expiresAt -gt $now -and $d.method -ceq 'webauthn'
   if($verified){$verified=[OrbyPhoneClient]::VerifyWeb($key,[string]$d.deviceId,[string]$d.id,[string]$d.revision,[string]$d.decision,[string]$d.nonce,[long]$d.expiresAt,[string]$d.signature,[string]$config.Origin,[string]$d.clientDataJSON,[string]$d.authenticatorData)}
   $result=if($verified){'verified'}else{'failed'}
   [void](Invoke-RestMethod -Method Post -Uri ($config.Origin+'/desktop/phone-test/'+$TestId+'/ack') -Headers @{Authorization=('Bearer '+$config.Token)} -ContentType 'application/json' -Body (@{result=$result}|ConvertTo-Json -Compress))
   $receipt=[ordered]@{CheckedAt=[datetime]::UtcNow.ToString('o');SignatureVerifiedWithWindowsPinnedKey=[bool]$verified;ChoiceIndex=[int]$test.answer;Choice=[string]$test.choices[[int]$test.answer];ActionsExecuted=0;NormalFiveMinuteRuleChanged=$false}
   $receipt|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $private 'direct-phone-test-result.json') -Encoding UTF8
   Write-Output ('Phone test '+$result+'. No action was executed.');return
  }
  if($test.status -in @('verified','failed')){Write-Output ('Phone test already '+$test.status);return}
 }catch{Write-Output 'Phone test is temporarily unavailable; waiting for the current PC connection.'}
 Start-Sleep -Seconds 1
}
Write-Output 'Phone test expired without a verified response. No action was executed.'
