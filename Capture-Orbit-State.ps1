$ErrorActionPreference='Stop'
$dir=Join-Path $env:LOCALAPPDATA 'OrbitNotch'
[void][IO.Directory]::CreateDirectory($dir)
$output=Join-Path $dir 'orbit-state-capture.txt'
@('Orbit v1.2 state capture', ('Captured: ' + [datetime]::UtcNow.ToString('o')), 'Recent parser and state records:') | Set-Content $output -Encoding UTF8
$log=Join-Path $dir 'orbit.log'
if (Test-Path -LiteralPath $log) { Get-Content -LiteralPath $log -Tail 4000 | Where-Object {$_ -match 'EVENT |PET FEED |LOG |warning|FATAL|starting|STATE =>'} | Add-Content $output -Encoding UTF8 }
Write-Host "Saved: $output"
