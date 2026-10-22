param([string]$TestDirectory)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework
. (Join-Path $PSScriptRoot 'Account-Usage.ps1')
. (Join-Path $PSScriptRoot 'Reference-Home.ps1')
function Get-NotchTaskTitle {return 'Example task'}
function Update-OrbyProviderView {}
function Get-OrbyCodexExecutable {throw 'Executable discovery ran on the UI thread'}
function Assert($ok,$message){if(-not $ok){throw $message}}
[xml]$x=Get-Content (Join-Path $PSScriptRoot 'Reference-Home.xaml') -Raw
$ui=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($x));$script:referenceHome=$ui;$script:referenceControls=@{}
foreach($m in [regex]::Matches($x.OuterXml,'x:Name="([^"]+)"')){$n=$m.Groups[1].Value;$script:referenceControls[$n]=$ui.FindName($n)}
$reset=[DateTimeOffset]::UtcNow.AddHours(1).ToUnixTimeSeconds()
$cached=[OrbyUsageSnapshot]::new();$cached.Connected=$true;$cached.LimitsJson='{"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":25,"windowDurationMins":300,"resetsAt":'+$reset+'}}}}'
$script:usageSnapshot=$cached;$script:usagePollAt=[datetime]::UtcNow
Update-OrbyAgents # Match the real startup warm-up before the first account click.
$pending=[System.Threading.Tasks.TaskCompletionSource[OrbyUsageSnapshot]]::new();$script:usagePollTask=$pending.Task
$watch=[Diagnostics.Stopwatch]::StartNew();Set-OrbyHomePage 'agents';$watch.Stop()
Assert ($watch.ElapsedMilliseconds -lt 500) ('Panel opening took '+$watch.ElapsedMilliseconds+' ms with account refresh pending')
Assert ($script:referenceControls.RefSessionBar.Value -eq 75) 'Cached quota was not displayed immediately'
Assert (-not $pending.Task.IsCompleted) 'Test refresh was not pending'
$updated=[OrbyUsageSnapshot]::new();$updated.Connected=$true;$updated.LimitsJson=$cached.LimitsJson.Replace('25','40')
$pending.SetResult($updated);Update-OrbyAccountUsage
Assert ($script:referenceControls.RefSessionBar.Value -eq 60) 'Completed background refresh did not update visible panel'
$bad=[System.Threading.Tasks.TaskCompletionSource[OrbyUsageSnapshot]]::new();$script:usagePollTask=$bad.Task
$failed=[OrbyUsageSnapshot]::new();$failed.ErrorKind='TimeoutException';$failed.Status='Account service could not be reached';$bad.SetResult($failed);Update-OrbyAccountUsage
Assert ($script:referenceControls.RefSessionBar.Value -eq 60 -and $script:usageRefreshFailed) 'Transient failure erased the valid display'
if($TestDirectory){
 [void][IO.Directory]::CreateDirectory($TestDirectory)
 $serializer=[System.Web.Script.Serialization.JavaScriptSerializer]::new()
 [IO.File]::WriteAllText((Join-Path $TestDirectory 'usage-cache.json'),$serializer.Serialize($updated))
 $restored=[OrbyUsageWorker]::Cached($TestDirectory)
 Assert ($restored -and $restored.Connected -and $restored.LimitsJson -eq $updated.LimitsJson) 'Same-session cache did not restore'
 $updated.At=[datetime]::UtcNow.AddMinutes(-4);[IO.File]::WriteAllText((Join-Path $TestDirectory 'usage-cache.json'),$serializer.Serialize($updated))
 Assert ($null -eq [OrbyUsageWorker]::Cached($TestDirectory)) 'Expired saved usage shown as current'
}
Write-Output ('PASS: AI panel opened in '+$watch.ElapsedMilliseconds+' ms with refresh pending; cached data, background completion, failure retention and cache expiry verified.')
