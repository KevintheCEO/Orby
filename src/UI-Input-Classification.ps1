function Get-OrbyUiInputRequest {
 param([string[]]$Names,[object[]]$Buttons)
 # Chat history and scheduler notifications are content, not blocking controls.
 # Never infer approval from a question mark, 'please confirm', or Continue alone.
 $labels=@($Buttons | ForEach-Object {([string]$_.Name).Trim()})
 $allow=@($labels | Where-Object {$_ -match '(?i)^allow(?: once)?(?:\s+[\u21B5\u23CE])?$'})
 $deny=@($labels | Where-Object {$_ -match '(?i)^deny(?:\s+esc)?$'})
 if($allow.Count -eq 1 -and $deny.Count -eq 1){
  foreach($name in $Names){if($name -match '(?i)^Allow\s+(?:ChatGPT|Codex)\s+to\s+'){return $name}}
 }
 # A dedicated input form must expose both a waiting-state marker and a submit action.
 $submit=@($labels | Where-Object {$_ -match '(?i)^(submit answers?|submit response|send answers?)$'})
 if($submit.Count -gt 0){foreach($name in $Names){if($name -match '(?i)^(?:ChatGPT\s+)?(?:needs your input|waiting for your (?:input|response|answer))\b'){return $name}}}
 return ''
}
function Apply-OrbyBlockingInput {
 param($Snapshot,$Request,[bool]$Fresh=$false)
 # An actual on-screen form outranks the background spinner and a journal's LIVE flag.
 if($Fresh -and $Request -and $Request.Available){
  $Snapshot.InputRequest=$Request.Title;$Snapshot.Working=$false
  $script:needsInput=$true;$script:needsText=$Request.Title
  Set-ChatLogState 'attention' $(if($Request.Kind -eq 'question'){'ChatGPT is waiting for your answer'}else{'ChatGPT needs your permission'}) 'verified-input-card'
 }
}
