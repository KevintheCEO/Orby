param([switch]$RealPaste)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Xaml,UIAutomationClient,UIAutomationTypes
$window=[Windows.Window]::new();$window.Title='Orby local AI handoff fixture';$window.Width=480;$window.Height=300
$outer=[Windows.Controls.StackPanel]::new();$window.Content=$outer;$group=[Windows.Controls.GroupBox]::new();[void]$outer.Children.Add($group);$stack=[Windows.Controls.StackPanel]::new();$group.Content=$stack
$new=[Windows.Controls.Button]::new();$new.Content='New chat';[void]$stack.Children.Add($new)
$attach=[Windows.Controls.Button]::new();$attach.Content='Add files';[void]$stack.Children.Add($attach)
$files=[Windows.Controls.TextBlock]::new();[void]$stack.Children.Add($files)
$historyFile=[Windows.Controls.TextBlock]::new();[void]$outer.Children.Add($historyFile)
$composer=[Windows.Controls.TextBox]::new();[void]$stack.Children.Add($composer)
$send=[Windows.Controls.Button]::new();$send.Content='Send message';[void]$stack.Children.Add($send)
$stop=[Windows.Controls.Button]::new();$stop.Content='Stop generating';$stop.Visibility='Collapsed';[void]$stack.Children.Add($stop)
$state=[hashtable]::Synchronized(@{New=0;Send=0;Attach=0;Opened=0;InitialLookup=$true;Prompt='';Cancelled=$false;SendInvoked=$false;Stage='';Started=[datetime]::UtcNow})
$fixture=Join-Path $env:TEMP ('gap_full_fill_2026_'+[guid]::NewGuid().ToString('N')+'.py');[IO.File]::WriteAllText($fixture,'Local test fixture only')
$progress=[Windows.Controls.ProgressBar]::new();$progress.Height=8;$progress.Visibility='Collapsed';[void]$stack.Children.Add($progress)
$uploadTimer=[Windows.Threading.DispatcherTimer]::new();$uploadTimer.Interval=[timespan]::FromSeconds(2);$uploadTimer.Add_Tick({$uploadTimer.Stop();$state.PromptBeforeUploadReady=$composer.Text;$progress.Visibility='Collapsed'})
$composer.Add_PreviewKeyDown({param($sender,$e)if($e.Key -eq [Windows.Input.Key]::V -and ([Windows.Input.Keyboard]::Modifiers -band [Windows.Input.ModifierKeys]::Control) -and [Windows.Forms.Clipboard]::ContainsFileDropList()){$incoming=[Windows.Forms.Clipboard]::GetFileDropList();if($incoming.Count -ne 1 -or $incoming[0] -ne $fixture){throw 'Clipboard paths changed'};$state.Attach++;$files.Text=if($state.Truncated){[IO.Path]::GetFileName($fixture).Substring(0,18)+'...'}else{[IO.Path]::GetFileName($fixture)};if($state.Delayed){$progress.Visibility='Visible';$uploadTimer.Start()};if($state.CancelAfterAttach){$state.Cancelled=$true};$e.Handled=$true}})
$new.Add_Click({$progress.Visibility='Collapsed';$state.New++;$composer.Text='';$files.Text='';$historyFile.Text='';$send.IsEnabled=$true;$stop.Visibility='Collapsed'})
$attach.Add_Click({$state.Attach++;$files.Text=if($state.Truncated){[IO.Path]::GetFileName($fixture).Substring(0,18)+'...'}else{[IO.Path]::GetFileName($fixture)};if($state.Delayed){$progress.Visibility='Visible';$uploadTimer.Start()};if($state.CancelAfterAttach){$state.Cancelled=$true}})
$send.Add_Click({$state.Send++;$state.Prompt=$composer.Text;$composer.Text='';if($state.FastComplete){$send.IsEnabled=$false;$files.Text='';$historyFile.Text=[IO.Path]::GetFileName($fixture);$stop.Visibility='Collapsed'}else{$stop.Visibility='Visible'}})
$window.Show();$window.UpdateLayout();$handle=[Windows.Interop.WindowInteropHelper]::new($window).Handle
$workerText=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Chat-Drop-Worker.ps1'))
# Production has no test hooks. Launch and file picking stay inside this fixture.
$injection=@'
function Find-OrbyDropWindow($Adapter){if($Operation.InitialLookup){$Operation.InitialLookup=$false;return $null};return [Windows.Automation.AutomationElement]::FromHandle([IntPtr]$Operation.FixtureHwnd)}
function Open-OrbyDropApp($Adapter){$Operation.Opened++}
function Get-OrbyDropGeminiAttachments($Root,[string[]]$Files){Get-OrbyDropAttachmentNodes $Root $Files | ForEach-Object {[pscustomobject]@{Name=$_.Name;Token=$_.Token;Busy=$false}}}
function Add-OrbyDropFilesDirect($Root,$Adapter,$Composer,[string[]]$Files){Assert-OrbyDropTarget $Root $Adapter;Invoke-ChatButton (Find-ChatButton $Root '^Add files$')}
function Test-OrbyDropWindow($Root,$Adapter){return $Root.Current.NativeWindowHandle -eq $Operation.FixtureHwnd}
function Assert-OrbyDropTarget($Root,$Adapter){Assert-OrbyDropActive;if(-not (Test-OrbyDropWindow $Root $Adapter)){throw 'Wrong fixture window'}}
'@
if($RealPaste){$injection=$injection.Replace("Invoke-ChatButton (Find-ChatButton `$Root '^Add files`$')",'Paste-OrbyFiles $Composer $Files $script:chatHwnd')}
$workerText=$workerText.Replace("$([char]36)sendInvoked=$([char]36)false;$([char]36)stage='Validate request'",$injection+"`n$([char]36)sendInvoked=$([char]36)false;$([char]36)stage='Validate request'")
function Pump { $f=[Windows.Threading.DispatcherFrame]::new();$timer=[Windows.Threading.DispatcherTimer]::new();$timer.Interval=[timespan]::FromMilliseconds(25);$timer.Add_Tick({$timer.Stop();$f.Continue=$false}.GetNewClosure());$timer.Start();[Windows.Threading.Dispatcher]::PushFrame($f) }
$checks=0
try{
 foreach($id in @('chatgpt','claude','gemini')){
  foreach($prompt in @('','Summarize this local fixture.','CANCEL-FIXTURE','FAST-FILE-ONLY','TRUNCATED','DELAYED-MESSAGE')){
   $state.Truncated=($prompt -eq 'TRUNCATED');$state.Delayed=($prompt -eq 'DELAYED-MESSAGE');$state.PromptBeforeUploadReady='';$state.FastComplete=($prompt -eq 'FAST-FILE-ONLY');$actualPrompt=if($state.FastComplete){''}elseif($state.Delayed -or $state.Truncated){'check this'}else{$prompt};$new.Content=if($id -eq 'claude'){'New'}else{'New chat'};$state.CancelAfterAttach=($prompt -eq 'CANCEL-FIXTURE');$state.New=0;$state.Send=0;$state.Attach=0;$state.Opened=0;$state.InitialLookup=$true;$state.FixtureHwnd=$handle.ToInt64();$state.Cancelled=$false;$state.SendInvoked=$false
   [Windows.Automation.AutomationProperties]::SetName($composer,$(switch($id){chatgpt{'Message ChatGPT'}claude{'Reply to Claude'}gemini{'Ask Gemini'}}))
   $composer.Text='Existing draft must be replaced only by New chat'
   $runspace=[runspacefactory]::CreateRunspace();$runspace.ApartmentState='STA';$runspace.Open();$worker=[powershell]::Create();$worker.Runspace=$runspace
   [void]$worker.AddScript($workerText).AddArgument(@($fixture)).AddArgument($actualPrompt).AddArgument($PSScriptRoot).AddArgument($id).AddArgument($state)
   $job=$worker.BeginInvoke();$deadline=[datetime]::UtcNow.AddSeconds(35)
   while(-not $job.IsCompleted -and [datetime]::UtcNow -lt $deadline){Pump}
   if(-not $job.IsCompleted){$worker.Stop();throw 'Fixture timed out'}
   $result=@($worker.EndInvoke($job)) | Select-Object -Last 1
   if($state.CancelAfterAttach){if($result.Sent -or $state.Send -ne 0 -or $state.SendInvoked){throw 'Cancelled upload reached Send'};$checks++;$worker.Dispose();$runspace.Dispose();continue}
   if(-not $result.Sent){throw ($id+' failed: '+$result.Message+' fixtureText='+$composer.Text+' expected='+$actualPrompt+' '+($worker.Streams.Error -join ';'))};$checks++
   if($state.New -ne 1 -or $state.Attach -ne 1 -or $state.Send -ne 1 -or $state.Opened -ne 1){throw 'Launch, new chat, attach, Send must each run once'};$checks++
   if($state.Prompt -cne $actualPrompt){throw 'Optional prompt changed'};$checks++
   if(-not $state.SendInvoked){throw 'Send boundary not recorded'};$checks++
   if($state.Delayed){if($state.PromptBeforeUploadReady -cne $actualPrompt){throw 'Message was not inserted before upload finished'};$checks++}
   $worker.Dispose();$runspace.Dispose()
  }
 }
 "PASS: $checks real UIA worker fixture checks across three providers, with messages, file-only requests and fast file-only completion. No network requests or real AI sends. Launch and provider identity are simulated. Real clipboard delivery: $RealPaste. Truncated Python filenames and early message placement are checked."
}finally{$uploadTimer.Stop();if($worker){$worker.Dispose()};if($runspace){$runspace.Dispose()};$window.Close();Remove-Item -LiteralPath $fixture -Force}
