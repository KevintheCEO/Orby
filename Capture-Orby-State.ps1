$ErrorActionPreference='Stop'
$dir=Join-Path $env:LOCALAPPDATA 'Orby'
[void][IO.Directory]::CreateDirectory($dir)
$output=Join-Path $dir 'orby-state-capture.txt'
@('Orby v2.9 state capture', ('Captured: ' + [datetime]::UtcNow.ToString('o')), 'Recent parser and state records:') | Set-Content $output -Encoding UTF8
$log=Join-Path $dir 'orby.log'
if (Test-Path -LiteralPath $log) { Get-Content -LiteralPath $log -Tail 4000 | Where-Object {$_ -match 'EVENT |PET FEED |LOG |warning|FATAL|starting|STATE =>|DISPLAY |RENDER |MEDIA ART |FILE DROP|FILE HANDOFF'} | Add-Content $output -Encoding UTF8 }
Write-Host "Saved: $output"
