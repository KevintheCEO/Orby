param([string]$PreviewDirectory='')
$ErrorActionPreference='Stop'
$inlinePreview=$PreviewDirectory
. (Join-Path $PSScriptRoot 'Test-AllLargeMenus.ps1') -KeepWindow
$PreviewDirectory=$inlinePreview
$script:inlineChecks=0
function CheckInline($ok,$why){if(-not $ok){throw $why};$script:inlineChecks++}
function Start-Process {param($FilePath) $script:inlineOpened=$FilePath}
function Open-OrbyProvider($Id){$script:inlineLaunched+=$Id}
function Update-OrbyAccountUsage {$script:inlineRefreshed=$true}
$script:orbySettings.ProviderEnabled='chatgpt,claude,gemini';$script:expanded=$true;$script:fullscreenHidden=$false;$script:orbySettings.ReducedMotion=$true
try {
 $reset=[DateTimeOffset]::UtcNow.AddHours(1).ToUnixTimeSeconds();$weekReset=[DateTimeOffset]::UtcNow.AddDays(2).ToUnixTimeSeconds()
 $script:usageSnapshot=[OrbyUsageSnapshot]::new();$script:usageSnapshot.Connected=$true
 $script:usageSnapshot.LimitsJson='{"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":20,"windowDurationMins":300,"resetsAt":'+$reset+'},"secondary":{"usedPercent":60,"windowDurationMins":10080,"resetsAt":'+$weekReset+'}}}}'
 $script:orbyShared.ProviderSnapshots=@()
 foreach($id in @('claude','gemini')){
  $url=if($id -eq 'claude'){'https://claude.ai/settings/usage'}else{'https://gemini.google.com/usage'}
  $q=[OrbyProviderUsage]::Parse($id,$url,"Current session`n20% used`nWeekly usage`n60% used")
  $script:orbyShared.ProviderSnapshots+=[OrbyProviderSnapshot]@{Provider=$id;UsagePage=$true;Usage=$q;At=[datetime]::UtcNow}
 }
 foreach($id in @('chatgpt','claude','gemini')){
  $script:usageSnapshot.At=[datetime]::UtcNow
  foreach($snapshot in $script:orbyShared.ProviderSnapshots){$snapshot.At=[datetime]::UtcNow}
  Select-OrbyCompanion $id;Set-OrbyAIChooser $true;Layout
  $card=$script:providerCards[$id];$c=$card.Controls
  CheckInline ($script:compactMenuPage -eq 'home' -and $script:companionSelection -eq $id) 'Selecting an AI navigated away from the shared main tab'
  CheckInline ($c.InlineSessionValue.Text -eq '80% remaining' -and $c.InlineWeekValue.Text -eq '40% remaining') 'Main card quotas did not bind to this provider'
  CheckInline ($c.InlineSessionBar.Value -eq 80 -and $c.InlineWeekBar.Value -eq 40 -and $c.InlineSessionBar.IsVisible) 'Main card bars hidden or wrong'
  CheckInline ($c.InlineSessionLabel.Text -eq '5-hour window' -and $c.InlineWeekLabel.Text -eq 'Weekly usage') 'Main card window labels unclear'
  foreach($control in @($c.InlineSessionBar,$c.InlineWeekBar,$c.InlineUsageAction,$c.InlineWeekValue)){
   $p=$control.TranslatePoint([Windows.Point]::new($control.ActualWidth-1,$control.ActualHeight-1),$notch)
   CheckInline ($notch.Clip.FillContains($p)) 'Main card usage control was clipped by the notch'
  }
  CheckInline (@($c.Menu.ContextMenu.Items | Where-Object {$_.Header -eq 'AI status'}).Count -eq 0) 'Usage still requires the removed AI Status menu'
  $script:inlineLaunched=@();$c.InlineUsageAction.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
  CheckInline ($script:inlineLaunched.Count -eq 0) 'Usage action accidentally launched the AI app'
  if($id -eq 'chatgpt'){CheckInline $script:inlineRefreshed 'ChatGPT refresh did not use the existing background feed'}else{CheckInline ($script:inlineOpened -eq $(if($id -eq 'claude'){'https://claude.ai/settings/usage'}else{'https://gemini.google.com/usage'})) 'Usage button opened the wrong account'}
  Invoke-OrbyAvatarClick $id 1;CheckInline ($script:inlineLaunched.Count -eq 0) 'Single avatar click launched the app'
  Invoke-OrbyAvatarClick $id 2;CheckInline ($script:inlineLaunched.Count -eq 1 -and $script:inlineLaunched[0] -eq $id) 'Double-click did not open the chosen provider exactly once'
  if($PreviewDirectory){
   [void][IO.Directory]::CreateDirectory($PreviewDirectory)
   $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new(668,384,96,96,[Windows.Media.PixelFormats]::Pbgra32);$bitmap.Render($window.Content)
   $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap));$file=[IO.File]::Create((Join-Path $PreviewDirectory ($id+'-inline-sample.png')));try{$encoder.Save($file)}finally{$file.Dispose()}
  }
 }
 CheckInline ($null -eq (Get-OrbyProviderSnapshot 'claude')) 'An account Usage page was treated as a chat/app window'
 $providerAst=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'Providers.ps1'),[ref]$null,[ref]$null)
 $openFunction=$providerAst.Find({param($node)$node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Open-OrbyProvider'},$true)
 Set-Item Function:Open-OrbyProvider $openFunction.Body.GetScriptBlock()
 function Get-Process {[CmdletBinding()]param([string]$Name) @()}
 function Get-StartApps {[CmdletBinding()]param() [pscustomobject]@{Name='Claude';AppID='Orby.Test.InstalledClaude'}}
 function Start-Process {param($FilePath,$ArgumentList) $script:inlineOpened=$FilePath;$script:inlineLaunchArguments=$ArgumentList}
 $script:providerCatalog.claude.Process='Claude'
 Open-OrbyProvider 'claude'
 CheckInline ($script:inlineOpened -eq 'explorer.exe' -and $script:inlineLaunchArguments -eq 'shell:AppsFolder\Orby.Test.InstalledClaude') 'Closed app launch focused the usage page instead of opening the installed AI'
 $script:usageSnapshot.At=[datetime]::UtcNow.AddMinutes(-4);Select-OrbyCompanion 'chatgpt';Update-OrbyMultiProvider
 CheckInline ($script:providerCards.chatgpt.Controls.InlineSessionValue.Text -eq 'Not available') 'Expired Codex quota remained visible as live data'
 $script:orbyShared.ProviderSnapshots=@();Select-OrbyCompanion 'claude';Update-OrbyMultiProvider
 CheckInline ($script:providerCards.claude.Controls.InlineSessionValue.Text -eq 'Not available' -and $script:providerCards.claude.Controls.InlineSessionBar.IsVisible) 'Missing quota should keep an explicitly unavailable track in the main tab'
 "PASS: $script:inlineChecks inline quota, selection, clipping, freshness, direct action and double-click routing assertions."
}finally{$window.Close()}
