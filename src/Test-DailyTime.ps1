$ErrorActionPreference='Stop'
Add-Type -Path (Join-Path $PSScriptRoot 'Hydration-Model.cs')
$start=[datetime]'2026-10-09T08:00:00';$c=[OrbyWater.ActiveDayClock]::new();$c.Restore('2026-10-09',0,$start);$c.Tick($start,$true)
for($i=1;$i -le 14400;$i++){$c.Tick($start.AddSeconds($i),$true)}
if($c.ActiveSeconds -ne 14400){throw 'Morning session not counted'}
$c.Restore('2026-10-09',$c.ActiveSeconds,[datetime]'2026-10-09T17:00:00');$c.Tick([datetime]'2026-10-09T17:00:00',$true)
for($i=1;$i -le 7200;$i++){$c.Tick(([datetime]'2026-10-09T17:00:00').AddSeconds($i),$true)}
if($c.ActiveSeconds -ne 21600){throw 'Break counted or sessions not combined'}
$c.Tick([datetime]'2026-10-09T23:59:59',$false)
if($c.ActiveSeconds -ne 21600){throw 'Inactive time counted'}
$c.Tick([datetime]'2026-10-10T00:00:00',$true)
if($c.ActiveSeconds -ne 0 -or $c.Date -ne '2026-10-10'){throw 'Midnight reset failed'}
'PASS: 08:00-12:00 plus 17:00-19:00 = six hours, five-hour break excluded, restart resume, idle exclusion and midnight reset.'
