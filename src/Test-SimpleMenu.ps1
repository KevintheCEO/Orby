$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework
. (Join-Path $PSScriptRoot 'Account-Usage.ps1')
. (Join-Path $PSScriptRoot 'Reference-Home.ps1')
function Update-OrbyAccountUsage {}
function Get-NotchTaskTitle {return 'Test task'}
[xml]$x=Get-Content (Join-Path $PSScriptRoot 'Reference-Home.xaml') -Raw
$ui=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($x))
$script:referenceHome=$ui;$script:referenceControls=@{}
foreach($m in [regex]::Matches($x.OuterXml,'x:Name="([^"]+)"')){$n=$m.Groups[1].Value;$script:referenceControls[$n]=$ui.FindName($n)}
function Assert($ok,$message){if(-not $ok){throw $message}}
$script:chatConnectionPresent=$false;$script:usageSnapshot=$null;Update-OrbyAgents
Assert ($script:referenceControls.RefChatCard.Visibility -eq 'Collapsed') 'Disconnected ChatGPT visible'
Assert ($script:referenceControls.RefCodexCard.Visibility -eq 'Collapsed') 'Disconnected Codex visible'
$script:chatConnectionPresent=$true;$script:chatLogState='working';Update-OrbyAgents
Assert ($script:referenceControls.RefAgentState.Text -eq 'Working') 'Working state missing'
Assert ($script:referenceControls.RefCodexColumn.Width.Value -eq 0) 'Disconnected card reserves space'
$script:chatLogState='attention';Update-OrbyAgents
Assert ($script:referenceControls.RefAgentState.Text -eq 'Needs approval') 'Approval missing'
$reset=[DateTimeOffset]::UtcNow.AddHours(3).ToUnixTimeSeconds()
# Explicit synthetic fixtures for quota normalization, never used as live fallback.
$script:usageSnapshot=[pscustomobject]@{At=[datetime]::UtcNow;Connected=$true;Plan='Preview';Status='Live account data';LimitsJson=('{"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":25,"windowDurationMins":300,"resetsAt":'+$reset+'}}}}');UsageJson=''}
Update-OrbyAgents
Assert ($script:referenceControls.RefSessionBar.Value -eq 75) 'Used percent mistaken for remaining'
Assert ($script:referenceControls.RefWeekRow.Visibility -eq 'Collapsed') 'Missing weekly data shown as zero'
Assert ($script:referenceControls.RefTokenValue.Text -eq [string][char]0x2014) 'Missing tokens shown as zero'
$script:usageSnapshot.At=[datetime]::UtcNow.AddMinutes(-4);Update-OrbyAgents
Assert ($script:referenceControls.RefCodexCard.Visibility -eq 'Collapsed') 'Stale account connection shown'
Assert ($null -eq (Get-OrbyQuotaWindow ([pscustomobject]@{usedPercent=200;windowDurationMins=300;resetsAt=$reset}))) 'Invalid percent accepted'
Set-OrbyHomePage 'agents'
Assert ($ui.Height -eq 340) 'Dashboard not expanded'
Set-OrbyHomePage 'home'
Assert ($ui.Height -eq 180 -and $script:referenceControls.RefAgentsPage.Visibility -eq 'Collapsed') 'Home reset failed'
Assert ($script:referenceControls.RefHome.Tag -eq 'Selected' -and $script:referenceControls.RefAgents.Tag -ne 'Selected') 'Toolbar selection did not return Home'
'AI dashboard tests passed: connection filtering, state, remaining percentages, unknown data, expiry, resize and Home reset.'

$script:chatConnectionPresent=$true
Update-OrbyHome
Assert ($script:referenceControls.RefMusic.Visibility -eq 'Collapsed' -and $script:referenceControls.RefTools.Visibility -eq 'Collapsed') 'Removed menu icons visible'
Assert ($script:referenceControls.RefAgents.Visibility -eq 'Visible') 'Connected OpenAI hidden'
$script:chatConnectionPresent=$false;$script:usageSnapshot=$null;Update-OrbyHome
Assert ($script:referenceControls.RefAgents.Visibility -eq 'Collapsed') 'Disconnected provider visible'
'PASS: three-button connected menu and provider filtering.'
