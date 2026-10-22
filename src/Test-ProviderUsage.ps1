$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework
Add-Type -Path (Join-Path $PSScriptRoot 'Provider-Reader.cs') -ReferencedAssemblies UIAutomationClient,UIAutomationTypes,WindowsBase,System.Core
function Check($ok,$why){if(-not $ok){throw $why};$script:checks++}
$url='https://claude.ai/settings/usage';$gemini='https://gemini.google.com/usage'
$text="Current session`nResets in 2h 30m`n20% used`nWeekly limits`nAll models`nResets Friday 11am`n65% used`nSonnet only`n95% used"
$q=[OrbyProviderUsage]::Parse('claude',$url,$text)
Check ($q.SessionRemaining -eq 80 -and $q.WeekRemaining -eq 35) 'Claude remaining calculation or model isolation failed'
Check ($q.SessionReset -eq 'Resets in 2h 30m' -and $q.WeekReset -eq 'Resets Friday 11am') 'Reset text lost'
$q=[OrbyProviderUsage]::Parse('gemini',$gemini,"5-hour usage`n40% remaining`nRefreshes in 3 hours`nWeekly usage`n72% remaining")
Check ($q.SessionRemaining -eq 40 -and $q.WeekRemaining -eq 72) 'Gemini window mapping failed'
foreach($address in @('https://claude.ai/chat/123','https://claude.ai/settings/usage/fake','http://claude.ai/settings/usage','https://claude.ai.evil.test/settings/usage','https://evil.test/?url=https://claude.ai/settings/usage','https://user@claude.ai/settings/usage','https://claude.ai:444/settings/usage')){Check ($null -eq [OrbyProviderUsage]::Parse('claude',$address,$text)) 'Untrusted or non-usage page accepted'}
Check ([OrbyProviderUsage]::IsPage('gemini','https://gemini.google.com/u/1/usage')) 'Gemini account-index path rejected'
foreach($bad in @('Current session 101% used','Current session -5% used','Current session 20% used 30% used','Current session 90%','Context window 80% used','API usage 20% used','Sign in')){Check ($null -eq [OrbyProviderUsage]::Parse('claude',$url,$bad)) 'Ambiguous, invalid, context or API quota guessed'}
$q=[OrbyProviderUsage]::Parse('claude',$url,"Current session`n0% used`nWeekly limits`nAll models`n100% used")
Check ($q.SessionRemaining -eq 100 -and $q.WeekRemaining -eq 0) 'Zero/full limits confused with unavailable'
$q=[OrbyProviderUsage]::Parse('gemini',$gemini,'Weekly usage 25% used')
Check ($null -eq $q.SessionRemaining -and $q.WeekRemaining -eq 75) 'Missing window was fabricated'
function Pump { $f=[Windows.Threading.DispatcherFrame]::new();$timer=[Windows.Threading.DispatcherTimer]::new();$timer.Interval=[timespan]::FromMilliseconds(25);$timer.Add_Tick({$timer.Stop();$f.Continue=$false}.GetNewClosure());$timer.Start();[Windows.Threading.Dispatcher]::PushFrame($f) }
# Use a second runspace so UI Automation does not block its own WPF dispatcher.
$w=[Windows.Window]::new();$w.Width=500;$w.Height=450;$w.ShowActivated=$false
$body=[Windows.Controls.StackPanel]::new();$w.Content=$body
$address=[Windows.Controls.TextBox]::new();$address.Text=$url;[Windows.Automation.AutomationProperties]::SetName($address,'Address and search bar');[void]$body.Children.Add($address)
foreach($line in $text.Split("`n")){$t=[Windows.Controls.TextBlock]::new();$t.Text=$line;$t.Margin='0,3,0,3';[void]$body.Children.Add($t)}
$w.Show();Pump
$runspace=[runspacefactory]::CreateRunspace();$runspace.ApartmentState='MTA';$runspace.Open();$reader=[powershell]::Create();$reader.Runspace=$runspace
try {
 [void]$reader.AddScript({param($source,$handle)
  Add-Type -Path $source -ReferencedAssemblies UIAutomationClient,UIAutomationTypes,WindowsBase,System.Core
  $method=[OrbyProviderReader].GetMethod('ReadWindow',[Reflection.BindingFlags]'NonPublic,Static')
  $allowed=[Collections.Generic.HashSet[string]]::new();[void]$allowed.Add('claude');[void]$allowed.Add('gemini')
  $method.Invoke($null,[object[]]@([IntPtr]$handle,'chrome',$allowed))
 }).AddArgument((Join-Path $PSScriptRoot 'Provider-Reader.cs')).AddArgument([Windows.Interop.WindowInteropHelper]::new($w).Handle.ToInt64())
 $pending=$reader.BeginInvoke();$deadline=[datetime]::UtcNow.AddSeconds(10)
 while(-not $pending.IsCompleted -and [datetime]::UtcNow -lt $deadline){Pump}
 Check $pending.IsCompleted 'Accessibility read timed out'
 $result=@($reader.EndInvoke($pending));if($reader.Streams.Error.Count){throw $reader.Streams.Error[0]}
 Check ($result.Count -eq 1 -and $result[0].UsagePage) 'Actual accessibility path did not recognize usage page'
 Check ($result[0].Usage.SessionRemaining -eq 80 -and $result[0].Usage.WeekRemaining -eq 35) 'Actual accessibility text/order did not reach quota parser'
}finally{$w.Close();$reader.Dispose();$runspace.Dispose()}
"PASS: $script:checks provider usage assertions, including actual WPF accessibility traversal; no account credentials accessed."
