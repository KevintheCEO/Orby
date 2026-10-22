param([string]$PreviewDirectory='')
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Xaml
. (Join-Path $PSScriptRoot 'Orb-Avatar.ps1')
. (Join-Path $PSScriptRoot 'Motion.ps1')
Add-Type -Path (Join-Path $PSScriptRoot 'Provider-Reader.cs') -ReferencedAssemblies UIAutomationClient,UIAutomationTypes,WindowsBase,System.Core
[xml]$x=Get-Content (Join-Path $PSScriptRoot 'Reference-Home.xaml') -Raw
$script:referenceHome=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($x));$script:referenceControls=@{}
foreach($m in [regex]::Matches($x.OuterXml,'x:Name="([^"]+)"')){$n=$m.Groups[1].Value;$script:referenceControls[$n]=$script:referenceHome.FindName($n)}
$window=[Windows.Window]::new();$window.Content=$script:referenceHome;$window.Width=640;$window.Height=230;$window.ShowActivated=$false
$script:providerDirectory=$PSScriptRoot
. (Join-Path $PSScriptRoot 'Provider-Icons.ps1');Initialize-OrbyProviderIcons
$script:providerCatalog=@{chatgpt=@{Name='ChatGPT'};claude=@{Name='Claude'};gemini=@{Name='Gemini'}}
$source=Get-Content (Join-Path $PSScriptRoot 'Providers.ps1') -Raw
$functions=$source.Substring($source.IndexOf('function Get-OrbyProviderSnapshot'),$source.IndexOf('. (Join-Path $PSScriptRoot ''Multi-Provider.ps1'')')-$source.IndexOf('function Get-OrbyProviderSnapshot'))
. ([scriptblock]::Create($functions))
$script:orbySettings=@{PrimaryProvider='chatgpt';ProviderEnabled='chatgpt,claude';ReducedMotion=$false;EyeEffects=$true}
$now=[datetime]::UtcNow
$script:orbyShared=@{ProviderPresence=@{At=$now;Names=@('Claude','ChatGPT')};ProviderSnapshots=@(
 [OrbyProviderSnapshot]@{Provider='claude';AppOpen=$true;Connected=$true;StatusReadable=$true;State='working';Detail='Generating a response';At=$now},
 [OrbyProviderSnapshot]@{Provider='chatgpt';AppOpen=$true;Connected=$true;StatusReadable=$true;State='idle';Detail='Ready';At=$now})}
