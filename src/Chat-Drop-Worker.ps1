param([string[]]$Files,[string]$Prompt,[string]$BaseDirectory,[string]$Provider='chatgpt',$Operation=$null)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName UIAutomationClient,UIAutomationTypes,System.Windows.Forms
. (Join-Path $BaseDirectory 'Chat-Window.ps1')
. (Join-Path $BaseDirectory 'Chat-Control-Matching.ps1')
. (Join-Path $BaseDirectory 'Chat-Actions.ps1')
. (Join-Path $BaseDirectory 'Chat-File-Paste.ps1')
. (Join-Path $BaseDirectory 'Chat-Prompt-Check.ps1')
. (Join-Path $BaseDirectory 'Drop-Providers.ps1')
if(-not ('OrbyDropTransfer' -as [type])){
 $library=Join-Path $BaseDirectory 'Orby-Drop.dll'
 if([IO.File]::Exists($library)){Add-Type -Path $library}else{Add-Type -Path (Join-Path $BaseDirectory 'Drop-Transfer.cs') -ReferencedAssemblies UIAutomationClient,UIAutomationTypes,WindowsBase,System.Core,System.Windows.Forms}
}
. (Join-Path $BaseDirectory 'Drop-Fast.ps1')
function Invoke-ChatButton($Button){Assert-OrbyDropActive;Invoke-OrbyControl $Button}
function Set-OrbyDropPrompt($Root,$Composer,[string]$Text){
 if(-not $Text.Length){return $Composer}
 Set-OrbyDropStage 'Adding your message';Assert-OrbyDropTarget $Root $adapter
 if((Get-OrbyComposerText $Composer).Trim().Length){throw 'The draft changed. Nothing was overwritten or sent.'}
 $vp=$null
 if($Composer.TryGetCurrentPattern([Windows.Automation.ValuePattern]::Pattern,[ref]$vp) -and -not $vp.Current.IsReadOnly){$vp.SetValue($Text)}else{
  $Composer.SetFocus();Assert-OrbyDropTarget $Root $adapter
  $focused=[Windows.Automation.AutomationElement]::FocusedElement
  if(-not [Windows.Automation.Automation]::Compare($focused,$Composer)){throw 'The message box lost focus. Nothing was pasted.'}
  $script:orbyClipboardSaved=Save-OrbyClipboard;$script:orbyClipboardToken=[guid]::NewGuid().ToString()
  $data=[Windows.Forms.DataObject]::new();$data.SetText($Text);$data.SetData('Orby.FileTransfer.Token',$script:orbyClipboardToken)
  [Windows.Forms.Clipboard]::SetDataObject($data,$true);Assert-OrbyDropActive;[Windows.Forms.SendKeys]::SendWait('^v')
 }
 return Wait-OrbyPromptInserted $Root $Text
}
$attachmentsInvoked=$false;$sendInvoked=$false;$stage='Validate request'
try{
 $adapter=Get-OrbyDropAdapter $Provider
 if(-not $Files.Count -or @($Files | Where-Object {-not [IO.File]::Exists($_)}).Count){throw 'The dropped files no longer exist'}
 Set-OrbyDropStage ('Opening '+$adapter.Name)
 $root=Find-OrbyDropWindow $adapter
 if(-not $root){Open-OrbyDropApp $adapter}
 $deadline=[datetime]::UtcNow.AddSeconds(25)
 while(-not $root -and [datetime]::UtcNow -lt $deadline){Assert-OrbyDropActive;Start-Sleep -Milliseconds 400;$root=Find-OrbyDropWindow $adapter}
 if(-not $root){throw 'Could not find the selected AI. Finish signing in in its app or website, then retry.'}
 $script:chatHwnd=[IntPtr]$root.Current.NativeWindowHandle
 Assert-OrbyDropActive;[void][OrbyChatWindow]::Activate($script:chatHwnd)
 $activationDeadline=[datetime]::UtcNow.AddSeconds(3);do{Assert-OrbyDropActive;Start-Sleep -Milliseconds 100}while((Get-OrbyDropForegroundWindow) -ne $script:chatHwnd -and [datetime]::UtcNow -lt $activationDeadline)
 Assert-OrbyDropTarget $root $adapter
 Set-OrbyDropStage 'Opening a new chat'
 $browserChat=(Get-Process -Id $root.Current.ProcessId).ProcessName -in @('chrome','msedge','brave','firefox')
 if($browserChat){$root=Open-OrbyDropFreshBrowserChat $root $adapter}else{
 $new=$null;$deadline=[datetime]::UtcNow.AddSeconds(15)
 do{Assert-OrbyDropActive;$new=Find-OrbyNewChat $root $Provider;if(-not $new){Start-Sleep -Milliseconds 250}}while(-not $new -and [datetime]::UtcNow -lt $deadline)
 if(-not $new){throw 'New chat is unavailable. Open a new chat in the selected app and retry.'}
 Assert-OrbyDropTarget $root $adapter;Invoke-ChatButton $new
 }
 $deadline=[datetime]::UtcNow.AddSeconds(10);$composer=$null
 do{
  Assert-OrbyDropActive
  try{$candidate=Find-ChatComposer $root;if((Get-OrbyComposerText $candidate).Trim().Length -eq 0){$composer=$candidate}}catch{}
  if(-not $composer){Start-Sleep -Milliseconds 250}
 }while(-not $composer -and [datetime]::UtcNow -lt $deadline)
 if(-not $composer){throw 'A verified empty message box was not found. No existing draft was overwritten.'}
 Assert-OrbyDropNoDraftAttachments $composer
 Set-OrbyDropStage 'Attaching files'
 Assert-OrbyDropTarget $root $adapter
 $attachmentsInvoked=$true
 # Transfer the already-dropped files directly; never open a file chooser.
 Add-OrbyDropFilesDirect $root $adapter $composer $Files
 Set-OrbyDropStage 'Checking attached files'
 $deadline=[datetime]::UtcNow.AddSeconds(8);$attachment=$null
 do{
  Assert-OrbyDropTarget $root $adapter
  $composer=Find-ChatComposer $root
  $attachment=Get-OrbyDropAttachmentState $root $composer $Files
  if($attachment.Error){throw $attachment.Error}
  if($attachment.Count -eq $Files.Count){break}
  Start-Sleep -Milliseconds 100
 }while([datetime]::UtcNow -lt $deadline)
 if($attachment.Count -ne $Files.Count){throw 'The selected AI did not accept all pasted files. Nothing was sent. The file chooser was not opened.'}
 if($script:orbyClipboardToken){Restore-OrbyClipboard $script:orbyClipboardSaved $script:orbyClipboardToken;$script:orbyClipboardToken=$null}
 if($Operation){$Operation.AttachmentsConfirmed=$true}
 # Keep the message visible beside the file while its network upload finishes.
 $composer=Set-OrbyDropPrompt $root $composer $Prompt
 Set-OrbyDropStage 'Waiting for attachment upload'
 $deadline=[datetime]::UtcNow.AddSeconds(30)
 do{
  Assert-OrbyDropTarget $root $adapter
  $composer=Find-ChatComposer $root
  $attachment=Get-OrbyDropAttachmentState $root $composer $Files
  if($attachment.Error){throw $attachment.Error}
  if($attachment.Ready){break}
  Start-Sleep -Milliseconds 100
 }while([datetime]::UtcNow -lt $deadline)
 if(-not $attachment.Ready){throw 'The AI is still uploading. Your files and message are in its draft; nothing was sent. Check its upload status before retrying.'}
 Set-OrbyDropStage 'Sending to the selected AI'
 $deadline=[datetime]::UtcNow.AddSeconds(5);$send=$null
 do{Assert-OrbyDropActive;$send=Find-ChatButton $root '(?i)^(Send|Send message|Send prompt|Submit|Submit prompt)$';if(-not $send){Start-Sleep -Milliseconds 200}}while(-not $send -and [datetime]::UtcNow -lt $deadline)
 if(-not $send){throw 'Send is unavailable. The uploaded files remain in the selected app; nothing was sent.'}
 Assert-OrbyDropTarget $root $adapter
 if($Prompt.Length -and (ConvertTo-OrbyComparablePrompt (Get-OrbyComposerText $composer $false)) -cne (ConvertTo-OrbyComparablePrompt $Prompt)){throw 'The message changed before Send. Nothing was sent.'}
 if($Operation){$Operation.PromptConfirmed=$true}
 $draftAttachmentTokens=@($attachment.Tokens)
 # Mark BEFORE Invoke: an exception during Invoke can still mean the app accepted it.
 Assert-OrbyDropActive;$sendInvoked=$true;if($Operation){$Operation.SendInvoked=$true}
 Invoke-ChatButton $send
 Set-OrbyDropStage 'Confirming the request'
 $deadline=[datetime]::UtcNow.AddSeconds(8);$confirmed=$false
 do{
  Assert-OrbyDropActive;Start-Sleep -Milliseconds 250
  if(Find-ChatButton $root '(?i)^Stop( generating| streaming| response)?$'){$confirmed=$true}
  else{
   try{
    Assert-OrbyDropTarget $root $adapter
    $afterComposer=Find-ChatComposer $root
    $after=Get-OrbyDropAttachmentState $root $afterComposer $Files
    $sendStillEnabled=Find-ChatButton $root '(?i)^(Send|Send message|Send prompt|Submit|Submit prompt)$'
    $oldStillPresent=@($after.Tokens | Where-Object {$_ -in $draftAttachmentTokens}).Count
    $confirmed=($draftAttachmentTokens.Count -gt 0 -and -not $oldStillPresent -and $after.Count -eq 0 -and -not $sendStillEnabled -and (Get-OrbyComposerText $afterComposer).Trim().Length -eq 0)
   }catch{}
  }
 }while(-not $confirmed -and [datetime]::UtcNow -lt $deadline)
 if(-not $confirmed){throw 'Send was clicked. Check the response in the selected app before retrying.'}
 [pscustomobject]@{Sent=$true;RequiresReview=$false;Message='Sent to '+$adapter.Name}
}catch{
 if($Operation){$Operation.FailureType=$_.Exception.GetType().FullName;$Operation.FailureDetail=$_.Exception.ToString();$Operation.FailureLine=$_.InvocationInfo.ScriptLineNumber}
 $failureMessage=$_.Exception.GetBaseException().Message
 if([string]::IsNullOrWhiteSpace($failureMessage)){$failureMessage='The AI controls changed during the handoff. Check the selected app before retrying.'}
 [pscustomobject]@{Sent=$false;RequiresReview=($sendInvoked -or $attachmentsInvoked);Message=($stage+': '+$failureMessage)}
}finally{
 try{if($script:orbyClipboardToken){Restore-OrbyClipboard $script:orbyClipboardSaved $script:orbyClipboardToken}}catch{}
 if($Operation){$Operation.ElapsedMs=[math]::Round(([datetime]::UtcNow-$Operation.Started).TotalMilliseconds)}
}
