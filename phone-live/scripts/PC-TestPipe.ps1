param([string]$Helper,[string]$PrivateDirectory)
$ErrorActionPreference='Stop'
Add-Type -Path $Helper -ReferencedAssemblies System.Net.Http,System.Web.Extensions,System.Security
$pc=[OrbyPhoneClient]::Load((Join-Path $PrivateDirectory 'pc.dpapi'))|ConvertFrom-Json
$state=Get-Content -LiteralPath (Join-Path $PrivateDirectory 'running.json') -Raw|ConvertFrom-Json
$client=[OrbyPhoneClient]::new($state.Origin,$pc.token,$false)
try{while($line=[Console]::ReadLine()){try{$b=$line|ConvertFrom-Json;$task=$client.Request([string]$b.method,[string]$b.path,$(if($null -ne $b.body){$b.body|ConvertTo-Json -Depth 8 -Compress}else{$null}));$task.Wait();[Console]::WriteLine($task.Result)}catch{[Console]::WriteLine((@{pipeError=$_.Exception.GetBaseException().Message}|ConvertTo-Json -Compress))}}}finally{$client.Dispose()}