function Get-NotchTaskTitle {return 'Example project'}
function Save-OrbySettings {}
function Open-OrbyProvider($Id) {$script:lastOpenedProvider=$Id}
function Show-OrbyConnections {}
function Update-OrbyHome {}
function Set-OrbyHomePage($Page){$script:referenceControls.RefHomePage.Visibility=if($Page -eq 'home'){'Visible'}else{'Collapsed'};$script:referenceControls.RefAgentsPage.Visibility=if($Page -eq 'agents'){'Visible'}else{'Collapsed'}}
. (Join-Path $PSScriptRoot 'Multi-Provider.ps1')
$script:expanded=$true
Initialize-OrbyMultiProvider
function Assert($ok,$why){if(-not $ok){throw $why}}
Assert ($script:providerCards.Count -eq 2) 'Two independent cards missing'
$script:referenceHome.Measure([Windows.Size]::new(624,180));$script:referenceHome.Arrange([Windows.Rect]::new(0,0,624,180));$script:referenceHome.UpdateLayout()
foreach($card in $script:providerCards.Values){Assert ($card.View.ActualWidth -gt 150 -and $card.Controls.Title.ActualWidth -gt 65) 'Provider text area clipped'}
Assert ($script:providerCards.claude.Renderer.ActiveId -eq 'working_normal') 'Claude generation state lost'
Assert ($script:providerNav.claude.Visibility -eq 'Visible' -and $script:providerNav.chatgpt.Visibility -eq 'Visible') 'Both logos must be visible'
Select-OrbyProviderPage 'claude'
Assert ($script:orbySettings.ProviderEnabled -eq 'chatgpt,claude') 'Selecting Claude disconnected ChatGPT'
Assert ($script:referenceControls.RefProviderIcon.Data -eq $script:openAiLogo) 'OpenAI button changed into Claude'
Select-OrbyProviderPage 'chatgpt';Set-OrbyHomePage 'home';Update-OrbyMultiProvider
Assert ($script:providerCards.claude.Buddies.Count -eq 4 -and $script:providerCards.chatgpt.Buddies.Count -eq 4) 'Companions missing'
$model=[OrbyProviderLifecycle]::new()
Assert ($model.Evaluate('claude',$true,$false,$false,'unknown',$now).Sleeping) 'Closed app must sleep'
Assert (-not $model.Evaluate('claude',$true,$true,$false,'unknown',$now).Sleeping) 'Unreadable open app mistaken for sleep'
[void]$model.Evaluate('claude',$true,$true,$true,'idle',$now)
Assert ($model.Evaluate('claude',$true,$true,$true,'idle',$now.AddMinutes(11)).Sleeping) 'Long idle did not sleep'
Assert (-not $model.Evaluate('claude',$true,$true,$true,'working',$now.AddMinutes(12)).Sleeping) 'Working provider did not wake'
Assert ($model.Evaluate('chatgpt',$true,$true,$true,'working',$now.AddHours(5)).State -eq 'working') 'Long task put to sleep'
Assert (-not $model.Evaluate('claude',$false,$false,$false,'unknown',$now.AddHours(5)).Sleeping) 'Stale scan falsely claimed closed'
$script:orbyShared.ProviderSnapshots=@();$script:orbyShared.ProviderPresence=@{At=[datetime]::UtcNow;Names=@()}
Update-OrbyMultiProvider
foreach($card in $script:providerCards.Values){
 foreach($r in @($card.Renderer)+@($card.Buddies | ForEach-Object {$_.Renderer})){$r.Draw(2);Assert ($r.ActiveId -eq 'sleep_afk') 'Avatar did not use sleep animation'}
 $eye=$card.Parts.OrbEyeL.RenderTransform.Children[0]
 Assert ($eye.ScaleY -le .12 -and $eye.ScaleX -gt 1) 'Sleep eyes are not horizontal lines'
}
if($PreviewDirectory){
 [void][IO.Directory]::CreateDirectory($PreviewDirectory)
 function Save-Preview($Name){
  $script:referenceHome.Measure([Windows.Size]::new(624,180));$script:referenceHome.Arrange([Windows.Rect]::new(0,0,624,180));$script:referenceHome.UpdateLayout()
  $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new(1248,360,192,192,[Windows.Media.PixelFormats]::Pbgra32);$bitmap.Render($script:referenceHome)
  $enc=[Windows.Media.Imaging.PngBitmapEncoder]::new();$enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap));$f=[IO.File]::Create((Join-Path $PreviewDirectory $Name));try{$enc.Save($f)}finally{$f.Dispose()}
 }
 Save-Preview 'sleeping.png'
 $script:orbyShared.ProviderPresence=@{At=[datetime]::UtcNow;Names=@('Claude','ChatGPT')}
 $script:orbyShared.ProviderSnapshots=@([OrbyProviderSnapshot]@{Provider='claude';AppOpen=$true;State='unknown';Detail='App open';At=[datetime]::UtcNow},[OrbyProviderSnapshot]@{Provider='chatgpt';AppOpen=$true;Connected=$true;StatusReadable=$true;State='working';Detail='Generating';At=[datetime]::UtcNow})
 Update-OrbyMultiProvider
 foreach($card in $script:providerCards.Values){$card.Renderer.Draw($card.Renderer.TimeSeconds+2);foreach($b in $card.Buddies){$b.Renderer.Draw($b.Renderer.TimeSeconds+2)}}
 Save-Preview 'simultaneous.png'
}
# An unreadable app remains uncertain internally, with ordinary lively idle visuals.
$script:orbyShared.ProviderPresence=@{At=[datetime]::UtcNow;Names=@('Claude','ChatGPT')}
$script:orbyShared.ProviderSnapshots=@([OrbyProviderSnapshot]@{Provider='claude';AppOpen=$true;State='unknown';Detail='App open · waiting for activity';At=[datetime]::UtcNow},[OrbyProviderSnapshot]@{Provider='chatgpt';AppOpen=$true;Connected=$true;StatusReadable=$true;State='idle';Detail='Ready for your next chat';At=[datetime]::UtcNow})
Update-OrbyMultiProvider
Assert ((Get-OrbyIndependentStatus claude).State -eq 'unknown' -and -not (Get-OrbyIndependentStatus claude).Readable) 'Friendly display fabricated a readable Claude status'
Assert ($script:providerCards.claude.Controls.Title.Text -eq 'App open' -and $script:referenceControls.RefConnection.Text -notmatch 'unknown|unavailable|sign.in') 'Uncertain telemetry shown as sign-in failure'
$script:chatConnectionPresent=$true;$script:chatLogState='idle'
$script:orbyShared.ProviderSnapshots[1].StatusReadable=$false;$script:orbyShared.ProviderSnapshots[1].State='unknown';$script:orbyShared.ProviderSnapshots[1].Detail='App open · chat controls unavailable or sign-in needed'
Assert ((Get-OrbyIndependentStatus chatgpt).Detail -eq 'Ready for your next chat') 'Unreadable UI label overrode the real ChatGPT feed'
$script:chatConnectionPresent=$false;$script:orbyShared.ProviderSnapshots[1].StatusReadable=$true;$script:orbyShared.ProviderSnapshots[1].State='idle';$script:orbyShared.ProviderSnapshots[1].Detail='Ready for your next chat'
$family=@($script:providerCards.claude.Renderer)+@($script:providerCards.claude.Buddies | ForEach-Object {$_.Renderer})
$delays=@();$gestures=@()
foreach($r in $family){
 $r.EyeEffects=$false;$r.Draw($r.TimeSeconds+2);$delays+=$r.NextIdleAt;$nowIdle=$r.NextIdleAt
 $r.AdvanceIdle($nowIdle,$false);$gestures+=$r.ActiveId
 Assert ($r.ActiveId -in [OrbyAvatarRenderer]::IdleGestures -and $null -eq $r.SyncWith) 'Claude family locked or synchronized'
 $before=$r.ActiveId;$r.SetState('idle','Another reader update');Assert ($r.ActiveId -eq $before) 'Polling restarted Claude personality'
 $clip=[OrbyPack.Catalog]::ById[$r.ActiveId];$r.Draw($nowIdle+$clip.Duration/1000.0+.1)
}
Assert (@($delays | Select-Object -Unique).Count -gt 1 -and @($gestures | Select-Object -Unique).Count -gt 1) 'Claude pets share their timing or gesture'
$left=$script:providerCards.claude.Renderer;$right=$script:providerCards.chatgpt.Renderer;$right.Draw($right.TimeSeconds+2)
$script:nextNeighborGlance=[datetime]::UtcNow.AddSeconds(-1);Update-OrbyNeighborGlance $true
$left.Draw($left.TimeSeconds+1.2);$right.Draw($right.TimeSeconds+1.2)
Assert ($left.NeighborEyeOffset -gt .5 -and $right.NeighborEyeOffset -lt -.5) 'Neighbors did not glance toward each other'
$left.Draw($left.TimeSeconds+3);Assert ($left.NeighborEyeOffset -eq 0) 'Neighbor glance did not end'
$left.SetState('working','Generating');Assert (-not $left.GlanceAtNeighbor(1)) 'Neighbor glance interrupted active work'
$right.ReducedMotion=$true;Assert (-not $right.GlanceAtNeighbor(-1)) 'Neighbor glance ignored reduced motion'
# Every supported provider can coexist. Three providers use two rows rather than squeezing text.
$script:orbySettings.ProviderEnabled='chatgpt,claude,gemini';Update-OrbyMultiProvider
Assert ($script:multiHome.Children.Count -eq 3 -and $script:multiHome.RowDefinitions.Count -eq 2) 'Three-provider layout squeezed into one row'
Assert ($script:referenceHome.Height -eq 254) 'Third provider panel did not resize'
$script:providerCards.claude.Controls.Menu.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
Assert ($script:providerCards.claude.Controls.Menu.ContextMenu.IsOpen) 'Provider options did not open'
$script:providerCards.claude.Controls.Menu.ContextMenu.IsOpen=$false
$disconnect=$script:providerCards.claude.Controls.Menu.ContextMenu.Items[2]
$disconnect.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.MenuItem]::ClickEvent))
Assert ('claude' -notin (Get-OrbyPairedProviders) -and 'chatgpt' -in (Get-OrbyPairedProviders)) 'Disconnect affected another AI'
Assert ($script:providerCards.claude.Renderer.Suspended) 'Disconnected avatar kept rendering'
$window.Close()
'PASS: simultaneous cards/logos, account selection isolation, 10-minute sleep, closed-app sleep, stale/unknown safety, long-task wake protection and line eyes.'
