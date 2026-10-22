Add-Type -Path (Join-Path $PSScriptRoot 'Approval-Worker.cs') -ReferencedAssemblies @('UIAutomationClient','UIAutomationTypes','WindowsBase')
$script:approvalPollAt=[datetime]::MinValue
function Update-OrbyApprovalBridge {
 if($script:approvalReplyTask -and $script:approvalReplyTask.IsCompleted){
  if(-not $script:approvalReplyTask.IsFaulted -and -not $script:approvalReplyTask.IsCanceled){$r=$script:approvalReplyTask.Result;$script:approvalNotice=$r.Message;if($r.Submitted){$script:approvalAnswered=$script:approvalClickedId};if($r.Resolved){$script:approvalRequest=$null}}
  else{$script:approvalNotice='Could not send the response. Please review the request.'}
  $script:approvalReplyTask=$null;$script:approvalPollAt=[datetime]::MinValue
 }
 if($script:approvalPollTask -and $script:approvalPollTask.IsCompleted){
  if(-not $script:approvalPollTask.IsFaulted -and -not $script:approvalPollTask.IsCanceled){$next=$script:approvalPollTask.Result;if($next.Available -and $script:approvalRequest.Id -ne $next.Id){$script:approvalNotice='';$script:approvalAnswered='';$script:approvalChoice=-1};$script:approvalRequest=$next;$script:approvalRequestAt=[datetime]::UtcNow}
  else{$script:approvalRequest=$null;$script:approvalRequestAt=$null}
  $script:approvalPollTask=$null
 }
 if(-not $script:approvalReplyTask -and -not $script:approvalPollTask -and ([datetime]::UtcNow-$script:approvalPollAt).TotalSeconds -ge 2){$script:approvalPollAt=[datetime]::UtcNow;$script:approvalPollTask=[OrbyApprovalWorker]::Poll()}
}
function Update-OrbyApprovalView {
 $c=$script:eventControls;$q=$script:approvalRequest
 $visible=$script:orbyEventMode -eq 'attention' -and $q -and $q.Available
 $question=$visible -and $q.Kind -eq 'question'
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
 $script:approvalClickedId=$q.Id;$script:approvalNotice='Sending your response...'
 $script:approvalReplyTask=if($q.Kind -eq 'question'){[OrbyApprovalWorker]::Answer($q.Id,[int]$script:approvalChoice)}else{[OrbyApprovalWorker]::Respond($q.Id,$Allow)}
 Update-OrbyApprovalView
}
