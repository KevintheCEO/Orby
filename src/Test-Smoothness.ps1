$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework
Add-Type -Path @((Join-Path $PSScriptRoot 'Output-Volume.cs'),(Join-Path $PSScriptRoot 'Test-VolumeChannel.cs'))
Add-Type -Path @((Join-Path $PSScriptRoot 'Liquid-Surface.cs'),(Join-Path $PSScriptRoot 'Coucou-Motion.cs')) -ReferencedAssemblies WindowsBase,PresentationCore,PresentationFramework,System.Xaml
function Assert($ok,$why){if(-not $ok){throw $why}}
function Pump($seconds){$f=[Windows.Threading.DispatcherFrame]::new();$timer=[Windows.Threading.DispatcherTimer]::new();$timer.Interval=[timespan]::FromSeconds($seconds);$timer.Add_Tick({$timer.Stop();$f.Continue=$false}.GetNewClosure());$timer.Start();[Windows.Threading.Dispatcher]::PushFrame($f)}
[VolumeFixture]::Channel.Refresh();Assert ([VolumeFixture]::Started.WaitOne(1000)) 'Background endpoint did not start'
$watch=[Diagnostics.Stopwatch]::StartNew();foreach($i in 0..99){[void][VolumeFixture]::Channel.Set($i)};$watch.Stop()
Assert ($watch.ElapsedMilliseconds -lt 100) 'Slider writes blocked behind audio endpoint'
$script:beats=0;$beat=[Windows.Threading.DispatcherTimer]::new();$beat.Interval=[timespan]::FromMilliseconds(10);$beat.Add_Tick({$script:beats++});$beat.Start();Pump .2;$beat.Stop()
Assert ($script:beats -ge 3 -and [VolumeFixture]::Channel.Busy) 'UI heartbeat stalled during blocked audio call'
[void][VolumeFixture]::Release.Set();$deadline=[datetime]::UtcNow.AddSeconds(3);while([VolumeFixture]::Channel.Busy -and [datetime]::UtcNow -lt $deadline){Pump .01}
$snapshot=[VolumeFixture]::Channel.Snapshot
Assert ($snapshot.Value -eq 99 -and $snapshot.Revision -eq 100) 'Latest slider value lost'
Assert ([VolumeFixture]::Maximum -eq 1 -and [VolumeFixture]::Calls -eq 2) 'Drag commands piled up or ran concurrently'
[VolumeFixture]::Fail=$true;[void][VolumeFixture]::Channel.Set(20);while([VolumeFixture]::Channel.Busy){Pump .01}
Assert ([VolumeFixture]::Channel.Snapshot.Error -eq 'Test unavailable') 'Audio failure escaped worker'
[VolumeFixture]::Fail=$false;[void][VolumeFixture]::Channel.Set(120);while([VolumeFixture]::Channel.Busy){Pump .01}
Assert ([VolumeFixture]::Channel.Snapshot.Value -eq 100 -and -not [VolumeFixture]::Channel.Snapshot.Error) 'Worker failed to recover or clamp value'
$surface=[OrbyLiquidSurface]::new();$window=[Windows.Window]::new();$window.ShowActivated=$false;$window.Content=$surface;$window.Show()
foreach($cycle in 1..150){[OrbyMotion.Driver]::Move($surface,[OrbyLiquidSurface]::MorphProperty,1,$true);[OrbyMotion.Driver]::Move($surface,[OrbyLiquidSurface]::MorphProperty,0,$false)}
Assert ([OrbyMotion.Driver]::PendingCount -eq 1) 'Hover reversals created an animation backlog'
[OrbyMotion.Driver]::Snap($surface,[OrbyLiquidSurface]::MorphProperty,0);Pump .15
Assert ($surface.Morph -eq 0 -and [OrbyMotion.Driver]::PendingCount -eq 0) 'Canceled spring changed restored surface'
[OrbyMotion.Driver]::Move($surface,[OrbyLiquidSurface]::MorphProperty,1,$true);Pump .6
[OrbyMotion.Driver]::Move($surface,[OrbyLiquidSurface]::MorphProperty,0,$false);Pump .6
Assert ([math]::Abs($surface.Morph) -lt .01) 'Hover motion failed to settle'
[OrbyMotion.Driver]::StopAll();$window.Close()
'PASS: 100 slider updates coalesced behind blocked audio; UI heartbeat remained live; endpoint failure/recovery; 150 hover reversals; spring cancellation/settlement; animation cleanup.'
