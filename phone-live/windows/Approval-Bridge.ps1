Add-Type -Path (Join-Path $PSScriptRoot 'Approval-Worker.cs') -ReferencedAssemblies @('UIAutomationClient','UIAutomationTypes','WindowsBase')
$script:approvalPollAt=[datetime]::MinValue
function Get-OrbyApprovalClockKey($Next) {
 $turns=@($script:orbyActiveTasks|Where-Object {-not $_.Provider -or $_.Provider -eq 'chatgpt'}|Sort-Object Id|ForEach-Object {([string]$_.Id)+'|'+([string]$_.Turn)})
 return (@{scope=[string]$Next.Target;kind=[string]$Next.Kind;title=[string]$Next.Title;detail=[string]$Next.Detail;choices=@($Next.Choices);canReply=[bool]$Next.CanReply;turns=$turns}|ConvertTo-Json -Depth 5 -Compress)
}
function Update-OrbyHandoffClock($Next,[datetime]$Now=[datetime]::UtcNow) {
 if(-not $Next -or -not $Next.Available){
  if($script:approvalClockLastSeen -and ($Now-$script:approvalClockLastSeen).TotalSeconds -gt 10){$script:approvalClockKey=$null;$script:approvalClockEpisode=$null;$script:approvalFirstSeen=$null}
  return
 }
 $key=Get-OrbyApprovalClockKey $Next
 if($key -cne $script:approvalClockKey -or -not $script:approvalClockLastSeen -or ($Now-$script:approvalClockLastSeen).TotalSeconds -gt 10){$script:approvalFirstSeen=$Now;$script:approvalClockKey=$key;$script:approvalClockEpisode=[guid]::NewGuid().ToString();$script:approvalNativeRefreshes=0}
 elseif($script:approvalClockNativeId -cne $Next.Id){$script:approvalNativeRefreshes++}
 $script:approvalClockLastSeen=$Now;$script:approvalClockNativeId=$Next.Id
}
function Get-OrbyPhoneCountdown([datetime]$Now=[datetime]::UtcNow) {
 $q=$script:approvalRequest
 if(-not $script:phoneConfig.Enabled -or -not $script:phoneConfig.Approvals -or -not $q -or -not $q.Available -or $q.Kind -notin @('question','permission') -or -not $script:approvalFirstSeen -or $script:approvalAnswered -eq $q.Id){return [pscustomobject]@{Visible=$false;Text='';Hint=''}}
 $left=[int][math]::Max(0,[math]::Ceiling(300-($Now-$script:approvalFirstSeen).TotalSeconds))
 $ready=$q.CanAnswer -and $script:phoneConfig.Trusted.Count -gt 0 -and $script:phoneReadyCount -gt 0 -and $script:phoneConnectedAt -and ($Now-$script:phoneConnectedAt).TotalSeconds -lt 15
 if(-not $ready){return [pscustomobject]@{Visible=$true;Text='Phone paused';Hint='Reply here. Phone handoff needs readable answer controls, a trusted phone with alerts enabled and an online connection.'}}
 if((Test-Path function:Test-OrbyPhoneHandoffDelivered) -and (Test-OrbyPhoneHandoffDelivered)){return [pscustomobject]@{Visible=$true;Text='On your phone';Hint='The phone service has received this question. Open Orby on your phone to answer.'}}
 $label=if($left -gt 0){'Phone in '+[int][math]::Floor($left/60)+':'+($left%60).ToString('00')}else{'Sending to phone...'}
 return [pscustomobject]@{Visible=$true;Text=$label;Hint='Reply on this PC before the countdown ends. An unanswered request moves to your phone after five minutes; the PC card stays until the service receives it.'}
}
function Update-OrbyApprovalBridge {
 if($script:approvalReplyTask -and $script:approvalReplyTask.IsCompleted){
  if(-not $script:approvalReplyTask.IsFaulted -and -not $script:approvalReplyTask.IsCanceled){$r=$script:approvalReplyTask.Result;$script:approvalNotice=$r.Message;if($r.Submitted){$script:approvalAnswered=$script:approvalClickedId;$script:approvalClockKey=$null;$script:approvalClockEpisode=$null;$script:approvalFirstSeen=$null;$script:approvalClockLastSeen=$null};if($r.Submitted){$script:approvalPollTask=$null;$script:approvalRequest=$null;$script:approvalRequestAt=$null;$script:needsInput=$false;$script:needsText='';$script:approvalSentUntil=[datetime]::UtcNow.AddSeconds(8);if(Test-Path function:Set-ChatLogState){Set-ChatLogState 'working' 'Response sent; checking current activity' 'explicit-input-submitted'}}}
  else{$script:approvalNotice='Could not send the response. Please review the request.'}
  $script:approvalReplyTask=$null;$script:approvalPollAt=[datetime]::MinValue
 }
 if($script:approvalPollTask -and $script:approvalPollTask.IsCompleted){
  if(-not $script:approvalPollTask.IsFaulted -and -not $script:approvalPollTask.IsCanceled){$next=$script:approvalPollTask.Result;if($next.Available -and $next.Id -eq $script:approvalAnswered){$next.Available=$false};Update-OrbyHandoffClock $next;if($next.Available -and $script:approvalRequest.Id -ne $next.Id){$script:approvalNotice='';$script:approvalAnswered='';$script:approvalChoice=-1};$script:approvalRequest=$next;$script:approvalRequestAt=[datetime]::UtcNow}
  else{$script:approvalRequest=$null;$script:approvalRequestAt=$null}
  $script:approvalPollTask=$null
 }
 if(-not $script:approvalReplyTask -and -not $script:approvalPollTask -and ([datetime]::UtcNow-$script:approvalPollAt).TotalSeconds -ge 1){$script:approvalPollAt=[datetime]::UtcNow;$script:approvalPollTask=[OrbyApprovalWorker]::Poll()}
}
function Update-OrbyApprovalView {
 $c=$script:eventControls;$q=$script:approvalRequest
 $visible=$script:orbyEventMode -eq 'attention' -and $q -and $q.Available
 $question=$visible -and $q.Kind -eq 'question'
 if($c.EventPhoneCountdown){$clock=Get-OrbyPhoneCountdown;$c.EventPhoneCountdown.Visibility=if($visible -and $clock.Visible){'Visible'}else{'Collapsed'};$c.EventPhoneCountdownText.Text=$clock.Text;$c.EventPhoneCountdown.ToolTip=$clock.Hint}
 $c.EventApprove.Visibility=if($visible -and $q.CanAnswer){'Visible'}else{'Collapsed'}
 $c.EventDeny.Visibility=if($visible -and -not $question){'Visible'}else{'Collapsed'}
 $c.EventOpen.Visibility=if($visible -and -not $question -and $q.CanAnswer){'Collapsed'}else{'Visible'}
 if($c.EventChoices){$c.EventChoices.Visibility=if($question -and $q.CanAnswer){'Visible'}else{'Collapsed'}}
 if($script:orbyEventMode -ne 'attention'){return}
 if($visible){
  $c.EventTitle.Text=$q.Title;$c.EventDetail.Text=$q.Detail;$c.EventDetail.ToolTip=$q.Detail
  $c.EventStatus.Text=if($script:approvalNotice){$script:approvalNotice}elseif($question){'ChatGPT is waiting for your answer'}else{'Your permission is needed'}
  $busy=$script:approvalReplyTask -or $script:approvalAnswered -eq $q.Id
  $c.EventDeny.IsEnabled=-not $busy
  $c.EventApprove.IsEnabled=-not $busy -and (-not $question -or ($script:approvalChoice -ge 0 -and $script:approvalChoice -lt $q.Choices.Length))
  $c.EventApprove.Content=if($script:approvalReplyTask){'Sending...'}elseif($question){'Send answer'}else{'Allow once'}
  if($question -and $c.EventChoices -and $script:approvalChoicesId -ne $q.Id){
   $c.EventChoices.Children.Clear();$script:approvalChoicesId=$q.Id
   for($i=0;$i -lt $q.Choices.Length;$i++){
    $choice=[Windows.Controls.RadioButton]::new();$choice.GroupName='OrbyQuestion';$choice.Foreground=[Windows.Media.Brushes]::White;$choice.Margin='0,4,0,4';$choice.Padding='3';$choice.FontSize=12
    $text=[Windows.Controls.TextBlock]::new();$text.Text=$q.Choices[$i];$text.TextWrapping='Wrap';$choice.Content=$text
    $choice.CommandParameter=$i;$choice.Tag=$q.Id
    $choice.Add_Click({param($sender,$e)if($sender.Tag -eq $script:approvalRequest.Id){$script:approvalChoice=[int]$sender.CommandParameter;Update-OrbyApprovalView}})
    [void]$c.EventChoices.Children.Add($choice)
   }
  }
 }elseif($script:approvalNotice){$c.EventStatus.Text=$script:approvalNotice}
 elseif($script:approvalPollTask){$c.EventStatus.Text='Reading permission request...'}
 else{$c.EventStatus.Text='Permission needs review in ChatGPT';$c.EventOpen.ToolTip=if($q){$q.Status}else{'Waiting for permission controls'}}
}
function Send-OrbyApproval {
 param([bool]$Allow)
 $q=$script:approvalRequest
 if(-not $q -or -not $q.Available -or $script:approvalReplyTask -or $script:approvalAnswered -eq $q.Id){return}
 if($q.Kind -eq 'question' -and (-not $Allow -or -not $q.CanAnswer -or $script:approvalChoice -lt 0 -or $script:approvalChoice -ge $q.Choices.Length)){return}
 $script:approvalPollTask=$null;$script:approvalClickedId=$q.Id;$script:approvalNotice='Sending your response...'
 $script:approvalReplyTask=if($q.Kind -eq 'question'){[OrbyApprovalWorker]::Answer($q.Id,[int]$script:approvalChoice)}else{[OrbyApprovalWorker]::Respond($q.Id,$Allow)}
 Update-OrbyApprovalView
}
