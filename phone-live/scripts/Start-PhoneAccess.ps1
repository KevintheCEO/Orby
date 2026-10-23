param([int]$Port=4321,[string]$InstalledRoot='')
$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent
$node=(Get-Command node.exe -ErrorAction Stop).Source;$tunnel=(Get-Command cloudflared.exe -ErrorAction Stop).Source
if(-not $InstalledRoot){$candidates=@((Join-Path $env:USERPROFILE 'Documents/Codex/Orby'),(Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Codex/Orby'));$InstalledRoot=$candidates|Where-Object {Test-Path -LiteralPath (Join-Path $_ 'Phone-Link.cs')}|Select-Object -First 1;if(-not $InstalledRoot){throw 'The Orby installation was not found. Pass its folder with -InstalledRoot.'}} 
$helper=Join-Path $InstalledRoot 'Phone-Link.cs';if(-not (Test-Path -LiteralPath $helper)){throw 'Install Orby 10.43 before starting phone access.'}
if(-not (Test-Path -LiteralPath (Join-Path $root 'node_modules/express'))){throw 'Run npm.cmd ci --ignore-scripts inside phone-live once, then start again.'}
$private=Join-Path $root '.desktop-data';[void][IO.Directory]::CreateDirectory($private)
# Only this Windows account and SYSTEM can read local relay keys, logs and state.
$acl=[IO.Directory]::GetAccessControl($private,[Security.AccessControl.AccessControlSections]::Access);$acl.SetAccessRuleProtection($true,$false);foreach($rule in @($acl.Access)){$acl.RemoveAccessRuleSpecific($rule)}
$sid=[Security.Principal.WindowsIdentity]::GetCurrent().User
foreach($identity in @($sid,[Security.Principal.SecurityIdentifier]::new('S-1-5-18'))){$rule=[Security.AccessControl.FileSystemAccessRule]::new($identity,'FullControl','ContainerInherit,ObjectInherit','None','Allow');$acl.AddAccessRule($rule)};[IO.Directory]::SetAccessControl($private,$acl)
$statePath=Join-Path $private 'running.json'
if(Test-Path -LiteralPath $statePath){$old=Get-Content -LiteralPath $statePath -Raw|ConvertFrom-Json;if(Get-Process -Id $old.RelayPid -ErrorAction SilentlyContinue){Write-Output ('Phone relay is already running: '+$old.Origin);Write-Output 'Open Orby Settings > Phone access to create an invitation.';exit 0}}
if(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue){throw 'The phone test port is in use. Stop the previous test before starting again.'}
$tunnelProcess=$null;$relayProcess=$null
try{
 $tunnelLog=Join-Path $private 'tunnel.log';if(Test-Path -LiteralPath $tunnelLog){Remove-Item -LiteralPath $tunnelLog -Force};$tunnelProcess=Start-Process -FilePath $tunnel -ArgumentList @('tunnel','--url',('http://127.0.0.1:'+$Port),'--no-autoupdate','--logfile',('"'+$tunnelLog+'"')) -WindowStyle Hidden -RedirectStandardOutput (Join-Path $private 'tunnel-out.log') -RedirectStandardError (Join-Path $private 'tunnel-error.log') -PassThru
 Write-Output 'Creating your private phone test connection...';$watch=[Diagnostics.Stopwatch]::StartNew();$origin=''
 while($watch.Elapsed.TotalSeconds -lt 45){Start-Sleep -Milliseconds 500;if($tunnelProcess.HasExited){throw 'The tunnel could not start'};if(Test-Path -LiteralPath $tunnelLog){$stream=[IO.File]::Open($tunnelLog,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite);try{$reader=[IO.StreamReader]::new($stream);$content=$reader.ReadToEnd()}finally{$stream.Dispose()};$matches=[regex]::Matches($content,'https://[a-z0-9-]+\.trycloudflare\.com');if($matches.Count){$origin=$matches[$matches.Count-1].Value;break}}}
 if(-not $origin){throw 'No HTTPS test address was received. Try again.'}
 $env:PORT=[string]$Port;$env:NODE_ENV='production';$env:PUBLIC_ORIGIN=$origin;$env:DATA_DIR=$private
 $relayProcess=Start-Process -FilePath $node -ArgumentList ('"'+(Join-Path $root 'relay/main.mjs')+'"') -WindowStyle Hidden -WorkingDirectory $root -RedirectStandardOutput (Join-Path $private 'relay.log') -RedirectStandardError (Join-Path $private 'relay-error.log') -PassThru
 $adminPath=Join-Path $private 'admin.key';$ready=$false
 for($attempt=0;$attempt -lt 30;$attempt++){Start-Sleep -Milliseconds 300;if($relayProcess.HasExited){throw 'The relay could not start. Its private error log has the details.'};try{$health=Invoke-RestMethod -Uri ('http://127.0.0.1:'+$Port+'/health') -TimeoutSec 2;if($health){$ready=$true;break}}catch{}}
 if(-not $ready){throw 'The relay did not become ready'}
 Add-Type -Path $helper -ReferencedAssemblies System.Net.Http,System.Web.Extensions,System.Security
 $configPath=Join-Path $env:LOCALAPPDATA 'Orby/phone-link.dpapi';$existing=[OrbyPhoneClient]::Load($configPath);$saved=if($existing){$existing|ConvertFrom-Json}else{$null}
 $pcPath=Join-Path $private 'pc.dpapi';$pcStored=[OrbyPhoneClient]::Load($pcPath)
 if($pcStored){$pc=$pcStored|ConvertFrom-Json}else{$admin=[IO.File]::ReadAllText($adminPath).Trim();$pc=Invoke-RestMethod -Method Post -Uri ('http://127.0.0.1:'+$Port+'/admin/desktop') -Headers @{Authorization=('Bearer '+$admin)} -ContentType 'application/json' -Body '{"name":"My Orby PC"}';[OrbyPhoneClient]::Save($pcPath,($pc|ConvertTo-Json -Compress))}
 $trust=@{};if($saved -and $saved.Token -ceq $pc.token){foreach($p in $saved.Trusted.PSObject.Properties){$trust[$p.Name]=$p.Value}}
 $config=@{Enabled=$true;Approvals=$false;Origin=$origin;Token=$pc.token;Trusted=$trust}
 [OrbyPhoneClient]::Save($configPath,($config|ConvertTo-Json -Depth 5 -Compress))
 [pscustomobject]@{Origin=$origin;RelayPid=$relayProcess.Id;TunnelPid=$tunnelProcess.Id;RelayExe=$node;TunnelExe=$tunnel;MainScript=(Join-Path $root 'relay/main.mjs');Started=[datetime]::UtcNow.ToString('o')}|ConvertTo-Json|Set-Content -LiteralPath $statePath -Encoding UTF8
 Write-Output ('Phone relay ready: '+$origin);Write-Output 'Open Orby Settings > Phone access > Create invitation / QR code. Orby 10.43 reloads this connection automatically.';Write-Output 'Connect each phone separately and compare its fingerprint on both screens.';Write-Output 'Task sharing is enabled. Remote approvals remain off until you enable them in Phone access.';Write-Output 'This temporary address works away from home while this PC and both helpers stay running. It changes when restarted.'
}catch{if($relayProcess){Stop-Process -Id $relayProcess.Id -ErrorAction SilentlyContinue};if($tunnelProcess){Stop-Process -Id $tunnelProcess.Id -ErrorAction SilentlyContinue};throw}finally{foreach($name in @('PORT','NODE_ENV','PUBLIC_ORIGIN','DATA_DIR')){Remove-Item ('Env:'+$name) -ErrorAction SilentlyContinue}}
