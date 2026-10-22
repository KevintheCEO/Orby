# Observe Claude Code's lifecycle through documented user hooks. Existing hooks are retained.
function Get-OrbyClaudeConfigRoot {
 if($env:CLAUDE_CONFIG_DIR){return [IO.Path]::GetFullPath($env:CLAUDE_CONFIG_DIR)}
 Join-Path ([Environment]::GetFolderPath('UserProfile')) '.claude'
}
function Get-OrbyClaudeCodeSync {
 param([string]$ConfigRoot=(Get-OrbyClaudeConfigRoot))
 $config=Join-Path $ConfigRoot 'settings.json';$exe=Join-Path $ConfigRoot 'orby-bridge/Orby-Claude-Hook.exe'
 if(-not (Test-Path -LiteralPath $exe) -or -not (Test-Path -LiteralPath (Join-Path $ConfigRoot 'orby-bridge/enabled')) -or -not (Test-Path -LiteralPath $config)){return $false}
 try {
  $settings=Get-Content -LiteralPath $config -Raw | ConvertFrom-Json
  foreach($event in @('SessionStart','UserPromptSubmit','Stop','SessionEnd','PermissionRequest')) {
   $commands=@($settings.hooks.$event | ForEach-Object {$_.hooks} | Where-Object {$_.command -match 'Orby-Claude-Hook\.exe'})
   if(-not $commands.Count){return $false}
  }
  return $true
 }catch{return $false}
}
function Set-OrbyClaudeCodeSync {
 param([bool]$Enabled,[string]$ConfigRoot=(Get-OrbyClaudeConfigRoot),[string]$AppDirectory=$script:providerDirectory)
 $ErrorActionPreference='Stop'
 $ConfigRoot=$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ConfigRoot)
 $settingsPath=Join-Path $ConfigRoot 'settings.json';$bridge=Join-Path $ConfigRoot 'orby-bridge'
 $exe=Join-Path $bridge 'Orby-Claude-Hook.exe'
 $original=if(Test-Path -LiteralPath $settingsPath){[IO.File]::ReadAllText($settingsPath)}else{'{}'}
 $settings=$original | ConvertFrom-Json -ErrorAction Stop
 if($null -eq $settings -or $settings -isnot [pscustomobject]){throw 'Claude settings must contain a JSON object.'}
 if($Enabled -and $settings.disableAllHooks){throw 'Claude has all hooks disabled. Enable them in Claude before pairing Code activity.'}
 if($Enabled -and $settings.allowManagedHooksOnly){throw 'Claude is restricted to managed hooks. Ask your administrator to enable Orby activity hooks.'}
 if(-not $settings.hooks){$settings | Add-Member -NotePropertyName hooks -NotePropertyValue ([pscustomobject]@{}) -Force}
 $events=@('SessionStart','UserPromptSubmit','PreToolUse','PermissionRequest','PostToolUse','PostToolUseFailure','Notification','Stop','StopFailure','SessionEnd','Elicitation','ElicitationResult')
 foreach($event in @(@($settings.hooks.PSObject.Properties.Name) + $events | Select-Object -Unique)) {
  $groups=@()
  foreach($group in @($settings.hooks.$event)) {
   if(-not $group){continue}
   $remaining=@($group.hooks | Where-Object {$_.command -notmatch 'Orby-Claude-Hook\.exe'})
   if($remaining.Count){$group.hooks=$remaining;$groups+=,$group}
  }
  if($Enabled -and $event -in $events) {
   # Shell quoting works with Windows cmd and Git Bash; no execution-policy bypass.
   $command='"'+($exe -replace '\\','/')+'"'
   $groups+=,[pscustomobject]@{hooks=@([pscustomobject]@{type='command';command=$command;timeout=2})}
  }
  if($groups.Count){$settings.hooks | Add-Member -NotePropertyName $event -NotePropertyValue $groups -Force}
  elseif($settings.hooks.PSObject.Properties[$event]){$settings.hooks.PSObject.Properties.Remove($event)}
 }
 if($Enabled){
  New-Item -ItemType Directory -Path $bridge -Force | Out-Null
  Copy-Item -LiteralPath (Join-Path $AppDirectory 'Orby-Claude-Hook.exe') -Destination $exe -Force
 }
 New-Item -ItemType Directory -Path $ConfigRoot -Force | Out-Null
 # First installation preserves the exact original file for manual recovery.
 $backup=Join-Path $ConfigRoot 'settings.before-orby.json'
 if(-not (Test-Path -LiteralPath $backup) -and (Test-Path -LiteralPath $settingsPath)){[IO.File]::WriteAllText($backup,$original,[Text.UTF8Encoding]::new($false))}
 # Refuse to overwrite a concurrent edit in Claude's settings.
 if((Test-Path -LiteralPath $settingsPath) -and [IO.File]::ReadAllText($settingsPath) -ne $original){throw 'Claude settings changed during pairing. Try again.'}
 New-Item -ItemType Directory -Path $bridge -Force | Out-Null
 $temp=Join-Path $bridge ('settings-'+[guid]::NewGuid().ToString('N')+'.tmp')
 try {
  [IO.File]::WriteAllText($temp,($settings | ConvertTo-Json -Depth 100),[Text.UTF8Encoding]::new($false))
  if(Test-Path -LiteralPath $settingsPath){[IO.File]::Replace($temp,$settingsPath,[System.Management.Automation.Language.NullString]::Value)}else{[IO.File]::Move($temp,$settingsPath)}
 }finally{if(Test-Path -LiteralPath $temp){Remove-Item -LiteralPath $temp}}
 if($Enabled){[IO.File]::WriteAllText((Join-Path $bridge 'enabled'),'1')}else{
  if(Test-Path -LiteralPath (Join-Path $bridge 'enabled')){Remove-Item -LiteralPath (Join-Path $bridge 'enabled')}
  # Signal immediately to the running worker. No recursive deletion of user data.
  $stateDir=Join-Path $bridge 'state'
  if(Test-Path -LiteralPath $stateDir){Get-ChildItem -LiteralPath $stateDir -Filter '*.json' -File | ForEach-Object {Remove-Item -LiteralPath $_.FullName}}
 }
}
function Toggle-OrbyClaudeCodeSync {
 try {
  $enable=-not (Get-OrbyClaudeCodeSync)
  Set-OrbyClaudeCodeSync $enable
  if($enable){
   $script:orbySettings.ProviderEnabled=(@(($script:orbySettings.ProviderEnabled -split ',')+'claude') | Where-Object {$_} | Select-Object -Unique) -join ','
   Save-OrbySettings
  }
  $script:claudeCodeSetupNote=if($enable){'Code sync is on. Start a new Claude Code session to activate it.'}else{'Code sync is off. Claude chat remains available.'}
 }catch{$script:claudeCodeSetupNote='Could not pair Code: '+$_.Exception.Message}
 Update-OrbyConnections
}
