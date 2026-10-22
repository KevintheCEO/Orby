param([string]$TestDirectory=(Join-Path $PSScriptRoot 'claude-sync-test'))
$ErrorActionPreference='Stop'
Add-Type -Path (Join-Path $PSScriptRoot 'Claude-Code.cs') -ReferencedAssemblies System.Web.Extensions,System.Core
Add-Type -Path (Join-Path $PSScriptRoot 'Provider-Reader.cs') -ReferencedAssemblies UIAutomationClient,UIAutomationTypes,WindowsBase,System.Core
. (Join-Path $PSScriptRoot 'Claude-Sync.ps1')
function Assert($ok,$why){if(-not $ok){throw $why}}
Assert ([OrbyProviderReader]::Classify($true,[string[]]@('Stop response (Ctrl+Enter)')) -eq 'working') 'Shortcut label not normalized'
Assert ([OrbyProviderReader]::IsPrompt('Reply to Claude','')) 'Reply composer missed'
Assert ([OrbyProviderReader]::IsPrompt('','chat-input')) 'Contenteditable ID missed'
Assert (-not [OrbyProviderReader]::IsPrompt('Search chats','search')) 'Search mistaken for composer'
Assert ([OrbyProviderReader]::Classify($false,[string[]]@('Send')) -eq 'unknown') 'Unreadable app falsely live'
Assert ([OrbyProviderReader]::Classify($true,[string[]]@('Allow once','Deny')) -eq 'idle') 'Ordinary chat mistaken for permission'
$dir=Join-Path $TestDirectory 'signals';New-Item -ItemType Directory -Path $dir -Force | Out-Null
$now=[datetime]::UtcNow;$owner=Get-Process -Id $PID;$start=$owner.StartTime.ToUniversalTime().Ticks
$inputJson='{"session_id":"first","hook_event_name":"UserPromptSubmit","prompt":"PRIVATE-PROMPT-SENTINEL","tool_input":{"token":"PRIVATE-TOOL-SENTINEL"},"transcript_path":"PRIVATE-PATH-SENTINEL"}'
Assert ([OrbyClaudeCode]::Observe($inputJson,$dir,$PID,$start,$now)) 'Prompt event not persisted'
$json=Get-ChildItem -LiteralPath $dir -Filter '*.json' | Get-Content -Raw
Assert ($json -notmatch 'PRIVATE-|"first"|"prompt"|transcript_path|tool_input') 'Private data stored in bridge'
$one=$json | ConvertFrom-Json
Assert ($one.State -eq 'working') 'Prompt did not mark working'
$permission='{"session_id":"second","hook_event_name":"PermissionRequest"}'
Assert ([OrbyClaudeCode]::Observe($permission,$dir,$PID,$start,$now.AddMilliseconds(1))) 'Permission event missed'
Assert ([OrbyClaudeCode]::EventState('Notification','auth_success') -eq $null) 'Auth treated as work'
Assert (-not [OrbyClaudeCode]::Observe('{"session_id":"first","hook_event_name":"Stop","agent_id":"child"}',$dir,$PID,$start,$now.AddMilliseconds(2))) 'Subagent stopped parent'
Assert (-not [OrbyClaudeCode]::Observe('{"session_id":"first","hook_event_name":"Stop"}',$dir,$PID,$start,$now.AddMilliseconds(-1))) 'Older event overwrote newer event'
$signals=@(Get-ChildItem -LiteralPath $dir -Filter '*.json' | ForEach-Object {[OrbyCodeSignal]($_ | Get-Content -Raw | ConvertFrom-Json)})
$alive=[Func[int,long,bool]]{param($id,$ticks) $id -eq $PID -and $ticks -eq $start}
$state=[OrbyClaudeCode]::Aggregate([OrbyCodeSignal[]]$signals,$now.AddSeconds(1),$alive)
Assert ($state.State -eq 'attention' -and $state.Sessions -eq 2) 'Multiple session approval priority failed'
[void][OrbyClaudeCode]::Observe('{"session_id":"second","hook_event_name":"Stop"}',$dir,$PID,$start,$now.AddMilliseconds(3))
$signals=@(Get-ChildItem -LiteralPath $dir -Filter '*.json' | ForEach-Object {[OrbyCodeSignal]($_ | Get-Content -Raw | ConvertFrom-Json)})
$state=[OrbyClaudeCode]::Aggregate([OrbyCodeSignal[]]$signals,$now.AddHours(4),$alive)
Assert ($state.State -eq 'working') 'Finished session or elapsed time killed legitimate long work'
$dead=[Func[int,long,bool]]{param($id,$ticks) $false}
Assert (-not [OrbyClaudeCode]::Aggregate([OrbyCodeSignal[]]$signals,$now,$dead).Open) 'Crashed/reused process retained LIVE'
$untracked=[OrbyCodeSignal]@{State='working';AtTicks=$now.AddMinutes(-1).Ticks;OwnerPid=0}
Assert (-not [OrbyClaudeCode]::Aggregate([OrbyCodeSignal[]]@($untracked),$now,$alive).Readable) 'Unknown owner guessed LIVE'
foreach($ev in @('StopFailure','SessionEnd','PostToolUse','Elicitation','ElicitationResult')){Assert ($null -ne [OrbyClaudeCode]::EventState($ev,'')) ('Missing lifecycle event '+$ev)}
$config=Join-Path $TestDirectory 'config';New-Item -ItemType Directory -Path $config -Force | Out-Null
$settingsPath=Join-Path $config 'settings.json'
$before='{"env":{"CUSTOM":"kept"},"permissions":{"deny":["Read(secrets)"]},"hooks":{"Stop":[{"matcher":"","hooks":[{"type":"command","command":"echo existing"},{"type":"command","command":"old/Orby-Claude-Hook.exe"}]}]}}'
[IO.File]::WriteAllText($settingsPath,$before)
Set-OrbyClaudeCodeSync $true $config $PSScriptRoot
Set-OrbyClaudeCodeSync $true $config $PSScriptRoot
Assert (Get-OrbyClaudeCodeSync $config) 'Installed sync not detected'
$settings=Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
Assert ($settings.env.CUSTOM -eq 'kept' -and $settings.permissions.deny[0] -eq 'Read(secrets)') 'Existing settings changed'
Assert (@($settings.hooks.Stop | ForEach-Object {$_.hooks} | Where-Object {$_.command -match 'Orby-Claude-Hook.exe'}).Count -eq 1) 'Duplicate hook installation'
Assert (@($settings.hooks.Stop | ForEach-Object {$_.hooks} | Where-Object {$_.command -eq 'echo existing'}).Count -eq 1) 'User hook lost'
Assert ([IO.File]::ReadAllText((Join-Path $config 'settings.before-orby.json')) -eq $before) 'Exact original backup missing'
# Exercise the compiled WinExe's redirected stdin, silence and fail-open behavior.
$exe=Join-Path $config 'orby-bridge/Orby-Claude-Hook.exe'
function Run-Hook($payload){
 $p=[Diagnostics.Process]::new();$p.StartInfo=[Diagnostics.ProcessStartInfo]@{FileName=$exe;UseShellExecute=$false;CreateNoWindow=$true;RedirectStandardInput=$true;RedirectStandardOutput=$true;RedirectStandardError=$true}
 [void]$p.Start();$p.StandardInput.Write($payload);$p.StandardInput.Close();Assert ($p.WaitForExit(4000)) 'Observer blocked hook';Assert ($p.ExitCode -eq 0 -and $p.StandardOutput.ReadToEnd() -eq '' -and $p.StandardError.ReadToEnd() -eq '') 'Observer altered Claude output';$p.Dispose()
}
Run-Hook '{"session_id":"executable","hook_event_name":"UserPromptSubmit","prompt":"PRIVATE-EXE-SENTINEL"}'
$realFiles=@(Get-ChildItem (Join-Path $config 'orby-bridge/state') -Filter '*.json')
Assert ($realFiles.Count -eq 1 -and ($realFiles[0] | Get-Content -Raw) -notmatch 'PRIVATE-EXE') 'Compiled observer stdin failed'
Run-Hook 'invalid json'
Set-OrbyClaudeCodeSync $false $config $PSScriptRoot
Assert (-not (Get-OrbyClaudeCodeSync $config)) 'Off switch failed'
$settings=Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
Assert ($settings.hooks.Stop[0].hooks[0].command -eq 'echo existing' -and $settings.permissions.deny[0] -eq 'Read(secrets)') 'Unpair deleted unrelated settings'
Assert (@(Get-ChildItem (Join-Path $config 'orby-bridge/state') -Filter '*.json').Count -eq 0) 'Off retained stale session'
Run-Hook '{"session_id":"disabled","hook_event_name":"UserPromptSubmit"}'
Assert (@(Get-ChildItem (Join-Path $config 'orby-bridge/state') -Filter '*.json').Count -eq 0) 'Disabled observer wrote status'
# Exercise the actual provider merger, including simultaneous ChatGPT activity.
$source=Get-Content (Join-Path $PSScriptRoot 'Providers.ps1') -Raw
$functions=$source.Substring($source.IndexOf('function Get-OrbyProviderSnapshot'),$source.IndexOf('function Open-OrbyProvider')-$source.IndexOf('function Get-OrbyProviderSnapshot'))
. ([scriptblock]::Create($functions))
$script:orbyShared=@{ProviderSnapshots=@(
 [OrbyProviderSnapshot]@{Provider='claude';AppOpen=$true;StatusReadable=$true;Connected=$true;State='idle';Hwnd=123},
 [OrbyProviderSnapshot]@{Provider='chatgpt';AppOpen=$true;StatusReadable=$true;Connected=$true;State='working'})
 ClaudeCodeAt=[datetime]::UtcNow;ClaudeCodeStatus=[OrbyCodeStatus]@{Open=$true;Readable=$true;State='attention';Detail='Claude Code · waiting for your input'}}
