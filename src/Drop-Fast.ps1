function Get-OrbyDropNodes($Root){ return [OrbyDropTransfer]::Nodes($Root) }
function Find-ChatButton($Root,[string]$Pattern){
 foreach($node in Get-OrbyDropNodes $Root){if(-not $node.Offscreen -and $node.Enabled -and ($node.Name -match $Pattern -or $node.Help -match $Pattern) -and (Get-OrbyControlAction $node.Element)){return $node.Element}}
 return $null
}
function Find-ChatComposer($Root){
 $ranked=@(foreach($node in Get-OrbyDropNodes $Root){
  if($node.Offscreen -or -not $node.Enabled -or $node.Type -eq [Windows.Automation.ControlType]::Text){continue}
  $rank=Get-OrbyComposerRank $node.Name $node.Id $node.Class
  if($rank -gt 0){if($node.Type -eq [Windows.Automation.ControlType]::Edit){$rank+=20};[pscustomobject]@{Node=$node;Rank=$rank}}
 })
 foreach($candidate in $ranked | Sort-Object Rank -Descending){$element=$candidate.Node.Element;$vp=$null;$tp=$null;if(($element.TryGetCurrentPattern([Windows.Automation.ValuePattern]::Pattern,[ref]$vp) -and -not $vp.Current.IsReadOnly) -or $element.TryGetCurrentPattern([Windows.Automation.TextPattern]::Pattern,[ref]$tp)){return $element}}
 throw 'The AI message box is not accessible yet. Sign in or open a new chat, then retry.'
}
function Find-OrbyNewChat($Root,[string]$Provider=''){
 foreach($node in Get-OrbyDropNodes $Root){
  if($node.Offscreen -or -not $node.Enabled -or -not (Test-OrbyNewChatLabel $node.Name $node.Help $node.Id $Provider)){continue}
  $element=$node.Element
  for($i=0;$i -lt 3 -and $element;$i++){$action=Get-OrbyControlAction $element;if($action){return $element};$element=[Windows.Automation.TreeWalker]::ControlViewWalker.GetParent($element)}
 }
 return $null
}
function Get-OrbyDropComposerScope($Composer){
 $scope=[Windows.Automation.TreeWalker]::ControlViewWalker.GetParent($Composer)
 for($depth=0;$scope -and $depth -lt 10;$depth++){
  if($scope.Current.ControlType -in @([Windows.Automation.ControlType]::Document,[Windows.Automation.ControlType]::Window)){break}
  $nodes=@(Get-OrbyDropNodes $scope)
  if(@($nodes | Where-Object {-not $_.Offscreen -and $_.Name -match '(?i)^(Open upload file menu|Add attachments|Add files|Attach|Upload & tools)(\b|$)'}).Count){return $scope}
  $scope=[Windows.Automation.TreeWalker]::ControlViewWalker.GetParent($scope)
 }
 throw 'The attachment area could not be verified. Nothing was sent.'
}
function Assert-OrbyDropNoDraftAttachments($Composer){
 $scope=Get-OrbyDropComposerScope $Composer
 foreach($node in Get-OrbyDropNodes $scope){if($node.Offscreen){continue}
  if(($node.Type -eq [Windows.Automation.ControlType]::Button -and ($node.Name -match '(?i)\.[a-z][a-z0-9]{0,9}$' -or $node.Name -match '(?i)^(remove|delete)\s+(file|attachment|image|photo)')) -or $node.Class -match '(?i)file-thumbnail|attachment-chip|file-chip|(?:^|\s)file-preview-container(?:\s|$)'){
   throw 'The new-chat page has an unsent attachment draft. Clear that draft in the selected app, then retry. Nothing was added or sent.'
  }
 }
}
function Get-OrbyDropAttachmentState($Root,$Composer,[string[]]$Files){
 $scope=Get-OrbyDropComposerScope $Composer
 $nodes=@(Get-OrbyDropNodes $scope | Where-Object {-not $_.Offscreen})
 $matched=@{};$tokens=[Collections.Generic.List[string]]::new();$busy=$false;$errorText=''
 foreach($node in $nodes){
  if($node.Type -eq [Windows.Automation.ControlType]::ProgressBar -or $node.Class -match '(?i)(?:^|\s)(?:animate-spin|upload-spinner|loading-spinner)(?:\s|$)' -or $node.Name -match '(?i)^(?:Uploading(?:\b|\s)|Processing file(?:\b|\s)|[0-9]{1,2}\s*%)'){$busy=$true}
  if($node.Type -ne [Windows.Automation.ControlType]::Edit -and $node.Name -match '(?i)^(?:upload failed|failed to upload|file too large|unsupported file)'){$errorText='The AI reported an attachment error. Nothing was sent.'}
  $label=$node.Name -replace '(?i)^Remove\s+(?:file\s+)?',''
  $matches=@($Files | Where-Object {Test-OrbyDropPreviewLabel $label $_ $adapter.Id})
  if($matches.Count -eq 1){$matched[[IO.Path]::GetFileName($matches[0])]=$true;$tokens.Add(($node.Element.GetRuntimeId() -join ','))}
 }
 # Gemini clips its accessible text even though the parent file card is visible.
 # Read hidden labels only within an observed visible attachment container.
 foreach($card in $nodes | Where-Object {$_.Class -match '(?:^|\s)file-preview-container(?:\s|$)'}){
  $labels=@(Get-OrbyDropNodes $card.Element | Where-Object {$_.Type -eq [Windows.Automation.ControlType]::Text})
  $filesHere=@($Files | Where-Object {$file=$_;@($labels | Where-Object {Test-OrbyDropPreviewLabel $_.Name $file}).Count -gt 0})
  if($filesHere.Count -eq 1){$matched[[IO.Path]::GetFileName($filesHere[0])]=$true;$tokens.Add(($card.Element.GetRuntimeId() -join ','))}
 }
 $missing=@($Files | Where-Object {-not $matched[[IO.Path]::GetFileName($_)]})
 return [pscustomobject]@{Ready=(-not $missing.Count -and -not $busy -and -not $errorText);Count=$matched.Count;Busy=$busy;Error=$errorText;Tokens=$tokens.ToArray();Scope=$scope}
}
function Add-OrbyDropFilesDirect($Root,$Adapter,$Composer,[string[]]$Files){
 Assert-OrbyDropTarget $Root $Adapter
 Paste-OrbyFiles $Composer $Files $script:chatHwnd
}

function Set-OrbyDropStage([string]$Text){
 Assert-OrbyDropActive;$script:stage=$Text
 if($Operation){$Operation.Stage=$Text;$Operation.Timings=@($Operation.Timings | Where-Object {$null -ne $_})+@([pscustomobject]@{Stage=$Text;AtMs=[math]::Round(([datetime]::UtcNow-$Operation.Started).TotalMilliseconds)})}
}
