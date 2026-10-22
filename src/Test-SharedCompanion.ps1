param([string]$PreviewDirectory='')
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Xaml
. (Join-Path $PSScriptRoot 'Orb-Avatar.ps1')
. (Join-Path $PSScriptRoot 'Motion.ps1')
Add-Type -Path (Join-Path $PSScriptRoot 'Liquid-Surface.cs') -ReferencedAssemblies WindowsBase,PresentationCore,PresentationFramework,System.Xaml
Add-Type -Path (Join-Path $PSScriptRoot 'Provider-Reader.cs') -ReferencedAssemblies UIAutomationClient,UIAutomationTypes,WindowsBase,System.Core
. (Join-Path $PSScriptRoot 'Account-Usage.ps1')
. (Join-Path $PSScriptRoot 'Reference-Home.ps1')
$window=[Windows.Window]::new();$window.Width=668;$window.Height=384;$window.ShowActivated=$false;$window.WindowStyle='None';$window.Background=[Windows.Media.Brushes]::Black
$expandedArea=[Windows.Controls.Grid]::new();$expandedArea.HorizontalAlignment='Center';$expandedArea.VerticalAlignment='Top';$expandedArea.Margin='0,8,0,0'
$notch=[OrbyLiquidSurface]::new();$notch.Morph=1;$notch.Child=$expandedArea;$window.Content=$notch
$script:orbySettings=@{PrimaryProvider='chatgpt';ProviderEnabled='chatgpt,claude';ReducedMotion=$false;EyeEffects=$true;NotchSize='mini';Music=$true;Sounds=$false;HideFullscreen=$true}
$script:orbyShared=@{Health=@{Network=$true;Battery=80};ProviderPresence=@{At=[datetime]::UtcNow;Names=@('Claude','ChatGPT')};ProviderSnapshots=@(
 [OrbyProviderSnapshot]@{Provider='claude';Source='chat';AppOpen=$true;Connected=$true;StatusReadable=$true;State='working';Detail='Writing a reply';At=[datetime]::UtcNow},
 [OrbyProviderSnapshot]@{Provider='chatgpt';AppOpen=$true;Connected=$true;StatusReadable=$true;State='working';Detail='Reviewing code';At=[datetime]::UtcNow})}
