$script:normalChatLastWorking = $false
$script:normalChatState = 'idle'
$script:normalChatUntil = [datetime]::MinValue
$script:normalChatActivity = ''
function Update-OrbyNormalChatTracker {
 param($Chat,$Snapshot)
 $now=Get-Date
 if(-not $Chat -or $Snapshot.Mode -ne 'CHAT'){return $false}
 if(-not [string]::IsNullOrWhiteSpace($Snapshot.InputRequest)){
  $script:normalChatLastWorking=$true;$script:normalChatState='attention';$script:normalChatUntil=[datetime]::MinValue
 }elseif($Snapshot.Working){
  $script:normalChatLastWorking=$true;$script:normalChatState='working';$script:normalChatUntil=[datetime]::MinValue
  $script:normalChatActivity=if($Snapshot.Activity){$Snapshot.Activity}else{'Generating response'}
 }elseif($Snapshot.Failure -and $script:normalChatLastWorking){
  $script:normalChatLastWorking=$false;$script:normalChatState='error';$script:normalChatUntil=$now.AddSeconds(5)
 }elseif($Snapshot.Stopped -and $script:normalChatLastWorking){
  $script:normalChatLastWorking=$false;$script:normalChatState='stopped';$script:normalChatUntil=$now.AddSeconds(3)
 }elseif(-not [string]::IsNullOrWhiteSpace($Snapshot.InputRequest) -and $script:normalChatLastWorking){
  $script:normalChatState='attention';$script:normalChatUntil=[datetime]::MinValue
 }elseif($script:normalChatLastWorking){
  $script:normalChatLastWorking=$false;$script:normalChatState='success';$script:normalChatUntil=$now.AddSeconds(4)
 }elseif($script:normalChatUntil -ne [datetime]::MinValue -and $now -gt $script:normalChatUntil){
  $script:normalChatState='idle';$script:normalChatUntil=[datetime]::MinValue
 }
 return ($script:normalChatState -ne 'idle')
}
function Show-OrbyNormalChatState {
 param($Snapshot)
 switch($script:normalChatState){
  working {Set-OrbitState 'normal-working' 'ChatGPT is working' $script:normalChatActivity 'LIVE' '#5DFF8B' 'Normal ChatGPT' 'Generating a response' 'CHAT' $true 'working'}
  attention {Set-OrbitState 'normal-attention' 'ChatGPT needs you' $Snapshot.InputRequest 'NEED' '#FFC65C' 'Normal ChatGPT input needed' 'Waiting for your answer' 'CHAT' $false 'attention'}
  success {Set-OrbitState 'normal-success' 'ChatGPT finished' 'Response complete' 'DONE' '#78FFAE' 'Normal ChatGPT finished' 'Regular ChatGPT response finished' 'CHAT' $false 'success'}
  stopped {Set-OrbitState 'normal-stopped' 'ChatGPT stopped' 'Generation stopped' 'STOP' '#A0A0A0' 'Normal ChatGPT stopped' 'Regular ChatGPT response stopped' 'CHAT' $false 'stopped'}
  error {Set-OrbitState 'normal-error' 'ChatGPT error' 'Response failed' 'FAIL' '#FF6969' 'Normal ChatGPT error' 'Regular ChatGPT response failed' 'CHAT' $false 'error'}
 }
}
