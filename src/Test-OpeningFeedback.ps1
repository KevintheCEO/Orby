$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Test-AllLargeMenus.ps1') -KeepWindow
$script:openingChecks=0
function CheckOpening($ok,$why){if(-not $ok){throw $why};$script:openingChecks++}
function PumpOpening($seconds){$frame=[Windows.Threading.DispatcherFrame]::new();$timer=[Windows.Threading.DispatcherTimer]::new();$timer.Interval=[timespan]::FromSeconds($seconds);$timer.Add_Tick({$timer.Stop();$frame.Continue=$false}.GetNewClosure());$timer.Start();[Windows.Threading.Dispatcher]::PushFrame($frame)}
$script:openingState='idle'
function Get-OrbyIndependentStatus($Id){[pscustomobject]@{Id=$Id;Name='ChatGPT';State=$script:openingState;Open=$false;Readable=$false;Sleeping=$true;Detail='';Title=''}}
function Open-OrbyProvider($Id){$script:openingLaunches++}
$script:orbySettings.ReducedMotion=$false;$script:expanded=$true;$script:companionSelection='chatgpt';$script:compactMenuPage='home';$script:lastProviderLaunch=@{}
$card=$script:providerCards.chatgpt
try {
 $card.Renderer.SetState('sleep','');$before=[Diagnostics.Stopwatch]::StartNew();Invoke-OrbyAvatarClick 'chatgpt' 2;$before.Stop()
 CheckOpening ($script:openingLaunches -eq 1 -and $before.ElapsedMilliseconds -lt 400) 'Opening waited for the animation'
 CheckOpening ($card.Renderer.ActiveId -eq 'wake_up' -and $script:openingFeedback.ContainsKey('chatgpt')) 'Double-click did not start native wake-up feedback'
 Update-OrbyMultiProvider
 CheckOpening ($card.Controls.Title.Text -eq 'Opening ChatGPT…' -and $card.Controls.SleepLabel.Visibility -eq 'Collapsed') 'Closed-app status canceled opening feedback'
 Invoke-OrbyAvatarClick 'chatgpt' 2
 CheckOpening ($script:openingLaunches -eq 1) 'Repeated double-click launched twice'
 PumpOpening 1.05
 CheckOpening ($card.Renderer.ActiveId -eq 'wave') 'Greeting wave timer did not fire'
 PumpOpening 1.7
 CheckOpening (-not $script:openingFeedback.ContainsKey('chatgpt')) 'Finished animation retained timers'
 CheckOpening ($card.Controls.Title.Text -ne 'Ready') 'Launch feedback falsely confirmed that the app opened'
 $script:orbySettings.ReducedMotion=$true;$script:lastProviderLaunch=@{};Invoke-OrbyAvatarClick 'chatgpt' 2
 CheckOpening ($script:openingFeedback.Count -eq 0 -and $script:openingLaunches -eq 2) 'Reduced motion blocked launching or left animation running'
 $script:orbySettings.ReducedMotion=$false;Start-OrbyOpeningFeedback 'chatgpt';$script:orbySettings.ReducedMotion=$true;Update-OrbyMultiProvider
 CheckOpening ($script:openingFeedback.Count -eq 0 -and $card.Controls.MainHost.RenderTransform.ScaleX -eq 1) 'Reduced motion did not cancel pending feedback'
 $script:orbySettings.ReducedMotion=$false;Start-OrbyOpeningFeedback 'chatgpt';$script:openingState='attention';Update-OrbyMultiProvider
 CheckOpening ($script:openingFeedback.Count -eq 0 -and $card.Renderer.ActiveId -ne 'wave') 'Opening animation overrode approval activity'
 $script:openingState='idle';Start-OrbyOpeningFeedback 'chatgpt';Stop-OrbyAllOpeningFeedback
 CheckOpening ($script:openingFeedback.Count -eq 0) 'Window-close cleanup retained feedback timers'
 "PASS: $script:openingChecks opening feedback assertions: native wake and wave, immediate launch, double-click debounce, reduced motion, priority and cleanup."
}finally{Stop-OrbyAllOpeningFeedback;$window.Close()}
