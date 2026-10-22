# UI failures are reported without unwinding Application.Run. Shutdown never waits
# for a worker on the UI thread. Fatal CLR failures are not treated as recoverable.
if(-not ('OrbyBackgroundShutdown' -as [type])){Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Threading.Tasks;
public static class OrbyBackgroundShutdown {
 static readonly HashSet<PowerShell> stopping=new HashSet<PowerShell>();
 public static void Stop(PowerShell worker,Runspace runspace) {
  if(worker==null && runspace==null)return;
  lock(stopping){if(worker!=null && !stopping.Add(worker))return;}
  Task.Run(()=>{
   try{if(worker!=null)worker.Stop();}catch{}
   try{if(worker!=null)worker.Dispose();}catch{}
   try{if(runspace!=null)runspace.Dispose();}catch{}
  });
 }
}
'@ -ReferencedAssemblies @([powershell].Assembly.Location,'System.Core.dll')}

function Test-OrbyRecoverableUiError {
 param([Exception]$ErrorException)
 for($e=$ErrorException;$e;$e=$e.InnerException){
  if($e -is [OutOfMemoryException] -or $e -is [AccessViolationException] -or $e -is [StackOverflowException] -or $e -is [Threading.ThreadAbortException]){return $false}
 }
 return $true
}
function Show-OrbyUiWarning {
 param([Exception]$ErrorException,[string]$Context='UI action')
 try{Write-OrbitLog ('UI RECOVERED '+$Context+': '+$ErrorException.ToString())}catch{}
 if($script:orbyClosing){return}
 $now=[datetime]::UtcNow
 if(-not $script:uiErrorWindow -or ($now-$script:uiErrorWindow).TotalSeconds -gt 10){$script:uiErrorWindow=$now;$script:uiErrorCount=0}
 $script:uiErrorCount++
 $note='That action failed. You can keep using Orby; details are in the log.'
 if($script:uiErrorCount -ge 4){
  foreach($timer in @($scanTimer,$script:usageTimer,$script:artTimer,$script:musicTimelineTimer,$script:dropPoll)){try{if($timer){$timer.Stop()}}catch{}}
  $note='Background updates paused after repeated errors. Quit and reopen Orby.'
 }
 if(-not $script:uiWarningAt -or ($now-$script:uiWarningAt).TotalSeconds -gt 20){
  $script:uiWarningAt=$now
  try{if($script:orbyTray){$script:orbyTray.ShowBalloonTip(5000,'Orby',$note,[Windows.Forms.ToolTipIcon]::Warning)}}catch{}
 }
 try{if($script:compactMenuControls){$script:compactMenuControls.MenuFooter.Text=$note;$script:compactMenuControls.MenuFooter.ToolTip=$note}}catch{}
}
function Invoke-OrbySafeAction {
 param([scriptblock]$Action,[string]$Context='UI action')
 try{& $Action}catch{
  if(-not (Test-OrbyRecoverableUiError $_.Exception)){throw}
  Show-OrbyUiWarning $_.Exception $Context
 }
}
function Initialize-OrbyUiRecovery {
 param([Windows.Application]$Application)
 $script:uiRecoveryHandler=[Windows.Threading.DispatcherUnhandledExceptionEventHandler]{
  param($sender,$eventArgs)
  if(Test-OrbyRecoverableUiError $eventArgs.Exception){
   $eventArgs.Handled=$true
   Show-OrbyUiWarning $eventArgs.Exception 'Dispatcher event'
  }
 }
 $Application.Add_DispatcherUnhandledException($script:uiRecoveryHandler)
}
function Request-OrbyQuit {
 if($script:orbyClosing){return}
 $script:orbyClosing=$true
 try{Write-OrbitLog 'QUIT requested.'}catch{}
 if($script:orbyShared){$script:orbyShared.Stop=$true}
 foreach($timer in @($scanTimer,$script:usageTimer,$script:artTimer,$script:musicTimelineTimer,$script:dropPoll,$script:perfTimer,$script:fullscreenTimer,$script:hoverExitTimer,$script:greetingTimer,$script:greetingFinishTimer)){try{if($timer){$timer.Stop()}}catch{}}
 try{if($script:orbyTray){$script:orbyTray.Visible=$false;$script:orbyTray.Dispose()}}catch{}
 try{if($window){$window.Close()}}catch{try{Write-OrbitLog ('QUIT window cleanup: '+$_.Exception.Message)}catch{}}
 try{if([Windows.Application]::Current){[Windows.Application]::Current.Shutdown()}}catch{}
}
