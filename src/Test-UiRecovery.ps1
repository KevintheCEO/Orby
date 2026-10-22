$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,System.Windows.Forms
. (Join-Path $PSScriptRoot 'UI-Recovery.ps1')
$script:lines=[Collections.Generic.List[string]]::new();function Write-OrbitLog($text){$script:lines.Add($text)}
function Assert($ok,$why){if(-not $ok){throw $why};$script:checks++}
$script:compactMenuControls=@{MenuFooter=[Windows.Controls.TextBlock]::new()}
$script:orbyShared=@{Stop=$false}
Invoke-OrbySafeAction {throw 'test action failed'} 'Button test'
Assert ($script:lines[0] -like 'UI RECOVERED Button test:*') 'Recoverable error was not logged'
Assert ($script:compactMenuControls.MenuFooter.Text -like 'That action failed*') 'Non-modal recovery notice missing'
$continued=$false;Invoke-OrbySafeAction {$script:continued=$true};Assert $continued 'Action routing stopped after an error'
Assert (-not (Test-OrbyRecoverableUiError ([OutOfMemoryException]::new()))) 'Fatal memory error treated as recoverable'
Assert (-not (Test-OrbyRecoverableUiError ([AccessViolationException]::new()))) 'Fatal memory access error treated as recoverable'
$script:usageTimer=[Windows.Threading.DispatcherTimer]::new();$script:usageTimer.Start()
foreach($i in 1..3){Invoke-OrbySafeAction {throw 'repeated error'} 'Repeated test'}
Assert (-not $script:usageTimer.IsEnabled) 'Repeated errors did not pause background polling'
$worker=[powershell]::Create();$space=[runspacefactory]::CreateRunspace();$space.Open();$worker.Runspace=$space
[void]$worker.AddScript('[Threading.Thread]::Sleep(1800)');$handle=$worker.BeginInvoke();Start-Sleep -Milliseconds 100
$watch=[Diagnostics.Stopwatch]::StartNew();[OrbyBackgroundShutdown]::Stop($worker,$space);$watch.Stop()
Assert ($watch.ElapsedMilliseconds -lt 400) 'Worker shutdown blocked the caller'
$window=[Windows.Window]::new();$window.Show()
Request-OrbyQuit
Assert ($script:orbyShared.Stop -and $script:orbyClosing -and -not $window.IsVisible) 'Quit failed after errors'
Request-OrbyQuit
Assert $script:orbyClosing 'Repeated Quit was not safe'
"PASS: $script:checks recovery checks: non-modal errors, continued actions, fatal-error filtering, repeated-error pause, non-blocking worker cleanup and Quit"
