param([string]$PreviewDirectory='')
$ErrorActionPreference='Stop'
$inspectorPreview=$PreviewDirectory
. (Join-Path $PSScriptRoot 'Test-AllLargeMenus.ps1') -KeepWindow
$PreviewDirectory=$inspectorPreview
$script:taskChecks=0
function CheckTask($ok,$why){if(-not $ok){throw $why};$script:taskChecks++}
function ClickTask($button){$event=if($button -is [Windows.Controls.MenuItem]){[Windows.Controls.MenuItem]::ClickEvent}else{[Windows.Controls.Primitives.ButtonBase]::ClickEvent};$button.RaiseEvent([Windows.RoutedEventArgs]::new($event))}
function SaveTaskView($Visual,[string]$Name){
 if(-not $PreviewDirectory){return};[void][IO.Directory]::CreateDirectory($PreviewDirectory);Layout
 $width=if($Visual -eq $window.Content){668}else{[int][math]::Ceiling($Visual.ActualWidth)};$height=if($Visual -eq $window.Content){384}else{[int][math]::Ceiling($Visual.ActualHeight)}
 $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new($width,$height,96,96,[Windows.Media.PixelFormats]::Pbgra32);$bitmap.Render($Visual)
 $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap));$stream=[IO.File]::Create((Join-Path $PreviewDirectory ($Name+'.png')));try{$encoder.Save($stream)}finally{$stream.Dispose()}
}
$script:orbySettings.ProviderEnabled='chatgpt,claude,gemini';$script:orbySettings.ReducedMotion=$true;$script:expanded=$true;$script:fullscreenHidden=$false;$script:orbyEventMode=''
try{
 foreach($id in @('chatgpt','claude','gemini')){
  $script:orbyActiveTasks=@(1..6 | ForEach-Object {[pscustomobject]@{Id=$id+'-'+$_;Provider=$id;State='working';Title=('Task '+$_+' - '+$(if($_ -eq 2){'Investigate the file attachment handoff'}else{'Example active work'}));Action=('Activity '+$_+' - '+$(if($_ -eq 2){'Inspecting the second task, checking its current progress and preparing the next change.'}else{'Reviewing implementation details'}))}})
  Select-OrbyCompanion $id;Set-OrbyAIChooser $false;Layout
  $card=$script:providerCards[$id];$c=$card.Controls
  CheckTask ($card.Tasks.Count -eq 6 -and $c.ActiveCount.Text -eq '6 active tasks') 'Task list lost tasks beyond the four buddy slots'
  CheckTask ($c.Title.Text -eq $script:orbyActiveTasks[0].Title -and $c.Detail.Text -eq $script:orbyActiveTasks[0].Action) 'Primary title and activity refer to different tasks'
  $previousLaunch=$script:lastOpened;ClickTask $card.Buddies[0].Host
  CheckTask ($script:lastOpened -eq $previousLaunch) 'Inspecting a task unexpectedly launched an app'
  CheckTask ($card.SelectedTaskId -eq ($id+'-2') -and $c.Title.Text -eq $script:orbyActiveTasks[1].Title -and $c.Detail.Text -eq $script:orbyActiveTasks[1].Action) 'Clicking red Orby did not show its own task'
  CheckTask ($c.TaskPosition.Text -eq 'Task 2 of 6 · Working' -and $c.Detail.ToolTip -eq $c.Detail.Text) 'Selected task identity or full details missing'
  Select-OrbyCardPrimaryTask $id
  $peer=[Windows.Automation.Peers.UIElementAutomationPeer]::CreatePeerForElement($card.Buddies[0].Host)
  $invoke=$peer.GetPattern([Windows.Automation.Peers.PatternInterface]::Invoke)
  CheckTask ($null -ne $invoke) 'Active buddy has no accessible Invoke action'
  $invoke.Invoke()
  $frame=[Windows.Threading.DispatcherFrame]::new();$timer=[Windows.Threading.DispatcherTimer]::new();$timer.Interval=[timespan]::FromMilliseconds(25);$timer.Add_Tick({$timer.Stop();$frame.Continue=$false}.GetNewClosure());$timer.Start();[Windows.Threading.Dispatcher]::PushFrame($frame)
  CheckTask ($card.SelectedTaskId -eq ($id+'-2')) 'Accessible invocation did not select the buddy task'
  Update-OrbyMultiProvider
  CheckTask ($card.SelectedTaskId -eq ($id+'-2')) 'Regular polling reset the selected task'
  foreach($buddy in $card.Buddies){
   CheckTask ($buddy.Host.Width -eq 62 -and $buddy.Host.Height -eq 64 -and $buddy.Host.Parent -eq $c.AvatarStage) 'Active buddy not enlarged behind main Orby'
   CheckTask ($buddy.Renderer.ShowStatusDot -and $buddy.Renderer.StatusConnected -and $buddy.Host.IsHitTestVisible -and $buddy.Host.Focusable) 'Active buddy has no status dot or click/keyboard access'
   CheckTask ([Windows.Controls.Panel]::GetZIndex($buddy.Host) -lt [Windows.Controls.Panel]::GetZIndex($c.MainHost)) 'Buddy covers the main Orby'
   $buddy.Renderer.ReducedMotion=$false;$buddy.Renderer.Draw(1)
   $position=$buddy.Parts.OrbLed.RenderTransform.Value.OffsetX
   $buddy.Renderer.Draw(2)
   CheckTask ($buddy.Parts.OrbLed.Opacity -gt .9 -and [math]::Abs($buddy.Parts.OrbLed.RenderTransform.Value.OffsetX-$position) -gt .5) 'Working buddy indicator does not revolve'
   CheckTask ($buddy.Parts.OrbLed.Fill.Color.B -gt 200 -and $buddy.Parts.OrbLed.Fill.Color.R -lt 100) 'Working buddy indicator is not blue'
   $buddy.Renderer.ReducedMotion=$true
  }
  Layout
  CheckTask ($c.AvatarStage.TranslatePoint([Windows.Point]::new(0,$c.AvatarStage.ActualHeight),$card.View).Y -lt $c.InlineUsage.TranslatePoint([Windows.Point]::new(0,0),$card.View).Y) 'Larger avatars overlap usage bars'
  foreach($buddy in $card.Buddies){
   $corner=$buddy.Host.TranslatePoint([Windows.Point]::new($buddy.Host.ActualWidth-1,$buddy.Host.ActualHeight-1),$notch)
   CheckTask ($notch.Clip.FillContains($corner)) 'Expanded buddy click area is clipped by the notch'
  }
  ClickTask $c.TaskListButton
  $menu=$c.TaskListButton.ContextMenu
  CheckTask ($menu.IsOpen -and $menu.Items.Count -eq 6) 'Clicking task count did not reveal every task'
  CheckTask ($menu.Items[1].Header.Children[1].Text -eq $script:orbyActiveTasks[1].Title -and $menu.Items[1].Header.Children[2].Text -eq $script:orbyActiveTasks[1].Action) 'Task list details are incomplete'
  $menu.Items[5].BringIntoView();$menu.UpdateLayout()
  $last=$menu.Items[5].TranslatePoint([Windows.Point]::new(0,$menu.Items[5].ActualHeight),$menu)
  CheckTask ($last.Y -le $menu.ActualHeight+1) 'Task list cannot scroll to the sixth task'
  Set-OrbitExpanded $false
  CheckTask $script:expanded 'Moving into the task menu collapsed the notch'
  ClickTask $menu.Items[5]
  CheckTask ($card.SelectedTaskId -eq ($id+'-6') -and $c.TaskPosition.Text -like 'Task 6 of 6*') 'A task without a visible buddy cannot be inspected'
  $menu.IsOpen=$false
  Select-OrbyCardPrimaryTask $id
  CheckTask ($card.SelectedTaskId -eq ($id+'-1')) 'Main Orby does not restore primary task details'
  $previousLaunch=$script:lastOpened;ClickTask $card.Buddies[0].Host
  CheckTask ($script:lastOpened -eq $previousLaunch) 'Inspecting a task unexpectedly launched an app'
  if($PreviewDirectory -and $id -eq 'chatgpt'){
   $card.Renderer.Draw(1);foreach($buddy in $card.Buddies){$buddy.Renderer.Draw(1)}
   SaveTaskView $window.Content 'expanded-task-two'
   ClickTask $c.TaskListButton;SaveTaskView $menu 'all-active-tasks';$menu.IsOpen=$false
  }
  # Identity, rather than slot index, survives a feed reorder.
  $script:orbyActiveTasks=@($script:orbyActiveTasks[1],$script:orbyActiveTasks[0])+$script:orbyActiveTasks[2..5]
  Update-OrbyMultiProvider
  CheckTask ($card.SelectedTaskId -eq ($id+'-2') -and $c.TaskPosition.Text -like 'Task 1 of 6*') 'Task selection jumped to a different task after reordering'
  $script:orbyActiveTasks=@($script:orbyActiveTasks | Where-Object {$_.Id -ne ($id+'-2')})
  Update-OrbyMultiProvider
  CheckTask ($card.SelectedTaskId -eq ($id+'-1') -and $c.Title.Text -eq $script:orbyActiveTasks[0].Title) 'Completed selected task left stale details'
  Select-OrbyCardTask $id ($id+'-2')
  CheckTask ($card.SelectedTaskId -eq ($id+'-1')) 'A stale menu action selected a completed task'
  ClickTask $c.TaskListButton;Set-OrbyHomePage 'music'
  CheckTask (-not $menu.IsOpen -and $card.Renderer.Suspended) 'Hidden page retained an open task menu or renderer'
 }
 # No provider signal is an active task in this final resting fixture.
 $script:orbyActiveTasks=@();$script:orbyShared.ProviderSnapshots=@();$script:orbyShared.ClaudeCodeStatus=$null;$script:orbyShared.ProviderPresence=@{At=[datetime]::UtcNow;Names=@()};$script:chatConnectionPresent=$false;$script:petFeedAvailable=$false;$script:chatLogState='idle'
 Select-OrbyCompanion 'chatgpt';Update-OrbyMultiProvider
 $card=$script:providerCards.chatgpt
 CheckTask ($card.Tasks.Count -eq 0 -and -not $card.SelectedTaskId -and $card.Controls.TaskListButton.Visibility -eq 'Collapsed') 'No-task state retained task selection or button'
 foreach($buddy in $card.Buddies){CheckTask ($buddy.Host.Width -eq 24 -and -not $buddy.Renderer.ShowStatusDot -and -not $buddy.Host.IsHitTestVisible) 'Resting buddy kept active size, orbit or input'}
 $script:expanded=$false;Update-OrbyMultiProvider
 foreach($card in $script:providerCards.Values){foreach($buddy in $card.Buddies){CheckTask $buddy.Renderer.Suspended 'Closed menu kept a buddy rendering'}}
 "PASS: $script:taskChecks expanded-task inspection, independent identity, larger buddies, blue orbit, menu, stale-selection and cleanup checks. Fixture tasks only."
}finally{Close-OrbyTaskMenus;$window.Close()}
