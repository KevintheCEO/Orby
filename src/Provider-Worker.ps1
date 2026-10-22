param($Shared,[string]$BaseDirectory)
$ErrorActionPreference='Stop'
if(-not ('OrbyProviderReader' -as [type])){Add-Type -Path (Join-Path $BaseDirectory 'Provider-Reader.cs') -ReferencedAssemblies UIAutomationClient,UIAutomationTypes,WindowsBase,System.Core}
if(-not ('OrbyClaudeCode' -as [type])){Add-Type -Path (Join-Path $BaseDirectory 'Claude-Code.cs') -ReferencedAssemblies System.Web.Extensions,System.Core}
while(-not $Shared.Stop){
 try {
  $Shared.ClaudeCodeStatus=[OrbyClaudeCode]::Read([OrbyClaudeCode]::DefaultDirectory)
  $Shared.ClaudeCodeAt=[datetime]::UtcNow
  $Shared.ProviderSnapshots=[OrbyProviderReader]::Read([string]$Shared.Settings.ProviderEnabled)
  $names=@(Get-Process -ErrorAction SilentlyContinue | Select-Object -ExpandProperty ProcessName)
  $Shared.ProviderPresence=@{At=[datetime]::UtcNow;Names=$names}
 }catch{$Shared.ProviderError=$_.Exception.GetBaseException().Message}
 Start-Sleep -Milliseconds 650
}
