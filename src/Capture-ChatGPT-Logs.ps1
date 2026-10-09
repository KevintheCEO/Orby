param()
$ErrorActionPreference = 'SilentlyContinue'
$outDir = Join-Path $env:LOCALAPPDATA 'OrbitNotch'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$outFile = Join-Path $outDir 'chatgpt-log-capture.txt'
$roots = New-Object 'System.Collections.Generic.List[string]'
function AddRoot([string]$p) {
    if (-not [string]::IsNullOrWhiteSpace($p) -and (Test-Path -LiteralPath $p)) {
        $full = [IO.Path]::GetFullPath($p)
        if (-not $roots.Contains($full)) { $roots.Add($full) }
    }
}
if ($env:LOCALAPPDATA) {
    AddRoot (Join-Path $env:LOCALAPPDATA 'Packages\OpenAI.Codex_2p2nqsd0c76g0\LocalCache\Local\Codex\Logs')
    AddRoot (Join-Path $env:LOCALAPPDATA 'OpenAI\Codex\Logs')
    AddRoot (Join-Path $env:LOCALAPPDATA 'OpenAI\ChatGPT\Logs')
    $packages = Join-Path $env:LOCALAPPDATA 'Packages'
    Get-ChildItem -LiteralPath $packages -Directory | Where-Object { $_.Name -match '(?i)openai|chatgpt|codex' } | ForEach-Object {
        Get-ChildItem -LiteralPath $_.FullName -Directory -Recurse -Filter Logs | ForEach-Object { AddRoot $_.FullName }
    }
}
if ($env:APPDATA) {
    Get-ChildItem -LiteralPath (Join-Path $env:APPDATA 'OpenAI') -Directory -Recurse -Filter Logs | ForEach-Object { AddRoot $_.FullName }
}
$files = @()
foreach ($r in $roots) {
    $files += Get-ChildItem -LiteralPath $r -File -Recurse -Filter *.log
}
$files = $files | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 8
"Orbit ChatGPT log capture - $(Get-Date -Format o)" | Set-Content -Path $outFile -Encoding UTF8
"Roots:" | Add-Content $outFile
$roots | ForEach-Object { "  $_" | Add-Content $outFile }
"" | Add-Content $outFile
foreach ($f in $files) {
    "===== $($f.FullName) | $($f.LastWriteTime) | $($f.Length) bytes =====" | Add-Content $outFile
    Get-Content -LiteralPath $f.FullName -Tail 350 | Where-Object {
        $_ -match '(?i)turn/start|turn/started|turn-complete|turnstatus|latestturnstatus|interrupted|cancelled|canceled|paused|kind=question|request_user_input|thread_stream_view_activity_changed|reasoning summary|structured turn failed|desktop-notifications|web_search|search_query|apply_patch|exec_command'
    } | Select-Object -Last 140 | Add-Content $outFile
    "" | Add-Content $outFile
}
Write-Host "Saved: $outFile"
Start-Process notepad.exe $outFile
