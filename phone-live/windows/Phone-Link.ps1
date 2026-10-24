param([switch]$NoNetwork)
# Explicitly enabled desktop-to-phone link, separate from the withdrawn ChatGPT plugin.
Add-Type -Path (Join-Path $PSScriptRoot 'Phone-Link.cs') -ReferencedAssemblies System.Net.Http,System.Web.Extensions,System.Security
$script:phoneConfigPath=Join-Path $script:logDir 'phone-link.dpapi'
$script:phoneConfig=@{Enabled=$false;Approvals=$false;Origin='';Token='';Trusted=@{}}
try{$saved=[OrbyPhoneClient]::Load($script:phoneConfigPath);if($saved){$c=$saved|ConvertFrom-Json;$script:phoneConfig.Enabled=[bool]$c.Enabled;$script:phoneConfig.Approvals=[bool]$c.Approvals;$script:phoneConfig.Origin=[string]$c.Origin;$script:phoneConfig.Token=[string]$c.Token;foreach($p in $c.Trusted.PSObject.Properties){$script:phoneConfig.Trusted[$p.Name]=[string]$p.Value}}}catch{Write-OrbitLog 'Phone configuration could not be loaded; phone access remains off.'}
if($NoNetwork){$script:phoneConfig.Enabled=$false}
$script:phoneInstance=[guid]::NewGuid().ToString();$script:phoneSequence=0;$script:phoneConsumed=@{};$script:phoneAcks=@();$script:phoneLocalRequest=$null
$script:phoneNoNetwork=[bool]$NoNetwork
$script:phoneConfigStamp=[IO.File]::GetLastWriteTimeUtc($script:phoneConfigPath)
function Save-OrbyPhoneConfig {[OrbyPhoneClient]::Save($script:phoneConfigPath,($script:phoneConfig|ConvertTo-Json -Depth 6 -Compress));$script:phoneConfigStamp=[IO.File]::GetLastWriteTimeUtc($script:phoneConfigPath)}
function Read-OrbyPhoneConfigChange {
 if($script:phoneNoNetwork){return}
 $stamp=[IO.File]::GetLastWriteTimeUtc($script:phoneConfigPath);if($stamp -eq $script:phoneConfigStamp){return}
 try{$saved=[OrbyPhoneClient]::Load($script:phoneConfigPath);if(-not $saved){throw 'Missing phone config'};$c=$saved|ConvertFrom-Json;$trusted=@{};foreach($p in $c.Trusted.PSObject.Properties){$trusted[$p.Name]=[string]$p.Value};if($c.Enabled){$probe=[OrbyPhoneClient]::new([string]$c.Origin,[string]$c.Token,$false);$probe.Dispose()};$script:phoneConfig=@{Enabled=[bool]$c.Enabled;Approvals=[bool]$c.Approvals;Origin=[string]$c.Origin;Token=[string]$c.Token;Trusted=$trusted};$script:phoneConfigStamp=$stamp;Reset-OrbyPhoneClient;if($script:phoneWindow){$script:phoneUi.PhoneOrigin.Text=$script:phoneConfig.Origin;$script:phoneUi.PhoneEnabled.IsChecked=$script:phoneConfig.Enabled;$script:phoneUi.PhoneApprovals.IsChecked=$script:phoneConfig.Approvals;$script:phoneUi.PhoneQr.Source=$null;$script:phoneUi.PhoneInvitation.Text=''}}catch{$script:phoneConfig.Enabled=$false;Reset-OrbyPhoneClient;$script:phoneStatus='Phone setup could not be read. Open Phone access to reconnect.'}
}
function Reset-OrbyPhoneClient {$script:phoneHandoffAckBinding=$null;$script:phoneHandoffAckRevision=$null;if($script:phoneClient){$script:phoneClient.Dispose()};$script:phoneClient=$null;$script:phoneExchange=$null;$script:phoneInstance=[guid]::NewGuid().ToString();$script:phoneSequence=0;$script:phoneLocalRequest=$null;if($script:phoneConfig.Enabled){$script:phoneClient=[OrbyPhoneClient]::new($script:phoneConfig.Origin,$script:phoneConfig.Token,$false)}}
function Get-OrbyPhoneTaskSnapshot {
 $result=@();foreach($id in @(Get-OrbyPairedProviders)){$status=Get-OrbyIndependentStatus $id;foreach($task in @(Get-OrbyProviderTasks $id $status)){
  if($result.Count -ge 64){break};$title=[string]$task.Title;$detail=[string]$task.Action
  foreach($name in @('title','detail')){$value=Get-Variable $name -ValueOnly;$value=[regex]::Replace($value,'(?i)(sk-[A-Za-z0-9_-]{20,}|gh[pousr]_[A-Za-z0-9_]{20,}|Bearer\s+\S+)','[redacted]');Set-Variable $name $value}
  $result+=@{id=([string]$task.Id).Substring(0,[math]::Min(240,([string]$task.Id).Length));provider=$status.Name;state=$(if($task.State -in @('working','attention','idle','error')){$task.State}else{'idle'});title=$title.Substring(0,[math]::Min(240,$title.Length));detail=$detail.Substring(0,[math]::Min(600,$detail.Length))}
 }};return $result
}
function Get-OrbyPhoneReviewText($q){
 $text='ChatGPT'+"`n"+$q.Title+"`n`n"+$q.Detail
 if($q.Kind -eq 'question'){$i=0;foreach($choice in $q.Choices){$text+="`n"+$i+': '+$choice;$i++};$text+="`nCustom response: "+[bool]$q.CanReply};return $text
}
function Test-OrbyPhoneHandoff {
 $q=$script:approvalRequest
 return [bool]($script:phoneConfig.Enabled -and $script:phoneConfig.Approvals -and $script:phoneConfig.Trusted.Count -gt 0 -and $script:phoneReadyCount -gt 0 -and $script:phoneConnectedAt -and ([datetime]::UtcNow-$script:phoneConnectedAt).TotalSeconds -lt 15 -and $q -and $q.Available -and $q.CanAnswer -and $script:approvalAnswered -ne $q.Id -and $script:approvalFirstSeen -and ([datetime]::UtcNow-$script:approvalFirstSeen).TotalSeconds -ge 300)
}
function Test-OrbyPhoneHandoffDelivered {
 return [bool]((Test-OrbyPhoneHandoff) -and $script:phoneLocalRequest -and $script:phoneHandoffAckBinding -ceq $script:phoneLocalRequest.nativeId -and $script:phoneHandoffAckRevision -ceq $script:phoneLocalRequest.revision)
}
function Get-OrbyPhoneReviewWaiting {
 if(-not $script:phoneConfig.Enabled -or -not $script:phoneConfig.Approvals){return $false}
 $q=$script:approvalRequest
 return [bool](($q -and $q.Available -and $q.Kind -in @('question','permission')) -or ($script:approvalFirstSeen -and $script:approvalClockLastSeen -and ([datetime]::UtcNow-$script:approvalClockLastSeen).TotalSeconds -lt 10))
}
function Confirm-OrbyPhoneHandoffResponse($Response) {
 if(-not $script:phoneLocalRequest -or $script:phoneLocalRequest.kind -eq 'stop'){return}
 foreach($received in @($Response.requests)){if($received -and $received.id -ceq $script:phoneLocalRequest.id -and $received.status -eq 'pending'){$script:phoneHandoffAckBinding=$script:phoneLocalRequest.nativeId;$script:phoneHandoffAckRevision=$script:phoneLocalRequest.revision}}
}
function Write-OrbyPhoneHandoffStatus {
 if(-not $script:logDir -or ($script:phoneDiagnosticAt -and ([datetime]::UtcNow-$script:phoneDiagnosticAt).TotalSeconds -lt 5)){return}
 $script:phoneDiagnosticAt=[datetime]::UtcNow;$q=$script:approvalRequest
 $age=if($script:approvalFirstSeen){[int]([datetime]::UtcNow-$script:approvalFirstSeen).TotalSeconds}else{0}
 $fresh=$script:phoneConnectedAt -and ([datetime]::UtcNow-$script:phoneConnectedAt).TotalSeconds -lt 15
 $reason=if(-not $script:phoneConfig.Enabled){'sharing-off'}elseif(-not $script:phoneConfig.Approvals){'responses-off'}elseif($script:phoneConfig.Trusted.Count -eq 0){'phone-not-trusted'}elseif(-not $fresh){'relay-offline'}elseif($script:phoneReadyCount -lt 1){'phone-alerts-not-ready'}elseif(-not $q -or -not $q.Available){'waiting-for-accessible-question'}elseif(-not $q.CanAnswer){'answer-controls-unavailable'}elseif($script:approvalAnswered -eq $q.Id){'already-answered'}elseif($age -lt 300){'waiting-five-minutes'}else{'handoff-ready'}
 # Local troubleshooting state contains no prompt, choices, answer, key or phone identifier.
 try{@{checkedAt=[datetime]::UtcNow.ToString('o');reason=$reason;questionAgeSeconds=$age;nativeRefreshes=[int]$script:approvalNativeRefreshes;requestAvailable=[bool]($q -and $q.Available);canAnswer=[bool]($q -and $q.CanAnswer);kind=$(if($q){[string]$q.Kind}else{''});readerStatus=$(if($q -and $q.Available -and $q.CanAnswer){'Answer controls available'}elseif($q){[string]$q.Status}else{''});phoneReadyCount=[int]$script:phoneReadyCount;lastResponse=$script:phoneLastOutcome;relayFresh=[bool]$fresh}|ConvertTo-Json -Compress|Set-Content -LiteralPath (Join-Path $script:logDir 'phone-handoff-status.json') -Encoding UTF8}catch{}
}
function Get-OrbyPhoneRequestBinding($Request) {
 if($Request.Kind -ne 'question'){return [string]$Request.Id}
 # A remounted accessibility control is still the same logical question only
 # while its full text, choices, app window and journal turn remain unchanged.
 if($script:approvalClockEpisode -and $script:approvalClockKey -ceq (Get-OrbyApprovalClockKey $Request)){return [string]$script:approvalClockEpisode}
 return ''
}
function Get-OrbyPhoneActiveTaskToken {
 $tasks=@($script:orbyActiveTasks | Where-Object {$_.State -eq 'working' -and $_.Turn -and (-not $_.Provider -or $_.Provider -eq 'chatgpt')})
 if($tasks.Count -ne 1){return ''};return [OrbyPhoneClient]::Hash(([string]$tasks[0].Id)+'|'+([string]$tasks[0].Turn)+'|'+([string]$tasks[0].Started))
}
function Get-OrbyPhoneStopRequest {
 $token=Get-OrbyPhoneActiveTaskToken;if(-not $token){$script:phoneStopRequest=$null;return $null}
 $task=@($script:orbyActiveTasks|Where-Object {$_.State -eq 'working' -and $_.Turn -and (-not $_.Provider -or $_.Provider -eq 'chatgpt')})[0]
 if($script:phoneStopPoll -and $script:phoneStopPoll.IsCompleted){if(-not $script:phoneStopPoll.IsFaulted -and $script:phoneStopPollToken -ceq $token){$q=$script:phoneStopPoll.Result;if($q.Available){$q|Add-Member NoteProperty NativeStopId $q.Id -Force;$q|Add-Member NoteProperty TaskToken $token -Force;$q.Id=[OrbyPhoneClient]::Hash($q.Id+'|'+$token)};$script:phoneStopRequest=$q;$script:phoneStopAt=[datetime]::UtcNow};$script:phoneStopPoll=$null}
 if(-not $script:phoneStopPoll){$script:phoneStopPollToken=$token;$script:phoneStopPoll=[OrbyApprovalWorker]::PollStop([string]$task.Title)}
 if($script:phoneStopRequest -and $script:phoneStopRequest.Available -and $script:phoneStopRequest.TaskToken -ceq $token -and ([datetime]::UtcNow-$script:phoneStopAt).TotalSeconds -lt 5){return $script:phoneStopRequest};return $null
}
function Get-OrbyPhoneRequest {
 if($script:phoneSubmission){return $script:phoneSubmission.Request}
 $q=$script:approvalRequest;$stop=$false
 if(( -not $q -or -not $q.Available) -and $script:phoneConfig.Approvals){$q=Get-OrbyPhoneStopRequest;$stop=$true}
 $observedAt=if($stop){$script:phoneStopAt}else{$script:approvalRequestAt}
 $eligible=($stop -or (Test-OrbyPhoneHandoff)) -and $q -and $q.Kind -in @('permission','question','stop') -and $observedAt -and ([datetime]::UtcNow-$observedAt).TotalSeconds -lt 5
 if(-not $eligible){$script:phoneLocalRequest=$null;return $null}
 $binding=Get-OrbyPhoneRequestBinding $q
 if(-not $binding -or $script:phoneConsumed.ContainsKey($binding)){return $null}
 $review=Get-OrbyPhoneReviewText $q
 if($review.Length -gt 8000 -or $review -match '(?i)BEGIN .*PRIVATE KEY|sk-[A-Za-z0-9_-]{20,}|Bearer\s+\S+'){$script:phoneLocalRequest=$null;return $null}
 $revision=[OrbyPhoneClient]::Hash($review)
 if(-not $script:phoneLocalRequest -or $script:phoneLocalRequest.nativeId -cne $binding -or $script:phoneLocalRequest.revision -cne $revision -or ([datetime]::UtcNow-$script:phoneRequestStarted).TotalSeconds -ge 120){$script:phoneLocalRequest=@{id=[guid]::NewGuid().ToString();nativeId=$binding;provider='ChatGPT';kind=[string]$q.Kind;choices=@($q.Choices);canReply=[bool]$q.CanReply;handoff=(-not $stop);reviewText=$review;revision=$revision};$script:phoneRequestStarted=[datetime]::UtcNow}
 return $script:phoneLocalRequest
}
function Invoke-OrbyPhoneDecision($d){
 $r=$script:phoneLocalRequest;$q=if($r.kind -eq 'stop'){$script:phoneStopRequest}else{$script:approvalRequest};$observedAt=if($r.kind -eq 'stop'){$script:phoneStopAt}else{$script:approvalRequestAt}
 if(-not $script:phoneConfig.Enabled -or -not $script:phoneConfig.Approvals -or $script:approvalReplyTask -or -not $r -or -not $q -or -not $q.Available -or $q.Kind -notin @('permission','question','stop') -or (Get-OrbyPhoneRequestBinding $q) -cne $r.nativeId -or $d.id -cne $r.id -or $d.nativeId -cne $r.nativeId -or $d.revision -cne $r.revision -or $script:phoneConsumed.ContainsKey($r.nativeId)){return}
 $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();$key=$script:phoneConfig.Trusted[[string]$d.deviceId]
 $currentReview=Get-OrbyPhoneReviewText $q
 if(-not $q.CanAnswer -or [OrbyPhoneClient]::Hash($currentReview) -cne $r.revision -or -not $key -or [long]$d.expiresAt -le $now -or [long]$d.expiresAt -gt ([DateTimeOffset]$script:phoneRequestStarted).ToUnixTimeSeconds()+135 -or ([datetime]::UtcNow-$script:phoneRequestStarted).TotalSeconds -ge 120 -or ([datetime]::UtcNow-$observedAt).TotalSeconds -ge 5){return}
 $verified=if($d.method -eq 'webauthn'){[OrbyPhoneClient]::VerifyWeb($key,[string]$d.deviceId,[string]$d.id,[string]$d.revision,[string]$d.decision,[string]$d.nonce,[long]$d.expiresAt,[string]$d.signature,[string]$script:phoneConfig.Origin,[string]$d.clientDataJSON,[string]$d.authenticatorData)}else{[OrbyPhoneClient]::Verify($key,[string]$d.deviceId,[string]$d.id,[string]$d.revision,[string]$d.decision,[string]$d.nonce,[long]$d.expiresAt,[string]$d.signature)}
 if(-not $verified){return}
 $choice=-1;$answer=[string]$d.answer
 if($q.Kind -eq 'stop'){if($d.decision -ne 'stop' -or $q.TaskToken -cne (Get-OrbyPhoneActiveTaskToken)){return}}
 elseif($q.Kind -eq 'permission'){if($d.decision -notin @('allow','deny')){return}}
 elseif($d.decision -match '^choice:([0-7])$'){$choice=[int]$Matches[1];if($choice -ge $q.Choices.Length){return}}
 elseif($d.decision -like 'reply:*'){if(-not $q.CanReply -or [string]::IsNullOrWhiteSpace($answer) -or $answer.Length -gt 2000 -or $d.decision -cne ('reply:'+ [OrbyPhoneClient]::Hash($answer))){return}}
 else{return}
 $script:phoneConsumed[$r.nativeId]=$true;$script:approvalClickedId=$q.Id;$script:approvalNotice='Sending the trusted phone response...'
 $script:approvalPollTask=$null;$script:approvalReplyTask=if($q.Kind -eq 'stop'){[OrbyApprovalWorker]::Stop($q.NativeStopId,$q.Target)}elseif($q.Kind -eq 'permission'){[OrbyApprovalWorker]::Respond($q.Id,($d.decision -eq 'allow'))}elseif($choice -ge 0){[OrbyApprovalWorker]::Answer($q.Id,$choice)}else{[OrbyApprovalWorker]::Reply($q.Id,$answer)};$script:phoneSubmission=@{Id=$r.id;Task=$script:approvalReplyTask;Request=$r};Update-OrbyApprovalView
}
function Invoke-OrbyPhoneTick {
 Read-OrbyPhoneConfigChange
 Write-OrbyPhoneHandoffStatus
 if($script:phoneSubmission -and $script:phoneSubmission.Task.IsCompleted){$result='uncertain';if(-not $script:phoneSubmission.Task.IsFaulted){$reply=$script:phoneSubmission.Task.Result;$result=if($reply.Resolved){'resolved'}elseif($reply.Submitted){'submitted'}else{'stale'}};$script:phoneLastOutcome=@{at=[datetime]::UtcNow.ToString('o');result=$result;message=$(if($reply){[string]$reply.Message}else{'Native response could not be confirmed'})};$script:phoneAcks+=@{id=$script:phoneSubmission.Id;result=$result};$script:phoneSubmission=$null}
 if(-not $script:phoneConfig.Enabled){return}
 try{
  if(-not $script:phoneClient){Reset-OrbyPhoneClient}
  if($script:phoneExchange){if(-not $script:phoneExchange.IsCompleted){return};$pending=$script:phoneExchange;$script:phoneExchange=$null;if($pending.IsFaulted){throw 'Phone service unavailable'};$response=$pending.Result|ConvertFrom-Json;Confirm-OrbyPhoneHandoffResponse $response;$script:phoneConnectedAt=[datetime]::UtcNow;$script:phoneReadyCount=[int]$response.phoneReadyCount;$sentIds=@($script:phoneSentAcks|ForEach-Object {$_.id});$script:phoneAcks=@($script:phoneAcks|Where-Object {$_.id -notin $sentIds});foreach($d in @($response.decisions)){if($d){Invoke-OrbyPhoneDecision $d}};$script:phoneStatus='PC feed connected · '+$response.phoneCount+' trusted phone(s)'}
  $script:phoneSequence++;$body=@{instance=$script:phoneInstance;sequence=$script:phoneSequence;tasks=@(Get-OrbyPhoneTaskSnapshot);request=(Get-OrbyPhoneRequest);allowRequests=[bool]$script:phoneConfig.Approvals;reviewWaiting=(Get-OrbyPhoneReviewWaiting);presence=([OrbyPhoneClient]::Presence()|ConvertFrom-Json);acks=@($script:phoneAcks)}|ConvertTo-Json -Depth 7 -Compress
  $script:phoneSentAcks=@($script:phoneAcks);$script:phoneExchange=$script:phoneClient.Exchange($script:phoneInstance,$body)
 }catch{$script:phoneStatus='Phone feed offline. Local approvals still work.'}
 if($script:phoneWindow -and $script:phoneWindow.IsVisible){$script:phoneUi.PhoneMessage.Text=$script:phoneStatus}
}
function Start-OrbyPhoneUiRequest([string]$Method,[string]$Path,$Body,[string]$Action){
 if($script:phoneUiTask){return};if(-not $script:phoneClient){throw 'Save and enable the relay connection first.'}
 $script:phoneUiTask=$script:phoneClient.Request($Method,$Path,$(if($null -ne $Body){$Body|ConvertTo-Json -Compress}else{$null}));$script:phoneUiAction=$Action;$script:phoneUi.PhoneMessage.Text='Connecting...'
}
function Set-OrbyPhoneInvitation($Reply){
 $script:phoneUi.PhoneInvitation.Text=$Reply.invite;$script:phoneUi.PhoneQr.Source=$null;$script:phoneUi.PhoneQr.Visibility='Collapsed'
 if($Reply.qr -and ([string]$Reply.qr).StartsWith('data:image/png;base64,') -and $Reply.qr.Length -lt 150000){$bytes=[Convert]::FromBase64String($Reply.qr.Substring(22));$stream=[IO.MemoryStream]::new($bytes);try{$image=[Windows.Media.Imaging.BitmapImage]::new();$image.BeginInit();$image.CacheOption='OnLoad';$image.DecodePixelWidth=280;$image.StreamSource=$stream;$image.EndInit();$image.Freeze();$script:phoneUi.PhoneQr.Source=$image;$script:phoneUi.PhoneQr.Visibility='Visible'}finally{$stream.Dispose()}}
 $script:phoneUi.PhoneMessage.Text='Scan with your iPhone camera, connect with a passkey, then compare the fingerprint. Invitation expires in five minutes.'
}
function Update-OrbyPhoneUiTask {
 if(-not $script:phoneUiTask -or -not $script:phoneUiTask.IsCompleted){return};$t=$script:phoneUiTask;$script:phoneUiTask=$null
 try{if($t.IsFaulted){throw 'Connection failed; check the relay address and PC code.'};$r=$t.Result|ConvertFrom-Json
  switch($script:phoneUiAction){
   invite {Set-OrbyPhoneInvitation $r}
   phones {$script:phoneUi.PhoneDevices.Children.Clear();foreach($p in $r.phones){$row=[Windows.Controls.StackPanel]::new();$row.Margin='0,0,0,12';$label=[Windows.Controls.TextBlock]::new();$label.Text=$p.name+' · '+$p.fingerprint+$(if($p.active){' · connected'}else{' · awaiting PC confirmation'});[void]$row.Children.Add($label);$actions=[Windows.Controls.StackPanel]::new();$actions.Orientation='Horizontal'
    $trust=[Windows.Controls.Button]::new();$trust.Content='Fingerprints match — trust phone';$trust.IsEnabled=(-not $p.active -or $script:phoneConfig.Trusted[$p.id] -cne $p.publicKey);$trust.Tag=$p;$trust.Add_Click({param($sender,$e)$p=$sender.Tag;if([OrbyPhoneClient]::Fingerprint($p.publicKey) -cne $p.fingerprint){throw 'Phone fingerprint mismatch'};$script:phoneConfig.Trusted[$p.id]=$p.publicKey;Save-OrbyPhoneConfig;Start-OrbyPhoneUiRequest 'POST' ('/desktop/phones/'+$p.id+'/trust') @{fingerprint=$p.fingerprint} 'trusted'});[void]$actions.Children.Add($trust)
    $revoke=[Windows.Controls.Button]::new();$revoke.Content='Revoke';$revoke.Tag=$p.id;$revoke.Add_Click({param($sender,$e)$id=[string]$sender.Tag;$script:phoneConfig.Trusted.Remove($id);Save-OrbyPhoneConfig;Start-OrbyPhoneUiRequest 'DELETE' ('/desktop/phones/'+$id) $null 'revoked'});[void]$actions.Children.Add($revoke);[void]$row.Children.Add($actions);[void]$script:phoneUi.PhoneDevices.Children.Add($row)}}
   trusted {Start-OrbyPhoneUiRequest 'GET' '/desktop/phones' $null 'phones'}
   revoked {Start-OrbyPhoneUiRequest 'GET' '/desktop/phones' $null 'phones'}
   default {$script:phoneUi.PhoneMessage.Text='Phone access updated. Refresh the list to check it.'}
  }
 }catch{$script:phoneUi.PhoneMessage.Text=$_.Exception.Message}
}
function Show-OrbyPhoneLink {
 if($script:phoneWindow){$script:phoneWindow.Activate()|Out-Null;return}
 [xml]$x=Get-Content (Join-Path $PSScriptRoot 'Phone-Link.xaml') -Raw;$script:phoneWindow=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($x));$script:phoneUi=@{};foreach($m in [regex]::Matches($x.OuterXml,'x:Name="([^"]+)"')){$script:phoneUi[$m.Groups[1].Value]=$script:phoneWindow.FindName($m.Groups[1].Value)}
 Set-OrbyQuietScrollbars $script:phoneWindow;$u=$script:phoneUi;$u.PhoneEnabled.IsChecked=$script:phoneConfig.Enabled;$u.PhoneApprovals.IsChecked=$script:phoneConfig.Approvals;$u.PhoneOrigin.Text=$script:phoneConfig.Origin
 $u.PhoneSave.Add_Click({try{$secret=if($script:phoneUi.PhoneSecret.Password){$script:phoneUi.PhoneSecret.Password}else{$script:phoneConfig.Token};$origin=$script:phoneUi.PhoneOrigin.Text.Trim().TrimEnd('/');$enabled=[bool]$script:phoneUi.PhoneEnabled.IsChecked;if($enabled){$probe=[OrbyPhoneClient]::new($origin,$secret,$false);$probe.Dispose()};if($origin -cne $script:phoneConfig.Origin -or $secret -cne $script:phoneConfig.Token){$script:phoneConfig.Trusted=@{}};$script:phoneConfig.Origin=$origin;$script:phoneConfig.Token=$secret;$script:phoneConfig.Enabled=$enabled;$script:phoneConfig.Approvals=[bool]$script:phoneUi.PhoneApprovals.IsChecked;Save-OrbyPhoneConfig;Reset-OrbyPhoneClient;$script:phoneUi.PhoneSecret.Password='';$script:phoneUi.PhoneMessage.Text='Saved. Phone access is '+$(if($enabled){'on; confirm each phone below.'}else{'off.'})}catch{$script:phoneUi.PhoneMessage.Text=$_.Exception.Message}})
 $u.PhoneInvite.Add_Click({try{Start-OrbyPhoneUiRequest 'POST' '/desktop/invite' @{} 'invite'}catch{$script:phoneUi.PhoneMessage.Text=$_.Exception.Message}});$u.PhoneRefresh.Add_Click({try{Start-OrbyPhoneUiRequest 'GET' '/desktop/phones' $null 'phones'}catch{$script:phoneUi.PhoneMessage.Text=$_.Exception.Message}});$u.PhoneClose.Add_Click({$script:phoneWindow.Close()});$script:phoneWindow.Add_Closed({$script:phoneWindow=$null;$script:phoneUi=@{}});$script:phoneWindow.Show()
}
$script:phoneTimer=[Windows.Threading.DispatcherTimer]::new();$script:phoneTimer.Interval=[timespan]::FromSeconds(3);$script:phoneTimer.Add_Tick({Invoke-OrbyPhoneTick;Update-OrbyPhoneUiTask});$script:phoneTimer.Start()
$phoneButton=[Windows.Controls.Button]::new();$phoneButton.Content='Phone access';$phoneButton.Height=36;$phoneButton.Margin='6,0,0,0';$phoneButton.Add_Click({Invoke-OrbySafeAction {Show-OrbyPhoneLink} 'Phone access'});[void]$script:compactMenuControls.MoreSettings.Parent.Children.Add($phoneButton)
$window.Add_Closed({$script:phoneTimer.Stop();if($script:phoneClient){$script:phoneClient.Dispose()};if($script:phoneWindow){$script:phoneWindow.Close()}})
