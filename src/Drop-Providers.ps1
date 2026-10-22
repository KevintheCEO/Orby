function Get-OrbyDropForegroundWindow { return [OrbyChatWindow]::GetForegroundWindow() }
function Get-OrbyDropAdapter([string]$Id){
 switch($Id){
  chatgpt {return @{Id=$Id;Name='ChatGPT';Process='ChatGPT';Url='https://chatgpt.com/';Host='chatgpt.com'}}
  claude {return @{Id=$Id;Name='Claude';Process='Claude';Url='https://claude.ai/new';Host='claude.ai'}}
  gemini {return @{Id=$Id;Name='Gemini';Process='Gemini';Url='https://gemini.google.com/app';Host='gemini.google.com'}}
  default {throw 'Choose ChatGPT, Claude, or Gemini'}
 }
}
function Test-OrbyDropUrl([string]$Url,[string]$HostName){
 $parsed=$null
 if($Url -notmatch '^https?://'){$Url='https://'+$Url}
 return [uri]::TryCreate($Url,[UriKind]::Absolute,[ref]$parsed) -and $parsed.Scheme -eq 'https' -and $parsed.IsDefaultPort -and -not $parsed.UserInfo -and $parsed.DnsSafeHost -eq $HostName -and $parsed.AbsolutePath -notmatch '^/(settings|usage|login|signin)(/|$)'
}
function Assert-OrbyDropActive {
 if($Operation -and $Operation.Cancelled){throw 'Handoff cancelled'}
}
function Set-OrbyDropStage([string]$Text){Assert-OrbyDropActive;$script:stage=$Text;if($Operation){$Operation.Stage=$Text}}
function Test-OrbyDropWindow($Root,$Adapter){
 try{
  $process=Get-Process -Id $Root.Current.ProcessId -ErrorAction Stop
  if($process.ProcessName -eq $Adapter.Process){return $true}
  if($process.ProcessName -notin @('msedge','chrome','firefox','brave')){return $false}
  foreach($node in $Root.FindAll([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::ControlTypeProperty,[Windows.Automation.ControlType]::Edit))){
   $c=$node.Current
   if($c.IsOffscreen -or ($c.Name -notmatch '(?i)address|search or enter|search with' -and $c.AutomationId -notmatch '(?i)address|urlbar|omnibox')){continue}
   # A web page can name its own textbox Address. Only accept browser chrome,
   # outside the web document and beneath the browser toolbar.
   $ancestor=$node;$chrome=$false
   for($i=0;$i -lt 10 -and $ancestor;$i++){
    if($ancestor.Current.ControlType -eq [Windows.Automation.ControlType]::Document){break}
    if($ancestor.Current.ControlType -eq [Windows.Automation.ControlType]::ToolBar){$chrome=$true;break}
    $ancestor=[Windows.Automation.TreeWalker]::ControlViewWalker.GetParent($ancestor)
   }
   if(-not $chrome){continue}
   $vp=$null
   if($node.TryGetCurrentPattern([Windows.Automation.ValuePattern]::Pattern,[ref]$vp) -and (Test-OrbyDropUrl $vp.Current.Value $Adapter.Host)){return $true}
  }
 }catch{}
 return $false
}
function Find-OrbyDropWindow($Adapter){
 foreach($process in Get-Process | Where-Object {$_.MainWindowHandle -ne [IntPtr]::Zero -and $_.ProcessName -in @($Adapter.Process,'msedge','chrome','firefox','brave')}){
  Assert-OrbyDropActive
  try{$root=[Windows.Automation.AutomationElement]::FromHandle($process.MainWindowHandle);if(Test-OrbyDropWindow $root $Adapter){return $root}}catch{}
 }
 return $null
}
function Open-OrbyDropApp($Adapter){
 $entry=Get-StartApps -ErrorAction SilentlyContinue | Where-Object {$_.Name -eq $Adapter.Name} | Select-Object -First 1
 if($entry){Start-Process explorer.exe -ArgumentList ('shell:AppsFolder\'+$entry.AppID)}else{Start-Process $Adapter.Url}
}
function Open-OrbyDropFreshBrowserChat($Root,$Adapter){
 Assert-OrbyDropTarget $Root $Adapter
 $browser=Get-Process -Id $Root.Current.ProcessId -ErrorAction Stop
 if($browser.ProcessName -notin @('chrome','msedge','brave','firefox')){throw 'A supported browser was not found'}
 # A separate tab preserves an unsent draft in the existing tab.
 $flag=if($browser.ProcessName -eq 'firefox'){'-new-tab'}else{'--new-tab'}
 $oldDocument=$Root.FindAll([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::ControlTypeProperty,[Windows.Automation.ControlType]::Document)) | Where-Object {-not $_.Current.IsOffscreen} | Select-Object -First 1
 $oldToken=if($oldDocument){$oldDocument.GetRuntimeId() -join ','}else{''}
 Start-Process -FilePath $browser.Path -ArgumentList @($flag,$Adapter.Url)
 $deadline=[datetime]::UtcNow.AddSeconds(12)
 do{
  Assert-OrbyDropActive;Start-Sleep -Milliseconds 150
  try{
   $foreground=Get-OrbyDropForegroundWindow;$candidate=[Windows.Automation.AutomationElement]::FromHandle($foreground)
   if(Test-OrbyDropWindow $candidate $Adapter){
    $document=$candidate.FindAll([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::ControlTypeProperty,[Windows.Automation.ControlType]::Document)) | Where-Object {-not $_.Current.IsOffscreen} | Select-Object -First 1
    if($document -and ($document.GetRuntimeId() -join ',') -ne $oldToken){$script:chatHwnd=$foreground;return $candidate}
   }
  }catch{}
 }while([datetime]::UtcNow -lt $deadline)
 throw 'The new browser chat did not open. Nothing was attached or sent.'
}
function Assert-OrbyDropTarget($Root,$Adapter){
 Assert-OrbyDropActive
 if(-not (Test-OrbyDropWindow $Root $Adapter) -or (Get-OrbyDropForegroundWindow) -ne $script:chatHwnd){throw 'The selected AI is no longer in front. Nothing else was pasted or sent.'}
}
function Get-OrbyDropVisibleNames($Root){
 return (@(foreach($tree in Get-OrbyChatRoots $Root){foreach($node in $tree.FindAll([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.Condition]::TrueCondition)){try{if(-not $node.Current.IsOffscreen){$node.Current.Name}}catch{}}}) -join "`n")
}
function Get-OrbyDropAttachmentNodes($Root,[string[]]$Files){
 $seen=@{}
 foreach($tree in Get-OrbyChatRoots $Root){
  foreach($node in $tree.FindAll([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.Condition]::TrueCondition)){
   try{
    $c=$node.Current;if($c.IsOffscreen -or $c.ControlType -eq [Windows.Automation.ControlType]::Document){continue}
    foreach($file in $Files){$name=[IO.Path]::GetFileName($file);if($c.Name.IndexOf($name,[StringComparison]::OrdinalIgnoreCase) -ge 0){
     $id=$node.GetRuntimeId() -join ',';if(-not $seen[$id]){$seen[$id]=$true;[pscustomobject]@{Name=$name;Token=$id}}
    }}
   }catch{}
  }
 }
}
function Test-OrbyDropPreviewLabel([string]$Label,[string]$Filename,[string]$Provider=''){
 $label=$Label.Trim().Replace([string][char]0x2026,'...')
 if($Provider -eq 'claude' -and $label -match '^\d{13}_'){$withoutStamp=$label -replace '^\d{13}_','';if(Test-OrbyDropPreviewLabel $withoutStamp $Filename){return $true}}
 foreach($candidate in @([IO.Path]::GetFileName($Filename),[IO.Path]::GetFileNameWithoutExtension($Filename))){
  if($label -eq $candidate){return $true}
  $parts=$label -split '\.\.\.',2
  if($parts.Count -eq 2 -and ($parts[0].Length+$parts[1].Length) -ge 6 -and $candidate.StartsWith($parts[0],[StringComparison]::OrdinalIgnoreCase) -and $candidate.EndsWith($parts[1],[StringComparison]::OrdinalIgnoreCase)){return $true}
 }
 return $false
}
function Get-OrbyDropGeminiAttachments($Root,[string[]]$Files){
 foreach($node in $Root.FindAll([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.Condition]::TrueCondition)){
  $c=$node.Current;if($c.IsOffscreen -or $c.ClassName -notmatch '(?:^|\s)file-preview-container(?:\s|$)'){continue}
  $children=@($node.FindAll([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.Condition]::TrueCondition))
  $labels=@($children | Where-Object {$_.Current.ControlType -eq [Windows.Automation.ControlType]::Text} | ForEach-Object {$_.Current.Name})
  $matches=@($Files | Where-Object {$file=$_;@($labels | Where-Object {Test-OrbyDropPreviewLabel $_ $file}).Count -gt 0})
  $busy=@($children | Where-Object {-not $_.Current.IsOffscreen -and $_.Current.ControlType -eq [Windows.Automation.ControlType]::ProgressBar}).Count -gt 0
  [pscustomobject]@{Name=$(if($matches.Count -eq 1){[IO.Path]::GetFileName($matches[0])}else{''});Token=($node.GetRuntimeId() -join ',');Busy=$busy}
 }
}
function Assert-OrbyDropNoDraftAttachments($Composer){
 $scope=[Windows.Automation.TreeWalker]::ControlViewWalker.GetParent($Composer)
 for($depth=0;$scope -and $depth -lt 8;$depth++){
  if($scope.Current.ControlType -in @([Windows.Automation.ControlType]::Document,[Windows.Automation.ControlType]::Window)){return}
  $nodes=@($scope.FindAll([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.Condition]::TrueCondition))
  $hasUpload=@($nodes | Where-Object {-not $_.Current.IsOffscreen -and $_.Current.Name -match '(?i)^(Open upload file menu|Add attachments|Add files|Attach|Upload & tools)(\b|$)'}).Count -gt 0
  if($hasUpload){
   foreach($node in $nodes){$c=$node.Current;if($c.IsOffscreen){continue}
    if(($c.ControlType -eq [Windows.Automation.ControlType]::Button -and ($c.Name -match '(?i)\.[a-z][a-z0-9]{0,9}$' -or $c.Name -match '(?i)^(remove|delete)\s+(file|attachment|image|photo)')) -or $c.ClassName -match '(?i)file-thumbnail|attachment-chip|file-chip|(?:^|\s)file-preview-container(?:\s|$)'){
     throw 'The new-chat page still has an unsent attachment draft. Clear that draft in the selected app, then retry. Nothing was added or sent.'
    }
   }
   return
  }
  $scope=[Windows.Automation.TreeWalker]::ControlViewWalker.GetParent($scope)
 }
}
function Wait-OrbyDropPickerClosed($Root,$Adapter){
 $deadline=[datetime]::UtcNow.AddSeconds(8)
 do{
  Assert-OrbyDropActive
  $foreground=Get-OrbyDropForegroundWindow
  if($foreground -eq $script:chatHwnd){Assert-OrbyDropTarget $Root $Adapter;return}
  if(-not [OrbyChatWindow]::OwnedBy($foreground,$script:chatHwnd)){throw 'The selected AI lost focus after choosing files. Nothing was sent.'}
  [Windows.Forms.Application]::DoEvents();Start-Sleep -Milliseconds 100
 }while([datetime]::UtcNow -lt $deadline)
 throw 'The file picker is still open. Check the selected files; nothing was sent.'
}
function Add-OrbyDropFilesWithPicker($Root,$Adapter,[string[]]$Files){
 Assert-OrbyDropTarget $Root $Adapter
 $button=Find-ChatButton $Root '(?i)^(Open upload file menu|Add attachments|Add files|Add files and more|Add files, connectors, and more|Attach files|Attach|Upload files|Upload file|Add photos and files|Add content|Upload & tools)(\b|$)'
 if(-not $button){throw 'Attachment button is unavailable. Open a new chat in the selected app and retry.'}
 $pickerAction=[OrbyDropUIA]::InvokeAsync($button,$script:chatHwnd)
 if($Operation){$Operation.AttachmentTrace=@($button.Current.Name)}
 $invokedControls=@{($button.GetRuntimeId() -join ',')=$true}
 $deadline=[datetime]::UtcNow.AddSeconds(12);$dialog=$null
 do{
  Assert-OrbyDropActive
  if($pickerAction.IsFaulted){throw $pickerAction.Exception.GetBaseException()}
  $foreground=Get-OrbyDropForegroundWindow
  if($foreground -ne [IntPtr]::Zero -and $foreground -ne $script:chatHwnd -and -not [OrbyChatWindow]::OwnedBy($foreground,$script:chatHwnd)){if($Operation){$other=[Windows.Automation.AutomationElement]::FromHandle($foreground);$Operation.FocusTrace=@{Selected=[long]$script:chatHwnd;Foreground=[long]$foreground;Class=$other.Current.ClassName;Process=(Get-Process -Id $other.Current.ProcessId).ProcessName}};throw 'The selected AI lost focus while opening attachments. Nothing was sent.'}
  if($foreground -ne $script:chatHwnd -and [OrbyChatWindow]::OwnedBy($foreground,$script:chatHwnd)){
   $candidate=[Windows.Automation.AutomationElement]::FromHandle($foreground)
   if($candidate.Current.ClassName -eq '#32770'){$dialog=$candidate;break}
  }
  if($foreground -eq $script:chatHwnd){
   $upload=Find-ChatButton $Root '(?i)^(Choose files|Upload or add files|Upload files|Upload file|Upload from computer|Upload from device|Add photos & files|Add photos and files|From computer)(\b|$)'
   if($upload -and -not $invokedControls[($upload.GetRuntimeId() -join ',')]){
    # A modal picker can take focus between the snapshot and menu lookup.
    $currentForeground=Get-OrbyDropForegroundWindow
    if($currentForeground -eq $script:chatHwnd){Assert-OrbyDropTarget $Root $Adapter;$invokedControls[($upload.GetRuntimeId() -join ',')]=$true;$pickerAction=if($Adapter.Id -eq 'chatgpt'){[OrbyDropUIA]::ClickAsync($upload,$script:chatHwnd)}else{[OrbyDropUIA]::InvokeAsync($upload,$script:chatHwnd)};if($Operation){$Operation.AttachmentTrace+=@($upload.Current.Name)}}
    elseif(-not [OrbyChatWindow]::OwnedBy($currentForeground,$script:chatHwnd)){Assert-OrbyDropTarget $Root $Adapter}
   }
  }
  [Windows.Forms.Application]::DoEvents();Start-Sleep -Milliseconds 250
 }while([datetime]::UtcNow -lt $deadline)
 if(-not $dialog){throw 'The file picker did not open. Nothing was sent.'}
 if($Operation){$Operation.PickerHwnd=[long]$dialog.Current.NativeWindowHandle}
 $name=$null;$open=$null;$controlsDeadline=[datetime]::UtcNow.AddSeconds(5)
 do{
 Assert-OrbyDropActive
 foreach($node in $dialog.FindAll([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.Condition]::TrueCondition)){
  if($node.Current.AutomationId -eq '1148' -or ($node.Current.ControlType -eq [Windows.Automation.ControlType]::Edit -and $node.Current.Name -match '^File name')){$vp=$null;if($node.TryGetCurrentPattern([Windows.Automation.ValuePattern]::Pattern,[ref]$vp)){$name=$vp}}
  if($node.Current.AutomationId -eq '1' -and $node.Current.ControlType -eq [Windows.Automation.ControlType]::Button){$open=$node}
 }
 if(-not $name -or -not $open){[Windows.Forms.Application]::DoEvents();Start-Sleep -Milliseconds 200}
 }while((-not $name -or -not $open) -and [datetime]::UtcNow -lt $controlsDeadline)
 $fileList=(@($Files | ForEach-Object {'"'+[IO.Path]::GetFullPath($_)+'"'}) -join ' ')
 if(-not $name -or -not $open){
  Assert-OrbyDropActive
  if((Get-OrbyDropForegroundWindow) -ne [IntPtr]$dialog.Current.NativeWindowHandle -or -not [OrbyChatWindow]::OwnedBy([IntPtr]$dialog.Current.NativeWindowHandle,$script:chatHwnd)){throw 'The owned picker lost focus. Nothing was sent.'}
  if(-not [OrbyDropUIA]::SetPickerFiles([IntPtr]$dialog.Current.NativeWindowHandle,$fileList)){throw 'File picker controls are unavailable. Nothing was sent.'}
  Assert-OrbyDropActive
  if(-not [OrbyDropUIA]::AcceptPicker([IntPtr]$dialog.Current.NativeWindowHandle)){throw 'The picker did not accept the files. Nothing was sent.'}
  Wait-OrbyDropPickerClosed $Root $Adapter;return
 }
 Assert-OrbyDropActive
 $name.SetValue((@($Files | ForEach-Object {'"'+[IO.Path]::GetFullPath($_)+'"'}) -join ' '))
 Assert-OrbyDropActive
 if((Get-OrbyDropForegroundWindow) -ne $dialog.Current.NativeWindowHandle){throw 'The file picker lost focus. Nothing was sent.'}
 $openAction=[OrbyDropUIA]::InvokeAsync($open,[IntPtr]$dialog.Current.NativeWindowHandle)
 Wait-OrbyDropPickerClosed $Root $Adapter
}
