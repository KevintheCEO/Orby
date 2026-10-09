param([string[]]$Files,[string]$Prompt,[string]$BaseDirectory)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName UIAutomationClient,UIAutomationTypes,System.Windows.Forms
. (Join-Path $BaseDirectory 'Chat-Window.ps1')
. (Join-Path $BaseDirectory 'Chat-Control-Matching.ps1')
. (Join-Path $BaseDirectory 'Chat-Actions.ps1')
. (Join-Path $BaseDirectory 'Chat-File-Paste.ps1')
. (Join-Path $BaseDirectory 'Chat-Prompt-Check.ps1')
function Find-ChatButton($Root,[string]$Pattern){
 foreach($tree in (Get-OrbyChatRoots $Root)){
  foreach($el in $tree.FindAll([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.Condition]::TrueCondition)){
   try{
    $c=$el.Current
    if($c.IsOffscreen -or -not $c.IsEnabled){continue}
    if($c.Name -notmatch $Pattern -and $c.HelpText -notmatch $Pattern){continue}
    if(Get-OrbyControlAction $el){return $el}
   }catch{}
  }
 }
 return $null
}
function Invoke-ChatButton($Button){Invoke-OrbyControl $Button}
function Find-ChatComposer($Root){
 $matches=New-Object Collections.Generic.List[object]
 foreach($tree in (Get-OrbyChatRoots $Root)){
  foreach($el in $tree.FindAll([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.Condition]::TrueCondition)){
   try{
    $c=$el.Current
    if($c.IsOffscreen -or -not $c.IsEnabled){continue}
    $rank=Get-OrbyComposerRank $c.Name $c.AutomationId $c.ClassName
    if($rank -le 0){continue}
    $value=$null
    if($el.TryGetCurrentPattern([Windows.Automation.ValuePattern]::Pattern,[ref]$value)){
     if(-not $value.Current.IsReadOnly){$matches.Add([pscustomobject]@{Element=$el;Rank=$rank})}
    }
   }catch{}
  }
 }
 $best=$matches | Sort-Object Rank -Descending | Select-Object -First 1
 if($best){return $best.Element}
 throw 'Editable ChatGPT composer is not exposed by accessibility'
}
function Wait-OrbyEmptyComposer($Root){
 $deadline=[datetime]::UtcNow.AddSeconds(8);$composer=$null;$length=-1
 do{
  try{
   $composer=Find-ChatComposer $Root
   $value=$composer.GetCurrentPattern([Windows.Automation.ValuePattern]::Pattern)
   $length=(Get-OrbyComposerText $composer).Trim().Length
   if($length -eq 0){return $composer}
  }catch{}
  Start-Sleep -Milliseconds 250
 }while([datetime]::UtcNow -lt $deadline)
 throw ('New-chat composer did not become empty (draft length '+$length+'). Nothing was overwritten.')
}
$sendInvoked=$false;$stage='Validate request'
try{
 if(-not $Prompt.Trim() -or -not $Files.Count){throw 'Files and a prompt are required'}
 $app=Get-Process ChatGPT -ErrorAction SilentlyContinue | Where-Object {$_.MainWindowHandle -ne [IntPtr]::Zero} | Select-Object -First 1
 if(-not $app){throw 'Open the ChatGPT desktop app first'}
 $root=[Windows.Automation.AutomationElement]::FromHandle($app.MainWindowHandle)
 $script:chatHwnd=$app.MainWindowHandle
 [void][OrbyChatWindow]::Activate($script:chatHwnd)
 Start-Sleep -Milliseconds 200
 if([OrbyChatWindow]::GetForegroundWindow() -ne $script:chatHwnd){throw 'Could not activate ChatGPT. Bring ChatGPT to the front and retry.'}
$stage='Find New chat button'
 $new=$null;$deadline=[datetime]::UtcNow.AddSeconds(4)
 do{$new=Find-OrbyNewChat $root;if(-not $new){Start-Sleep -Milliseconds 300}}while(-not $new -and [datetime]::UtcNow -lt $deadline)
 if(-not $new){
  $capture=Join-Path $env:LOCALAPPDATA 'Orby\chatgpt-controls.txt'
  Save-OrbyChatControls $root $capture
  throw ('New chat is not exposed. Control capture saved: '+$capture)
 }
 Invoke-ChatButton $new
 $stage='Wait for new-chat composer'
 $composer=Wait-OrbyEmptyComposer $root
 $valuePattern=$composer.GetCurrentPattern([Windows.Automation.ValuePattern]::Pattern)
 $stage='Paste dropped files into ChatGPT'
 Paste-OrbyFiles $composer $Files $script:chatHwnd
 $stage='Confirm attachment upload'
 $deadline=[datetime]::UtcNow.AddSeconds(25);$ready=0
 do{
  $all=@(foreach($tree in (Get-OrbyChatRoots $root)){$tree.FindAll([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.Condition]::TrueCondition)})
  $names=@($all | Where-Object {-not $_.Current.IsOffscreen} | ForEach-Object {$_.Current.Name}) -join "`n"
  if($names -match '(?i)upload failed|failed to upload|file too large|unsupported file'){throw 'ChatGPT reported an attachment error'}
  $missing=@($Files | Where-Object {$names.IndexOf([IO.Path]::GetFileName($_),[StringComparison]::OrdinalIgnoreCase) -lt 0})
  if(-not $missing.Count -and $names -notmatch '(?i)uploading|processing file'){$ready++}else{$ready=0}
  if($ready -lt 2){Start-Sleep -Milliseconds 500}
 }while($ready -lt 2 -and [datetime]::UtcNow -lt $deadline)
 if($ready -lt 2){throw 'Pasted attachments were not confirmed. Nothing was sent'}
 Restore-OrbyClipboard $script:orbyClipboardSaved $script:orbyClipboardToken
 $script:orbyClipboardToken=$null
 $composer=Find-ChatComposer $root
 $valuePattern=$composer.GetCurrentPattern([Windows.Automation.ValuePattern]::Pattern)
 if((Get-OrbyComposerText $composer).Trim().Length -ne 0){throw 'ChatGPT draft changed. Nothing was sent'}
 $stage='Insert prompt'
 $valuePattern.SetValue($Prompt)
 $composer=Wait-OrbyPromptInserted $root $Prompt
 $stage='Find Send button'
 $deadline=[datetime]::UtcNow.AddSeconds(5);$send=$null
 do{$send=Find-ChatButton $root '(?i)^(Send|Send message|Send prompt)$';if(-not $send){Start-Sleep -Milliseconds 200}}while(-not $send -and [datetime]::UtcNow -lt $deadline)
 if(-not $send){throw 'ChatGPT Send button is unavailable. Nothing was sent'}
 $stage='Send request'
 Invoke-ChatButton $send;$sendInvoked=$true
 $deadline=[datetime]::UtcNow.AddSeconds(5);$confirmed=$false
 do{
  Start-Sleep -Milliseconds 200
  if((Find-ChatButton $root '(?i)^Stop( generating| streaming| response)?$') -or (Get-OrbyComposerText $composer).Length -eq 0){$confirmed=$true}
 }while(-not $confirmed -and [datetime]::UtcNow -lt $deadline)
 if(-not $confirmed){throw 'Send was clicked; verify the result in ChatGPT before retrying'}
 [pscustomobject]@{Sent=$true;RequiresReview=$false;Message='Sent files and prompt to a new ChatGPT chat.'}
}catch{
 try{if($root){Save-OrbyChatControls $root (Join-Path $env:LOCALAPPDATA 'Orby\chatgpt-controls.txt')}}catch{}
 [pscustomobject]@{Sent=$false;RequiresReview=$sendInvoked;Message=($stage+': '+$_.Exception.GetBaseException().Message)}
}

finally{
 try{if($script:orbyClipboardToken){Restore-OrbyClipboard $script:orbyClipboardSaved $script:orbyClipboardToken}}catch{}
}