$script:chatConnectionPresent=$true;$script:chatLogState='working';$script:expanded=$true
function Save-OrbySettings {$script:savedCount++}
function Get-NotchTaskTitle {'Reviewing code'}
function Get-OrbyClaudeCodeSync {$false}
function Toggle-OrbyClaudeCodeSync {$script:codeClicked=$true}
function Open-OrbyProvider($Id){$script:lastOpened=$Id}
function Show-OrbyConnections {$script:connectionsClicked=$true}
function Show-OrbySettings {$script:moreClicked=$true}
function Send-OrbyMusicControl($Action,$Value,$TrackKey){$script:lastMusic=$Action}
function Get-OrbySmoothMusicPosition($m){return 64}
function Format-OrbyMusicTime($seconds){'{0}:{1:00}' -f [math]::Floor($seconds/60),($seconds%60)}
function Update-OrbyCompactTask {}
function Set-OrbitExpanded($Expand){$script:expanded=$Expand}
$script:providerDirectory=$PSScriptRoot
. (Join-Path $PSScriptRoot 'Provider-Icons.ps1');Initialize-OrbyProviderIcons
$script:providerCatalog=@{chatgpt=@{Name='ChatGPT'};claude=@{Name='Claude'};gemini=@{Name='Gemini'}}
$source=Get-Content (Join-Path $PSScriptRoot 'Providers.ps1') -Raw
$functions=$source.Substring($source.IndexOf('function Get-OrbyProviderSnapshot'),$source.IndexOf('. (Join-Path $PSScriptRoot ''Multi-Provider.ps1'')')-$source.IndexOf('function Get-OrbyProviderSnapshot'))
. ([scriptblock]::Create($functions))
# Keep fixture side effects local.
function Save-OrbySettings {$script:savedCount++}
function Open-OrbyProvider($Id){$script:lastOpened=$Id}
function Show-OrbyConnections {$script:connectionsClicked=$true}
$script:referenceHome=New-OrbyHome;[void]$expandedArea.Children.Add($script:referenceHome);$script:providerIconResources=$null;Initialize-OrbyProviderIcons
. (Join-Path $PSScriptRoot 'Multi-Provider.ps1');Initialize-OrbyMultiProvider
. (Join-Path $PSScriptRoot 'Compact-Menus.ps1')
function Assert($ok,$why){if(-not $ok){throw $why};$script:assertions++}
function Layout {
 $window.Content.Measure([Windows.Size]::new(668,384));$window.Content.Arrange([Windows.Rect]::new(0,0,668,384));$window.Content.UpdateLayout()
}
function Capture($name){
 if(-not $PreviewDirectory){return}
 [void][IO.Directory]::CreateDirectory($PreviewDirectory);Layout
 foreach($card in $script:providerCards.Values){$card.Renderer.Draw(1);foreach($b in $card.Buddies){$b.Renderer.Draw(1)}}
 foreach($a in $script:compactMenuAvatars.Values){$a.Renderer.Draw(1)}
 $height=[int]($script:compactMenus.Height+16)
 $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new(([int]$script:compactMenus.Width+56),$height,96,96,[Windows.Media.PixelFormats]::Pbgra32)
 $visual=[Windows.Media.DrawingVisual]::new();$dc=$visual.RenderOpen();$brush=[Windows.Media.VisualBrush]::new($script:compactMenus);$dc.DrawRectangle([Windows.Media.Brushes]::Black,$null,[Windows.Rect]::new(0,0,($script:compactMenus.Width+56),$height));$dc.DrawRectangle($brush,$null,[Windows.Rect]::new(28,8,$script:compactMenus.Width,$script:compactMenus.Height));$dc.Close();$bitmap.Render($visual)
 $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap));$fs=[IO.File]::Create((Join-Path $PreviewDirectory ($name+'.png')));try{$encoder.Save($fs)}finally{$fs.Dispose()}
}
$window.Show();$script:orbySettings.ReducedMotion=$true;Layout
Assert ($script:aiCompanionButton.Content.Children[0].Text -eq 'AI') 'Combined entry is not a single AI label'
Assert (@($script:providerNav.Values | Where-Object {$_.Visibility -eq 'Visible'}).Count -eq 0) 'Separate provider navigation is still visible'
Assert ($script:companionCardHost.Children.Count -eq 1 -and $script:compactMenus.Height -eq 310) 'Home did not use one compact shared card'
Assert ($script:aiChooser.Height -eq 0 -and -not $script:aiChooser.IsHitTestVisible) 'Hidden chooser intercepts input'
Capture 'shared-closed'
$script:orbySettings.ProviderEnabled='chatgpt,claude,gemini'
$script:orbyShared.ProviderPresence.Names=@('ChatGPT','Claude','Gemini')
$script:orbyShared.ProviderSnapshots+= [OrbyProviderSnapshot]@{Provider='gemini';AppOpen=$true;StatusReadable=$true;State='working';Detail='Generating a response';Hwnd=456;At=[datetime]::UtcNow}
Set-OrbyAIChooser $true;Layout
Assert ($script:aiChooser.Height -eq 44 -and $script:compactMenus.Height -eq 354) 'Chooser did not expand to its intended size'
Assert ($script:companionChoices.Count -eq 3 -and $script:aiChooser.IsHitTestVisible) 'Three choices missing or inaccessible'
$before=$script:orbySettings.ProviderEnabled
foreach($id in @('claude','chatgpt','gemini')){
 $script:orbyActiveTasks=@(
  [pscustomobject]@{Id=$id+'-one';Provider=$id;State='working';Title='Main task';Action='Working'},
  [pscustomobject]@{Id=$id+'-two';Provider=$id;State='attention';Title='Second task';Action='Needs your input'})
 $script:companionChoices[$id].RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent));Layout
 $card=$script:providerCards[$id]
 Assert ($script:companionSelection -eq $id -and $script:companionCardHost.Children[0] -eq $card.View) ('Selection failed: '+$id)
 Assert ($card.Controls.ActiveCount.Text -eq '2 active tasks') ('Task count incorrect: '+$id)
 Assert ($card.Buddies[0].Host.Parent -eq $card.Controls.AvatarStage) ('Red agent did not move behind main Orby: '+$id)
 Assert ($card.Buddies[0].Host.Width -eq 62 -and [Windows.Controls.Panel]::GetZIndex($card.Buddies[0].Host) -lt [Windows.Controls.Panel]::GetZIndex($card.Controls.MainHost)) 'Red agent covers the main Orby'
 Assert ($card.Controls.BuddyRow.Children.Count -eq 3) 'Active red agent duplicated in resting row'
 Assert ($script:orbySettings.ProviderEnabled -eq $before) 'View selection disconnected another provider'
 foreach($other in $script:providerCards.Values | Where-Object {$_.Id -ne $id}){Assert $other.Renderer.Suspended 'A hidden provider kept rendering'}
 Capture ('shared-'+$id+'-two-tasks')
 Set-OrbyAIChooser $false;Layout
 Assert ($script:compactMenus.Height -eq 310 -and $card.Controls.ActiveCount.Text -eq '2 active tasks') 'Closing chooser stopped tasks or left empty space'
 Capture ('shared-'+$id+'-collapsed')
 Set-OrbyAIChooser $true
}
$script:orbyActiveTasks=@();Update-OrbyMultiProvider;Layout
$card=$script:providerCards.gemini
Assert ($card.Controls.BuddyRow.Children.Count -eq 4 -and $card.Buddies[0].Slot -eq -1) 'Finished agent did not return to resting row'
# Do not mistake a single provider signal, duplicate task, or other AI task for extra work.
$status=Get-OrbyIndependentStatus 'gemini'
Assert (@(Get-OrbyProviderTasks 'gemini' $status).Count -eq 1) 'One actual Gemini signal became multiple invented tasks'
$task=[pscustomobject]@{Id='duplicate';Provider='chatgpt';State='working';Title='Task';Action='Working'}
$script:orbyActiveTasks=@($task,$task)
Assert (@(Get-OrbyProviderTasks 'chatgpt' (Get-OrbyIndependentStatus 'chatgpt')).Count -eq 1) 'Duplicate journal entries created extra agents'
Assert (@(Get-OrbyProviderTasks 'claude' (Get-OrbyIndependentStatus 'claude')).Count -eq 1) 'ChatGPT tasks leaked into Claude'
# The existing native Claude hook observer can now expose distinct active sessions.
Add-Type -Path (Join-Path $PSScriptRoot 'Claude-Code.cs') -ReferencedAssemblies System.Web.Extensions,System.Core
$owner=Get-Process -Id $PID;$start=$owner.StartTime.ToUniversalTime().Ticks;$now=[datetime]::UtcNow
$signals=[OrbyCodeSignal[]]@(
 [OrbyCodeSignal]@{Session='one';OwnerPid=$PID;OwnerStart=$start;State='working';AtTicks=$now.Ticks},
 [OrbyCodeSignal]@{Session='two';OwnerPid=$PID;OwnerStart=$start;State='attention';AtTicks=$now.Ticks},
 [OrbyCodeSignal]@{Session='idle';OwnerPid=$PID;OwnerStart=$start;State='idle';AtTicks=$now.Ticks})
