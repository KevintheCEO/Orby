param([string]$OutputPath="",[switch]$NoOpen)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName UIAutomationClient,UIAutomationTypes
. (Join-Path $PSScriptRoot 'Chat-Window.ps1')
. (Join-Path $PSScriptRoot 'Chat-Control-Matching.ps1')
$app=Get-Process ChatGPT -ErrorAction SilentlyContinue | Where-Object {$_.MainWindowHandle -ne [IntPtr]::Zero} | Select-Object -First 1
if(-not $app){throw 'Open ChatGPT first'}
$script:chatHwnd=$app.MainWindowHandle
$root=[Windows.Automation.AutomationElement]::FromHandle($script:chatHwnd)
$folder=Join-Path $env:LOCALAPPDATA 'Orby';[void][IO.Directory]::CreateDirectory($folder)
$path=if($OutputPath){$OutputPath}else{Join-Path $folder 'chatgpt-controls.txt'}
Save-OrbyChatControls $root $path
Write-Host ('Saved: '+$path)
if(-not $NoOpen){Start-Process notepad.exe -ArgumentList ('"'+$path+'"')
}
