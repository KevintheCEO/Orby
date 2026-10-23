param([string]$Helper,[string]$PrivateDirectory)
$ErrorActionPreference='Stop'
Add-Type -Path $Helper -ReferencedAssemblies System.Net.Http,System.Web.Extensions,System.Security
$pc=[OrbyPhoneClient]::Load((Join-Path $PrivateDirectory 'pc.dpapi'))|ConvertFrom-Json
$state=Get-Content -LiteralPath (Join-Path $PrivateDirectory 'running.json') -Raw|ConvertFrom-Json
$client=[OrbyPhoneClient]::new($state.Origin,$pc.token,$false)
try{while($line=[Console]::ReadLine()){try{$b=$line|ConvertFrom-Json;if($b.operation -eq 'verifyWeb'){$d=$b.decision;$ok=[OrbyPhoneClient]::VerifyWeb([string]$b.publicKey,[string]$d.deviceId,[string]$d.id,[string]$d.revision,[string]$d.decision,[string]$d.nonce,[long]$d.expiresAt,[string]$d.signature,[string]$state.Origin,[string]$d.clientDataJSON,[string]$d.authenticatorData);[Console]::WriteLine((@{verified=$ok}|ConvertTo-Json -Compress));continue};$task=$client.Request([string]$b.method,[string]$b.path,$(if($null -ne $b.body){$b.body|ConvertTo-Json -Depth 8 -Compress}else{$null}));$task.Wait();[Console]::WriteLine($task.Result)}catch{[Console]::WriteLine((@{pipeError=$_.Exception.GetBaseException().Message}|ConvertTo-Json -Compress))}}}finally{$client.Dispose()}