$merged=Get-OrbyProviderSnapshot 'claude'
Assert ($merged.State -eq 'attention' -and $merged.Source -eq 'code' -and $merged.Hwnd -eq 123) 'Code wait hidden behind idle chat'
Assert ((Get-OrbyProviderSnapshot 'chatgpt').State -eq 'working') 'Claude altered ChatGPT status'
$script:orbyShared.ClaudeCodeStatus.State='idle';$script:orbyShared.ProviderSnapshots[0].State='working'
Assert ((Get-OrbyProviderSnapshot 'claude').Source -eq 'chat') 'Idle Code hid generating chat'
$script:orbyShared.ClaudeCodeAt=[datetime]::UtcNow.AddSeconds(-9);$script:orbyShared.ClaudeCodeStatus.State='attention'
Assert ((Get-OrbyProviderSnapshot 'claude').Source -eq 'chat') 'Stale Code feed won priority'
$settings=[pscustomobject]@{disableAllHooks=$true}
[IO.File]::WriteAllText($settingsPath,($settings | ConvertTo-Json))
$blocked=$false;try{Set-OrbyClaudeCodeSync $true $config $PSScriptRoot}catch{$blocked=$true}
Assert ($blocked) 'Pairing overrode disabled hooks'
Write-Output 'PASS: Claude chat labels, Code events, multi-session priority, long work, process expiry, privacy, silent EXE, settings preservation, idempotent pairing, off switch and independent merged providers'
