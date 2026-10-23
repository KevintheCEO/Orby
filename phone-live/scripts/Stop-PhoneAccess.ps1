$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent;$statePath=Join-Path $root '.desktop-data/running.json'
if(-not (Test-Path -LiteralPath $statePath)){Write-Output 'No managed phone test is recorded.';exit 0}
$state=Get-Content -LiteralPath $statePath -Raw|ConvertFrom-Json
foreach($pair in @(@($state.RelayPid,$state.RelayExe,$state.MainScript),@($state.TunnelPid,$state.TunnelExe,'tunnel --url'))){$process=Get-CimInstance Win32_Process -Filter ('ProcessId='+[int]$pair[0]) -ErrorAction SilentlyContinue;if($process -and $process.ExecutablePath -eq $pair[1] -and $process.CommandLine.Contains($pair[2])){Stop-Process -Id $process.ProcessId -ErrorAction Stop}}
Remove-Item -LiteralPath $statePath;Write-Output 'The private test relay and tunnel are stopped. Phones cannot send new decisions. Your normal local Orby still works.'
