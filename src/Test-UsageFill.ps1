$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Test-AllLargeMenus.ps1') -KeepWindow
$script:fillChecks=0
function CheckFill($ok,$why){if(-not $ok){throw $why};$script:fillChecks++}
function PumpFill($seconds){$frame=[Windows.Threading.DispatcherFrame]::new();$timer=[Windows.Threading.DispatcherTimer]::new();$timer.Interval=[timespan]::FromSeconds($seconds);$timer.Add_Tick({$timer.Stop();$frame.Continue=$false}.GetNewClosure());$timer.Start();[Windows.Threading.Dispatcher]::PushFrame($frame)}
$script:fillData=$true;$script:fillTarget=60
function Get-OrbyAccountUsage($Id){[pscustomobject]@{Session=$(if($script:fillData){[pscustomobject]@{Remaining=$script:fillTarget;Label='5-hour window';Reset='1h'}});Week=$(if($script:fillData){[pscustomobject]@{Remaining=85;Label='Weekly usage';Reset='3d'}});Note='Controlled animation fixture'}}
$script:orbySettings.ProviderEnabled='chatgpt,claude,gemini';$script:expanded=$true;$script:fullscreenHidden=$false;$script:orbyEventMode='';$script:orbySettings.ReducedMotion=$false
try {
 Select-OrbyCompanion 'chatgpt';$card=$script:providerCards.chatgpt;$bar=$card.Controls.InlineSessionBar;$weekly=$card.Controls.InlineWeekBar
 CheckFill ($bar.Value -eq 0 -and $weekly.Value -eq 0) 'Panel entry did not begin both bars at zero'
 PumpFill .12
 CheckFill ($bar.Value -gt 0 -and $bar.Value -lt 60 -and $weekly.Value -gt 0 -and $weekly.Value -lt 85) 'Both usage bars failed to interpolate'
 $before=$bar.Value;Update-OrbyMultiProvider
 CheckFill ([math]::Abs($bar.Value-$before) -lt .01) 'Unchanged status poll restarted the fill'
 PumpFill .6
 CheckFill ([math]::Abs($bar.Value-60) -lt .01 -and [math]::Abs($weekly.Value-85) -lt .01) 'Fill did not finish at the actual quota'
 Set-OrbyHomePage 'music'
 CheckFill ($bar.Value -eq 0 -and -not $card.UsageVisible) 'Leaving the page retained an active fill'
 Set-OrbyHomePage 'home'
 CheckFill ($bar.Value -eq 0 -and $card.UsageVisible) 'Returning to Home did not replay from zero'
 PumpFill .65;Select-OrbyCompanion 'claude'
 CheckFill ($script:providerCards.claude.Controls.InlineSessionBar.Value -eq 0 -and $bar.Value -eq 0) 'Provider switching did not reset the arriving and departing bars'
 PumpFill .65;Select-OrbyCompanion 'chatgpt'
 CheckFill ($bar.Value -eq 0) 'Returning to the previous provider did not replay'
 PumpFill .65;Select-OrbyCompanion 'chatgpt'
 CheckFill ($bar.Value -eq 0) 'Clicking the same provider did not replay'
 PumpFill .65;$script:fillTarget=90;Update-OrbyMultiProvider
 CheckFill ([math]::Abs($bar.Value-60) -lt .01) 'Live quota change jumped or reset to zero'
 PumpFill .1;CheckFill ($bar.Value -gt 60 -and $bar.Value -lt 90) 'Live quota change failed to transition from its current value'
 $script:orbySettings.ReducedMotion=$true;Update-OrbyMultiProvider
 CheckFill ($bar.Value -eq 90 -and -not $bar.HasAnimatedProperties) 'Reduced motion did not snap and cancel the active fill'
 Select-OrbyCompanion 'gemini'
 CheckFill ($script:providerCards.gemini.Controls.InlineSessionBar.Value -eq 90) 'Reduced-motion provider entry animated instead of snapping'
 $script:orbySettings.ReducedMotion=$false;$script:fillData=$false;Select-OrbyCompanion 'chatgpt';PumpFill .1
 CheckFill ($bar.Value -eq 0 -and $card.Controls.InlineSessionValue.Text -eq 'Not available') 'Unknown quota was animated as real data'
 $script:fillData=$true;Update-OrbyMultiProvider
 CheckFill ($bar.Value -eq 0) 'Newly available quota did not start from zero'
 PumpFill .65;CheckFill ($bar.Value -eq 90) 'Newly available quota did not settle'
 $script:expanded=$false;Update-OrbyMultiProvider
 CheckFill ($bar.Value -eq 0 -and -not $card.UsageVisible) 'Closing the notch did not stop/reset the fill'
 $script:expanded=$true;Update-OrbyMultiProvider;CheckFill ($bar.Value -eq 0) 'Reopening the notch did not replay'
 PumpFill .65
 $notch.Morph=0;Select-OrbyCompanion 'chatgpt';PumpFill .08
 CheckFill ($bar.Value -eq 0) 'Bar filled while the unfolding notch still masked it'
 PumpFill .25;CheckFill ($bar.Value -eq 0) 'Fill used a fixed delay instead of the actual notch reveal'
 $notch.Morph=.96;PumpFill .25;CheckFill ($bar.Value -gt 0 -and $bar.Value -lt 90) 'Actual reveal never started the fill'
 PumpFill .6;CheckFill ($bar.Value -eq 90) 'Delayed fill did not settle'
 $notch.Morph=1
 "PASS: $script:fillChecks usage-fill assertions: entry, both windows, provider/page/reopen replay, same-provider replay, no polling restart, live changes, missing data and reduced motion."
}finally{$window.Close()}
