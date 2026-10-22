function Start-OrbyUiScanner {
 $script:uiScanShared=[hashtable]::Synchronized(@{Stop=$false;Latest=$null;Error=''})
 $definitions=@{}
 foreach($name in @('Get-AllTopWindows','Find-ChatGptWindow','Get-ChatGptUiRoots','Get-NamedControls','Get-ChatGptSnapshot','Get-OrbyUiInputRequest','Get-LiveChatGptNotification','Get-WatchdogUiResult')){$definitions[$name]=(Get-Command $name).Definition}
 $script:uiScanRunspace=[runspacefactory]::CreateRunspace();$script:uiScanRunspace.ApartmentState='MTA';$script:uiScanRunspace.Open()
 $script:uiScanWorker=[powershell]::Create();$script:uiScanWorker.Runspace=$script:uiScanRunspace
 [void]$script:uiScanWorker.AddScript({
  param($shared,$definitions)
  Add-Type -AssemblyName UIAutomationClient,UIAutomationTypes
  function Write-OrbitLog {param($Message)}
  foreach($entry in $definitions.GetEnumerator()){Set-Item ('Function:'+ $entry.Key) ([scriptblock]::Create($entry.Value))}
  $generation=0;$lastChat=$null;$lastNote=$null
  while(-not $shared.Stop){
   try {
    $watch=[Diagnostics.Stopwatch]::StartNew();$chat=$null
    if($lastChat){try{$c=$lastChat.Current;$owner=(Get-Process -Id $c.ProcessId -ErrorAction SilentlyContinue).ProcessName;if(-not $c.IsOffscreen -and ($owner -match '(?i)chatgpt|openai' -or $c.Name -match '(?i)chatgpt')){$chat=$lastChat}}catch{}}
    if(-not $chat){$chat=Find-ChatGptWindow};$lastChat=$chat;$title='';if($chat){try{$title=$chat.Current.Name}catch{}}
    $snapshot=Get-ChatGptSnapshot $chat
    $watchdog=if($snapshot.Working){'present'}elseif($chat){Get-WatchdogUiResult $chat}else{'unknown'}
    if($generation%3 -eq 0){$lastNote=Get-LiveChatGptNotification $chat};$note=$lastNote
    $shared.Latest=[pscustomobject]@{Generation=(++$generation);At=[datetime]::UtcNow;Chat=$chat;Title=$title;Snapshot=$snapshot;Notification=$note;Watchdog=$watchdog;Connected=(@(Get-Process ChatGPT -ErrorAction SilentlyContinue).Count -gt 0) -or $null -ne $chat;ScanMs=$watch.Elapsed.TotalMilliseconds}
   }catch{$shared.Error=$_.Exception.GetType().Name}
   # This wait runs only on the scanner thread, never on the WPF dispatcher.
   for($i=0;$i -lt 10 -and -not $shared.Stop;$i++){[Threading.Thread]::Sleep(75)}
  }
 }).AddArgument($script:uiScanShared).AddArgument($definitions)
 $script:uiScanHandle=$script:uiScanWorker.BeginInvoke()
 $window.Add_Closed({if($PerformanceCheck){Write-OrbitLog ('UI SCANNER generations='+$script:uiScanShared.Latest.Generation+' error='+$script:uiScanShared.Error)};$script:uiScanShared.Stop=$true;try{[void]$script:uiScanWorker.BeginStop($null,$null)}catch{}})
}


