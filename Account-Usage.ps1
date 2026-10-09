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
  if($script:referenceControls -and $script:referenceControls.RefAgentsPage.Visibility -eq 'Visible'){Update-OrbyAgents;if(Get-Command Update-OrbyProviderView -ErrorAction SilentlyContinue){Update-OrbyProviderView}}
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
function Set-OrbyQuotaRow {
 param([string]$Prefix,$Window)
 $c=$script:referenceControls;$data=Get-OrbyQuotaWindow $Window
 $c[$Prefix+'Row'].Visibility=if($data){'Visible'}else{'Collapsed'}
 if($data){$c[$Prefix+'Label'].Text=$data.Label+'  '+$data.Reset;$c[$Prefix+'Percent'].Text=[string][math]::Round($data.Remaining)+'%';$c[$Prefix+'Bar'].Value=$data.Remaining;$c[$Prefix+'Row'].ToolTip='Remaining quota; resets in '+$data.Reset}
}

