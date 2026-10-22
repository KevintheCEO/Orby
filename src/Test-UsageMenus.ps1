$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Test-AllLargeMenus.ps1') -KeepWindow
$script:usageChecks=0
function CheckUsage($ok,$why){if(-not $ok){throw $why};$script:usageChecks++}
function Start-Process {param($FilePath) $script:openedUsage=$FilePath}
$script:orbySettings.ProviderEnabled='chatgpt,claude,gemini'
try {
 foreach($id in @('claude','gemini')){
  $address=if($id -eq 'claude'){'https://claude.ai/settings/usage'}else{'https://gemini.google.com/usage'}
  $q=[OrbyProviderUsage]::Parse($id,$address,"Current session`n20% used`nWeekly usage`n65% used")
  $script:orbyShared.ProviderSnapshots=@([OrbyProviderSnapshot]@{Provider=$id;UsagePage=$true;Usage=$q;At=[datetime]::UtcNow})
  Select-OrbyProviderPage $id;Layout;Update-OrbyCompactMenus
  $u=$script:compactMenuControls
  CheckUsage ($u.LocalSessionPercent.Text -eq '80% remaining' -and $u.LocalWeekPercent.Text -eq '35% remaining') 'Provider quota values not shown'
  CheckUsage ($u.LocalSessionBar.Value -eq 80 -and $u.LocalWeekBar.Value -eq 35 -and $u.LocalSessionBar.Visibility -eq 'Visible') 'Provider bars disagree with labels'
  $u.LocalUsageOpen.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
  CheckUsage ($script:openedUsage -eq $address) 'Open usage chose the wrong provider'
  CheckUsage (($u.LocalCodeSync.Visibility -eq 'Visible') -eq ($id -eq 'claude')) 'Gemini incorrectly shows Claude sync control'
  $script:orbyShared.ProviderSnapshots[0].At=[datetime]::UtcNow.AddSeconds(-9);Update-OrbyCompactMenus
  CheckUsage ($u.LocalSessionPercent.Text -eq 'Not available' -and $u.LocalSessionBar.Visibility -eq 'Hidden') 'Expired quota remained live'
  $script:orbyShared.ProviderSnapshots[0].At=[datetime]::UtcNow.AddMinutes(2);Update-OrbyCompactMenus
  CheckUsage ($u.LocalSessionPercent.Text -eq 'Not available') 'Future quota was accepted'
  $script:orbyShared.ProviderSnapshots=@();Update-OrbyCompactMenus
  CheckUsage ($u.LocalWeekPercent.Text -eq 'Not available') 'Disconnected provider inherited another account quota'
 }
 $first=[OrbyProviderUsage]::Parse('claude','https://claude.ai/settings/usage','Current session 20% used')
 $second=[OrbyProviderUsage]::Parse('claude','https://claude.ai/settings/usage','Current session 80% used')
 $script:orbyShared.ProviderSnapshots=@([OrbyProviderSnapshot]@{Provider='claude';UsagePage=$true;Usage=$first},[OrbyProviderSnapshot]@{Provider='claude';UsagePage=$true;Usage=$second})
 Select-OrbyProviderPage 'claude';Update-OrbyCompactMenus
 CheckUsage ($u.LocalSessionPercent.Text -eq 'Not available' -and $u.LocalUsageNote.Text.StartsWith('Multiple usage pages')) 'Conflicting account windows were silently combined'
 "PASS: $script:usageChecks real menu usage checks for Claude and Gemini, URL actions, fresh/missing/expired/future data and conflicting accounts."
}finally{$window.Close();foreach($avatar in $script:compactMenuAvatars.Values){$avatar.Renderer.Dispose()}}
