Add-Type -Path (Join-Path $PSScriptRoot 'Usage-Worker.cs') -ReferencedAssemblies @('System.Web.Extensions')
$script:usagePollAt=[datetime]::MinValue
function Get-OrbyCodexExecutable {
 $command=Get-Command codex.exe -ErrorAction SilentlyContinue
 if($command){return $command.Source}
 $root=Join-Path $env:LOCALAPPDATA 'OpenAI/Codex/bin'
 $file=Get-ChildItem $root -Filter codex.exe -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
 if($file){return $file.FullName}
 return $null
}
function Update-OrbyAccountUsage {
 if($script:usagePollTask -and $script:usagePollTask.IsCompleted){
  if(-not $script:usagePollTask.IsFaulted -and -not $script:usagePollTask.IsCanceled){
   $next=$script:usagePollTask.Result
   if($next.ErrorKind -or $next.Status -eq 'Account service could not be reached'){$script:usageRefreshFailed=$true}else{$script:usageSnapshot=$next;$script:usageRefreshFailed=$false}
  }else{$script:usageRefreshFailed=$true;if($script:usagePollTask.IsFaulted){[void]$script:usagePollTask.Exception}}
  $script:usagePollTask=$null
  # Prepare the cached values even while hidden; opening the menu never waits on decoding.
  if($script:referenceControls){Update-OrbyAgents;if($script:referenceControls.RefAgentsPage.Visibility -eq 'Visible' -and (Test-Path function:Update-OrbyProviderView)){Update-OrbyProviderView}}
 }
 if($script:usagePollTask -or ([datetime]::UtcNow-$script:usagePollAt).TotalSeconds -lt 60){return}
 $script:usagePollAt=[datetime]::UtcNow
 $script:usagePollTask=[OrbyUsageWorker]::PollAvailable((Join-Path $logDir 'usage-runtime'))
}
function Initialize-OrbyAccountUsage {
 $script:usageSnapshot=[OrbyUsageWorker]::Cached((Join-Path $logDir 'usage-runtime'))
 $script:usageTimer=[Windows.Threading.DispatcherTimer]::new([Windows.Threading.DispatcherPriority]::Background)
 $script:usageTimer.Interval=[timespan]::FromMilliseconds(200)
 $script:usageTimer.Add_Tick({try{Update-OrbyAccountUsage}catch{Write-OrbitLog ('Account refresh: '+$_.Exception.Message)}})
 $script:usageTimer.Start()
 $window.Add_Closed({$script:usageTimer.Stop()})
 Update-OrbyAccountUsage
}
function Get-OrbyQuotaWindow {
 param($Window)
 if(-not $Window -or $null -eq $Window.usedPercent -or $null -eq $Window.resetsAt -or $null -eq $Window.windowDurationMins){return $null}
 $used=[double]$Window.usedPercent
 if([double]::IsNaN($used) -or [double]::IsInfinity($used) -or $used -lt 0 -or $used -gt 100){return $null}
 $reset=[DateTimeOffset]::FromUnixTimeSeconds([long]$Window.resetsAt).UtcDateTime
 if($reset -le [datetime]::UtcNow){return $null}
 $mins=[double]$Window.windowDurationMins
 $label=if($mins -ge 10080){'Week'}elseif($mins -ge 1440){[string][math]::Round($mins/1440,1)+'d window'}else{[string][math]::Round($mins/60,1)+'h window'}
 $span=$reset-[datetime]::UtcNow
 $when=if($span.TotalDays -ge 1){[string][math]::Floor($span.TotalDays)+'d '+$span.Hours+'h'}else{[string][math]::Floor($span.TotalHours)+'h '+$span.Minutes+'m'}
 return [pscustomobject]@{Remaining=100-$used;Label=$label;Reset=$when}
}
function Get-OrbyAccountUsage {
 param([string]$Id)
 $session=$null;$week=$null;$note='Usage not available'
 if($Id -eq 'chatgpt'){
  $snapshot=$script:usageSnapshot
  $fresh=$snapshot -and $snapshot.Connected -and $snapshot.At -le [datetime]::UtcNow.AddSeconds(5) -and ([datetime]::UtcNow-$snapshot.At).TotalSeconds -lt 180
  if($fresh){
   if($script:inlineLimitsJson -ne $snapshot.LimitsJson){
    $script:inlineLimitsJson=$snapshot.LimitsJson;$script:inlineLimits=$null
    try{$r=$snapshot.LimitsJson | ConvertFrom-Json;if($r.rateLimitsByLimitId.codex){$script:inlineLimits=$r.rateLimitsByLimitId.codex}elseif($r.rateLimits.limitId -eq 'codex'){$script:inlineLimits=$r.rateLimits}}catch{}
   }
   try{$session=Get-OrbyQuotaWindow $script:inlineLimits.primary}catch{}
   try{$week=Get-OrbyQuotaWindow $script:inlineLimits.secondary}catch{}
  }
  $note=if($session -or $week){if($script:usageRefreshFailed){'Last known Codex quota; refresh unavailable'}else{'Codex account quota; ChatGPT message limits are separate'}}else{'Codex quota unavailable. Sign in to Codex, then refresh.'}
 }else{
  $observations=@($script:orbyShared.ProviderSnapshots | Where-Object {$_.Provider -eq $Id -and $_.UsagePage -and $_.Usage -and $_.At -le [datetime]::UtcNow.AddSeconds(5) -and ([datetime]::UtcNow-$_.At).TotalSeconds -lt 8})
  $conflict=@($observations | ForEach-Object {[string]$_.Usage.SessionRemaining+'|'+[string]$_.Usage.WeekRemaining} | Select-Object -Unique).Count -gt 1
  $data=if(-not $conflict -and $observations.Count){($observations | Sort-Object At -Descending | Select-Object -First 1).Usage}else{$null}
  if($data){
   if($null -ne $data.SessionRemaining){$session=[pscustomobject]@{Remaining=$data.SessionRemaining;Label='5-hour window';Reset=$data.SessionReset}}
   if($null -ne $data.WeekRemaining){$week=[pscustomobject]@{Remaining=$data.WeekRemaining;Label='Weekly usage';Reset=$data.WeekReset}}
  }
  $note=if($conflict){'Multiple usage pages disagree. Keep the account you want open.'}elseif($data){'Read from the open Usage page. Hover a value for its reset time.'}else{'Open usage, sign in, and keep that Usage page open in your browser.'}
 }
 [pscustomobject]@{Session=$session;Week=$week;Note=$note}
}
function Set-OrbyQuotaRow {
 param([string]$Prefix,$Window)
 $c=$script:referenceControls;$data=Get-OrbyQuotaWindow $Window
 $c[$Prefix+'Row'].Visibility=if($data){'Visible'}else{'Collapsed'}
 if($data){$c[$Prefix+'Label'].Text=$data.Label+'  '+$data.Reset;$c[$Prefix+'Percent'].Text=[string][math]::Round($data.Remaining)+'%';$c[$Prefix+'Bar'].Value=$data.Remaining;$c[$Prefix+'Row'].ToolTip='Remaining quota; resets in '+$data.Reset}
}

