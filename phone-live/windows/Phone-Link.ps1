param([switch]$NoNetwork)
# Explicitly enabled desktop-to-phone link, separate from the withdrawn ChatGPT plugin.
Add-Type -Path (Join-Path $PSScriptRoot 'Phone-Link.cs') -ReferencedAssemblies System.Net.Http,System.Web.Extensions,System.Security
$script:phoneConfigPath=Join-Path $script:logDir 'phone-link.dpapi'
$script:phoneConfig=@{Enabled=$false;Approvals=$false;Origin='';Token='';Trusted=@{}}
try{$saved=[OrbyPhoneClient]::Load($script:phoneConfigPath);if($saved){$c=$saved|ConvertFrom-Json;$script:phoneConfig.Enabled=[bool]$c.Enabled;$script:phoneConfig.Approvals=[bool]$c.Approvals;$script:phoneConfig.Origin=[string]$c.Origin;$script:phoneConfig.Token=[string]$c.Token;foreach($p in $c.Trusted.PSObject.Properties){$script:phoneConfig.Trusted[$p.Name]=[string]$p.Value}}}catch{Write-OrbitLog 'Phone configuration could not be loaded; phone access remains off.'}
if($NoNetwork){$script:phoneConfig.Enabled=$false}
$script:phoneInstance=[guid]::NewGuid().ToString();$script:phoneSequence=0;$script:phoneConsumed=@{};$script:phoneAcks=@();$script:phoneLocalRequest=$null
function Save-OrbyPhoneConfig {[OrbyPhoneClient]::Save($script:phoneConfigPath,($script:phoneConfig|ConvertTo-Json -Depth 6 -Compress))}
function Reset-OrbyPhoneClient {if($script:phoneClient){$script:phoneClient.Dispose()};$script:phoneClient=$null;$script:phoneExchange=$null;$script:phoneInstance=[guid]::NewGuid().ToString();$script:phoneSequence=0;$script:phoneLocalRequest=$null;if($script:phoneConfig.Enabled){$script:phoneClient=[OrbyPhoneClient]::new($script:phoneConfig.Origin,$script:phoneConfig.Token,$false)}}
function Get-OrbyPhoneTaskSnapshot {
 $result=@();foreach($id in @(Get-OrbyPairedProviders)){$status=Get-OrbyIndependentStatus $id;foreach($task in @(Get-OrbyProviderTasks $id $status)){
  if($result.Count -ge 64){break};$title=[string]$task.Title;$detail=[string]$task.Action
  foreach($name in @('title','detail')){$value=Get-Variable $name -ValueOnly;$value=[regex]::Replace($value,'(?i)(sk-[A-Za-z0-9_-]{20,}|gh[pousr]_[A-Za-z0-9_]{20,}|Bearer\s+\S+)','[redacted]');Set-Variable $name $value}
  $result+=@{id=([string]$task.Id).Substring(0,[math]::Min(240,([string]$task.Id).Length));provider=$status.Name;state=$(if($task.State -in @('working','attention','idle','error')){$task.State}else{'idle'});title=$title.Substring(0,[math]::Min(240,$title.Length));detail=$detail.Substring(0,[math]::Min(600,$detail.Length))}
 }};return $result
}
function Get-OrbyPhoneRequest {
 if($script:phoneSubmission){return $script:phoneSubmission.Request}
 $q=$script:approvalRequest;$eligible=$script:phoneConfig.Approvals -and $q -and $q.Available -and $q.CanAnswer -and $q.Kind -eq 'permission' -and $script:approvalRequestAt -and ([datetime]::UtcNow-$script:approvalRequestAt).TotalSeconds -lt 5
 if(-not $eligible){$script:phoneLocalRequest=$null;return $null}
 if($script:phoneConsumed.ContainsKey([string]$q.Id)){return $null}
 $review='ChatGPT'+"`n"+$q.Title+"`n`n"+$q.Detail
 if($review.Length -gt 8000 -or $review -match '(?i)BEGIN .*PRIVATE KEY|sk-[A-Za-z0-9_-]{20,}|Bearer\s+\S+'){$script:phoneLocalRequest=$null;return $null}
 $revision=[OrbyPhoneClient]::Hash($review)
 if(-not $script:phoneLocalRequest -or $script:phoneLocalRequest.nativeId -cne $q.Id -or $script:phoneLocalRequest.revision -cne $revision){$script:phoneLocalRequest=@{id=[guid]::NewGuid().ToString();nativeId=[string]$q.Id;provider='ChatGPT';reviewText=$review;revision=$revision};$script:phoneRequestStarted=[datetime]::UtcNow}
 if(([datetime]::UtcNow-$script:phoneRequestStarted).TotalSeconds -ge 120){return $null};return $script:phoneLocalRequest
}
function Invoke-OrbyPhoneDecision($d){
 $r=$script:phoneLocalRequest;$q=$script:approvalRequest
 if(-not $script:phoneConfig.Enabled -or -not $script:phoneConfig.Approvals -or $script:approvalReplyTask -or -not $r -or -not $q -or -not $q.Available -or $q.Kind -ne 'permission' -or $q.Id -cne $r.nativeId -or $d.id -cne $r.id -or $d.nativeId -cne $r.nativeId -or $d.revision -cne $r.revision -or $script:phoneConsumed.ContainsKey($r.nativeId)){return}
 $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();$key=$script:phoneConfig.Trusted[[string]$d.deviceId]
 $currentReview='ChatGPT'+"`n"+$q.Title+"`n`n"+$q.Detail
 if(-not $q.CanAnswer -or [OrbyPhoneClient]::Hash($currentReview) -cne $r.revision -or -not $key -or [long]$d.expiresAt -le $now -or [long]$d.expiresAt -gt ([DateTimeOffset]$script:phoneRequestStarted).ToUnixTimeSeconds()+135 -or ([datetime]::UtcNow-$script:phoneRequestStarted).TotalSeconds -ge 120 -or ([datetime]::UtcNow-$script:approvalRequestAt).TotalSeconds -ge 5){return}
 if(-not [OrbyPhoneClient]::Verify($key,[string]$d.deviceId,[string]$d.id,[string]$d.revision,[string]$d.decision,[string]$d.nonce,[long]$d.expiresAt,[string]$d.signature)){return}
 # Mark before invoking; network retries or another phone must never repeat a click.
 $script:phoneConsumed[$r.nativeId]=$true;$script:approvalClickedId=$q.Id;$script:approvalNotice='Sending the trusted phone response...'
 $script:approvalReplyTask=[OrbyApprovalWorker]::Respond($q.Id,($d.decision -eq 'allow'));$script:phoneSubmission=@{Id=$r.id;Task=$script:approvalReplyTask;Request=$r};Update-OrbyApprovalView
}
function Invoke-OrbyPhoneTick {
 if($script:phoneSubmission -and $script:phoneSubmission.Task.IsCompleted){$result='uncertain';if(-not $script:phoneSubmission.Task.IsFaulted){$reply=$script:phoneSubmission.Task.Result;$result=if($reply.Resolved){'resolved'}elseif($reply.Submitted){'submitted'}else{'stale'}};$script:phoneAcks+=@{id=$script:phoneSubmission.Id;result=$result};$script:phoneSubmission=$null}
 if(-not $script:phoneConfig.Enabled){return}
 try{
  if(-not $script:phoneClient){Reset-OrbyPhoneClient}
  if($script:phoneExchange){if(-not $script:phoneExchange.IsCompleted){return};$pending=$script:phoneExchange;$script:phoneExchange=$null;if($pending.IsFaulted){throw 'Phone service unavailable'};$response=$pending.Result|ConvertFrom-Json;$sentIds=@($script:phoneSentAcks|ForEach-Object {$_.id});$script:phoneAcks=@($script:phoneAcks|Where-Object {$_.id -notin $sentIds});foreach($d in @($response.decisions)){if($d){Invoke-OrbyPhoneDecision $d}};$script:phoneStatus='PC feed connected · '+$response.phoneCount+' trusted phone(s)'}
  $script:phoneSequence++;$body=@{instance=$script:phoneInstance;sequence=$script:phoneSequence;tasks=@(Get-OrbyPhoneTaskSnapshot);request=(Get-OrbyPhoneRequest);allowRequests=[bool]$script:phoneConfig.Approvals;acks=@($script:phoneAcks)}|ConvertTo-Json -Depth 7 -Compress
  $script:phoneSentAcks=@($script:phoneAcks);$script:phoneExchange=$script:phoneClient.Exchange($script:phoneInstance,$body)
 }catch{$script:phoneStatus='Phone feed offline. Local approvals still work.'}
 if($script:phoneWindow -and $script:phoneWindow.IsVisible){$script:phoneUi.PhoneMessage.Text=$script:phoneStatus}
}
function Start-OrbyPhoneUiRequest([string]$Method,[string]$Path,$Body,[string]$Action){
 if($script:phoneUiTask){return};if(-not $script:phoneClient){throw 'Save and enable the relay connection first.'}
 $script:phoneUiTask=$script:phoneClient.Request($Method,$Path,$(if($null -ne $Body){$Body|ConvertTo-Json -Compress}else{$null}));$script:phoneUiAction=$Action;$script:phoneUi.PhoneMessage.Text='Connecting...'
}
function Update-OrbyPhoneUiTask {
 if(-not $script:phoneUiTask -or -not $script:phoneUiTask.IsCompleted){return};$t=$script:phoneUiTask;$script:phoneUiTask=$null
 try{if($t.IsFaulted){throw 'Connection failed; check the relay address and PC code.'};$r=$t.Result|ConvertFrom-Json
  switch($script:phoneUiAction){
   invite {$script:phoneUi.PhoneInvitation.Text=$r.invite;$script:phoneUi.PhoneMessage.Text='Paste this invitation into the phone app within five minutes.'}
   phones {$script:phoneUi.PhoneDevices.Children.Clear();foreach($p in $r.phones){$row=[Windows.Controls.StackPanel]::new();$row.Margin='0,0,0,12';$label=[Windows.Controls.TextBlock]::new();$label.Text=$p.name+' · '+$p.fingerprint+$(if($p.active){' · connected'}else{' · awaiting PC confirmation'});[void]$row.Children.Add($label);$actions=[Windows.Controls.StackPanel]::new();$actions.Orientation='Horizontal'
    $trust=[Windows.Controls.Button]::new();$trust.Content='Fingerprints match — trust phone';$trust.IsEnabled=(-not $p.active -or $script:phoneConfig.Trusted[$p.id] -cne $p.publicKey);$trust.Tag=$p;$trust.Add_Click({param($sender,$e)$p=$sender.Tag;if([OrbyPhoneClient]::Fingerprint($p.publicKey) -cne $p.fingerprint){throw 'Phone fingerprint mismatch'};$script:phoneConfig.Trusted[$p.id]=$p.publicKey;Save-OrbyPhoneConfig;Start-OrbyPhoneUiRequest 'POST' ('/desktop/phones/'+$p.id+'/trust') @{fingerprint=$p.fingerprint} 'trusted'});[void]$actions.Children.Add($trust)
    $revoke=[Windows.Controls.Button]::new();$revoke.Content='Revoke';$revoke.Tag=$p.id;$revoke.Add_Click({param($sender,$e)$id=[string]$sender.Tag;$script:phoneConfig.Trusted.Remove($id);Save-OrbyPhoneConfig;Start-OrbyPhoneUiRequest 'DELETE' ('/desktop/phones/'+$id) $null 'revoked'});[void]$actions.Children.Add($revoke);[void]$row.Children.Add($actions);[void]$script:phoneUi.PhoneDevices.Children.Add($row)}}
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
