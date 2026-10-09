Add-Type -Path (Join-Path $PSScriptRoot 'Approval-Worker.cs') -ReferencedAssemblies @('UIAutomationClient','UIAutomationTypes','WindowsBase')
$script:approvalPollAt=[datetime]::MinValue
function Update-OrbyApprovalBridge {
 if($script:approvalReplyTask -and $script:approvalReplyTask.IsCompleted){
  if(-not $script:approvalReplyTask.IsFaulted){$r=$script:approvalReplyTask.Result;$script:approvalNotice=$r.Message;if($r.Submitted){$script:approvalAnswered=$script:approvalClickedId};if($r.Resolved){$script:approvalRequest=$null}}
  else{$script:approvalNotice='Could not send the response. Please review the request.'}
  $script:approvalReplyTask=$null;$script:approvalPollAt=[datetime]::MinValue
 }
 if($script:approvalPollTask -and $script:approvalPollTask.IsCompleted){
  if(-not $script:approvalPollTask.IsFaulted){$next=$script:approvalPollTask.Result;if($next.Available -and $script:approvalRequest.Id -ne $next.Id){$script:approvalNotice='';$script:approvalAnswered=''};$script:approvalRequest=$next}
  $script:approvalPollTask=$null
 }
 if(-not $script:approvalReplyTask -and -not $script:approvalPollTask -and ([datetime]::UtcNow-$script:approvalPollAt).TotalSeconds -ge 2){$script:approvalPollAt=[datetime]::UtcNow;$script:approvalPollTask=[OrbyApprovalWorker]::Poll()}
}
function Update-OrbyApprovalView {
 $c=$script:eventControls;$q=$script:approvalRequest
 $visible=$script:orbyEventMode -eq 'attention' -and $q -and $q.Available
 $c.EventApprove.Visibility=$c.EventDeny.Visibility=if($visible){'Visible'}else{'Collapsed'}
 $c.EventOpen.Visibility=if($visible){'Collapsed'}else{'Visible'}
 if($script:orbyEventMode -ne 'attention'){return}
 if($visible){
  $c.EventTitle.Text=$q.Title;$c.EventDetail.Text=$q.Detail;$c.EventDetail.ToolTip=$q.Detail
  $c.EventStatus.Text=if($script:approvalNotice){$script:approvalNotice}else{'Your permission is needed'}
  $busy=$script:approvalReplyTask -or $script:approvalAnswered -eq $q.Id
  $c.EventApprove.IsEnabled=$c.EventDeny.IsEnabled=-not $busy
  $c.EventApprove.Content=if($script:approvalReplyTask){'Sending...'}else{'Allow once'}
 }elseif($script:approvalNotice){$c.EventStatus.Text=$script:approvalNotice}
 elseif($script:approvalPollTask){$c.EventStatus.Text='Reading permission request...'}
 else{$c.EventStatus.Text='Permission needs review in ChatGPT';$c.EventOpen.ToolTip=if($q){$q.Status}else{'Waiting for permission controls'}}
}
function Send-OrbyApproval {
 param([bool]$Allow)
 $q=$script:approvalRequest
 if(-not $q -or -not $q.Available -or $script:approvalReplyTask -or $script:approvalAnswered -eq $q.Id){return}
 $script:approvalClickedId=$q.Id;$script:approvalNotice='Sending your response...'
 $script:approvalReplyTask=[OrbyApprovalWorker]::Respond($q.Id,$Allow)
 Update-OrbyApprovalView
}