$code=[OrbyClaudeCode]::Aggregate($signals,$now,{param($pidValue,$ticks) $true})
Assert ($code.Sessions -eq 3 -and $code.Tasks.Count -eq 2) 'Claude idle session counted as an active task'
$script:orbyShared.ClaudeCodeStatus=$code;$script:orbyShared.ClaudeCodeAt=$now
$script:orbyShared.ProviderSnapshots=@($script:orbyShared.ProviderSnapshots | Where-Object {$_.Provider -ne 'claude'})
Assert (@(Get-OrbyProviderTasks 'claude' (Get-OrbyIndependentStatus 'claude')).Count -eq 2) 'Claude independent sessions did not reach the shared panel'
Select-OrbyCompanion 'claude';Layout;Capture 'shared-claude-real-session-fixture'
for($i=0;$i -lt 20;$i++){Set-OrbyAIChooser ($i%2 -eq 0);Layout}
Assert ($script:multiHome.Children.Count -eq 1 -and $script:companionCardHost.Children.Count -eq 1) 'Rapid toggles duplicated shared cards'
Set-OrbyAIChooser $false
$script:expanded=$false;Update-OrbyMultiProvider
foreach($c in $script:providerCards.Values){Assert $c.Renderer.Suspended 'Closed menu kept rendering';foreach($b in $c.Buddies){Assert $b.Renderer.Suspended 'Closed mini-agent kept rendering'}}
$script:expanded=$true;$script:fullscreenHidden=$true;Update-OrbyMultiProvider
foreach($c in $script:providerCards.Values){Assert $c.Renderer.Suspended 'Fullscreen hidden menu kept rendering'}
$script:fullscreenHidden=$false;$script:orbySettings.ReducedMotion=$false
Set-OrbyAIChooser $true;Set-OrbyAIChooser $false;Set-OrbyAIChooser $true
$frame=[Windows.Threading.DispatcherFrame]::new();$timer=[Windows.Threading.DispatcherTimer]::new();$timer.Interval=[timespan]::FromMilliseconds(350)
$timer.Add_Tick({$this.Stop();$frame.Continue=$false});$timer.Start();[Windows.Threading.Dispatcher]::PushFrame($frame)
Assert ([math]::Abs($script:aiChooser.Height-44) -lt .1) 'Interrupted drawer animation did not settle'
Set-OrbyAIChooser $false;$script:orbySettings.ReducedMotion=$true;Set-OrbyAIChooser $false
foreach($id in @('chatgpt','claude','gemini')){Select-OrbyProviderPage $id;Layout;Assert ($script:compactMenuPage -eq 'agents') 'Existing account/status page lost'}
$window.Close();"PASS: $script:assertions shared companion checks, including real WPF input, three providers, independent tasks, slide transitions, hidden rendering and retained account pages"
