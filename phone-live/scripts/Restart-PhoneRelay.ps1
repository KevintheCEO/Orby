$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent;$private=Join-Path $root '.desktop-data';$statePath=Join-Path $private 'running.json'
$state=Get-Content -LiteralPath $statePath -Raw|ConvertFrom-Json
$owned=Get-CimInstance Win32_Process -Filter ('ProcessId='+[int]$state.RelayPid)
if(-not $owned -or $owned.ExecutablePath -ne $state.RelayExe -or -not $owned.CommandLine.Contains($state.MainScript)){throw 'Recorded relay identity could not be verified; nothing was stopped.'}
$listener=Get-NetTCPConnection -OwningProcess $owned.ProcessId -State Listen|Where-Object {$_.LocalAddress -eq '127.0.0.1'}|Select-Object -First 1
if(-not $listener){throw 'The current relay listener was not found.'}
try{
 $env:PORT=[string]$listener.LocalPort;$env:NODE_ENV='production';$env:PUBLIC_ORIGIN=$state.Origin;$env:DATA_DIR=$private
 Stop-Process -Id $owned.ProcessId -ErrorAction Stop;Wait-Process -Id $owned.ProcessId -ErrorAction SilentlyContinue
 $relay=Start-Process -FilePath $state.RelayExe -ArgumentList ('"'+$state.MainScript+'"') -WindowStyle Hidden -WorkingDirectory $root -RedirectStandardOutput (Join-Path $private 'relay.log') -RedirectStandardError (Join-Path $private 'relay-error.log') -PassThru
 $state.RelayPid=$relay.Id;$state|ConvertTo-Json|Set-Content -LiteralPath $statePath -Encoding UTF8
 $ready=$false;for($attempt=0;$attempt -lt 30;$attempt++){Start-Sleep -Milliseconds 200;$relay.Refresh();if($relay.HasExited){throw 'Relay restart failed; private logs contain diagnostics.'};try{$health=Invoke-RestMethod -Uri ('http://127.0.0.1:'+$listener.LocalPort+'/health') -TimeoutSec 2;if($health){$ready=$true;break}}catch{}}
 if(-not $ready){throw 'Relay did not become ready.'}
 'PASS: relay refreshed; existing HTTPS tunnel, phone credentials and Windows connection retained.'
}finally{foreach($name in @('PORT','NODE_ENV','PUBLIC_ORIGIN','DATA_DIR')){Remove-Item ('Env:'+$name) -ErrorAction SilentlyContinue}}
