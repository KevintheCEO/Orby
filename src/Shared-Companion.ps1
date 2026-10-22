# One shared Home card; choosing a view never disconnects another provider.
$script:sharedCompanion=$true
$script:aiChooserOpen=$false
$script:companionSelection=''
$script:companionChoices=@{}
. (Join-Path $PSScriptRoot 'Opening-Feedback.ps1')
function Invoke-OrbyAvatarClick {
 param([string]$Id,[int]$ClickCount)
 if($ClickCount -ne 2 -or $Id -notin @('chatgpt','claude','gemini')){return}
 if($script:lastProviderLaunch[$Id] -and ([datetime]::UtcNow-$script:lastProviderLaunch[$Id]).TotalMilliseconds -lt 700){return}
 $script:lastProviderLaunch[$Id]=[datetime]::UtcNow
 Start-OrbyOpeningFeedback $Id
 try{Open-OrbyProvider $Id}catch{Stop-OrbyOpeningFeedback $Id;throw}
}
function Invoke-OrbyInlineUsageAction {
 param([string]$Id)
 if($Id -eq 'chatgpt'){$script:usagePollAt=[datetime]::MinValue;Update-OrbyAccountUsage}
 else{Open-OrbyProviderUsage $Id}
 if($script:providerCards[$Id]){Update-OrbyInlineUsage $script:providerCards[$Id]}
}
function Update-OrbyInlineUsage {
 param($Card,[bool]$Visible=($script:expanded -and $script:companionSelection -eq $Card.Id -and $script:compactMenuPage -eq 'home' -and -not $script:fullscreenHidden -and -not $script:orbyEventMode))
 $c=$Card.Controls;$usage=Get-OrbyAccountUsage $Card.Id
 if(-not $Card.UsageTargets){$Card.UsageTargets=@{}}
 if(-not $Card.UsageKnown){$Card.UsageKnown=@{}}
 $enter=$Visible -and -not $Card.UsageVisible
 $reduced=[bool]$script:orbySettings.ReducedMotion -or -not [Windows.SystemParameters]::ClientAreaAnimation
 foreach($pair in @(@('Session','5-hour window'),@('Week','Weekly usage'))){
  $name=$pair[0];$window=$usage.$name
  $known=$null -ne $window -and $null -ne $window.Remaining -and [double]$window.Remaining -ge 0 -and [double]$window.Remaining -le 100
  $c['Inline'+$name+'Label'].Text=if($known -and $window.Label -notin @('5h window','Week')){$window.Label}else{$pair[1]}
  $c['Inline'+$name+'Value'].Text=if($known){[string][math]::Round([double]$window.Remaining)+'% remaining'}else{'Not available'}
  $bar=$c['Inline'+$name+'Bar'];$value=if($known){[double]$window.Remaining}else{0}
  $property=[Windows.Controls.Primitives.RangeBase]::ValueProperty
  if(-not $Visible -or -not $known){Invoke-OrbyMotion $bar $property 0 0}
  elseif($reduced){Invoke-OrbyMotion $bar $property $value 0}
  elseif($enter -or -not $Card.UsageKnown[$name]){
   # Reset only on entry/newly available data, never on the regular status poll.
   Invoke-OrbyMotion $bar $property 0 0
   [OrbyMotion.Transitions]::MoveAfterReveal($bar,$property,$value,.55,$script:displayHz,$false,$notch,[OrbyLiquidSurface]::MorphProperty,.95)
  }elseif($Card.UsageTargets[$name] -ne $value){Invoke-OrbyMotion $bar $property $value .28}
  $Card.UsageTargets[$name]=$value;$Card.UsageKnown[$name]=$known
  $c['Inline'+$name+'Bar'].Opacity=if($known){1}else{.35}
  $c['Inline'+$name+'Bar'].ToolTip=if($known){'Remaining quota. '+$window.Reset}else{'No readable usage data; this is not 0% remaining.'}
  $c['Inline'+$name+'Value'].ToolTip=if($known){$window.Reset}else{'No readable usage data'}
 }
 $Card.UsageVisible=$Visible
 $c.InlineUsageNote.Text=$usage.Note;$c.InlineUsageNote.ToolTip=$usage.Note
 $c.InlineUsageAction.Content=if($Card.Id -eq 'chatgpt'){'Refresh usage'}else{'Open usage'}
 if($script:referenceControls.RefAgentsPage){
  foreach($key in @('InlineSessionBar','InlineWeekBar')){$c[$key].Style=$script:referenceControls.RefAgentsPage.Resources[[type][Windows.Controls.ProgressBar]]}
 }
}

function Get-OrbyProviderTasks {
 param([string]$Id,$Status)
 $result=@();$seen=@{}
 # Existing task journals belong to ChatGPT unless explicitly tagged otherwise.
 foreach($task in @($script:orbyActiveTasks)){
  if(-not $task -or $task.State -notin @('working','attention')){continue}
  $owner=if($task.Provider){[string]$task.Provider}else{'chatgpt'}
  if($owner -ne $Id -or -not $task.Id -or $seen.ContainsKey([string]$task.Id)){continue}
  $seen[[string]$task.Id]=$true;$result+=$task
 }
 # A detailed task list is authoritative; its aggregate window status is the same work.
 if($result.Count){return $result}
 if($Id -eq 'claude' -and $script:orbyShared.ClaudeCodeAt -and ([datetime]::UtcNow-$script:orbyShared.ClaudeCodeAt).TotalSeconds -lt 8){
  foreach($task in @($script:orbyShared.ClaudeCodeStatus.Tasks)){
   if($task -and $task.Id -and $task.State -in @('working','attention') -and -not $seen.ContainsKey([string]$task.Id)){$seen[[string]$task.Id]=$true;$result+=$task}
  }
 }
 if($Id -ne 'chatgpt'){
  foreach($snap in @($script:orbyShared.ProviderSnapshots | Where-Object {$_.Provider -eq $Id -and $_.Source -ne 'code' -and $_.StatusReadable -and $_.AppOpen -and $_.State -in @('working','attention') -and ([datetime]::UtcNow-$_.At).TotalSeconds -lt 8})){
   $key=$Id+'-window-'+[string]$snap.Hwnd
   if(-not $seen.ContainsKey($key)){$seen[$key]=$true;$result+=[pscustomobject]@{Id=$key;State=$snap.State;Title=$Status.Name+' task';Action=$snap.Detail}}
  }
 }
 if($result.Count){return $result}
 # Desktop/provider snapshots can prove a primary activity, not an invented extra task.
 if($Status.State -in @('working','attention')){
  $result+=[pscustomobject]@{Id=$Id+'-primary';State=$Status.State;Title=$Status.Title;Action=$Status.Detail}
 }
 return $result
}
function Select-OrbyCompanion {
 param([string]$Id)
 if($Id -notin @('claude','chatgpt','gemini')){return}
 if($Id -notin @(Get-OrbyPairedProviders)){Show-OrbyConnections;return}
 if($script:providerCards[$Id]){$script:providerCards[$Id].UsageVisible=$false}
 Close-OrbyTaskMenus
 $script:companionSelection=$Id
 Set-OrbyHomePage 'home'
 Update-OrbyMultiProvider
}
function Set-OrbyAIChooser {
 param([bool]$Open)
 if(-not $script:aiChooser){return}
 if($script:compactMenuPage -ne 'home'){Set-OrbyHomePage 'home'}
 $script:aiChooserOpen=$Open
 $script:aiCompanionButton.Tag=if($Open){'Selected'}else{$null}
 $script:aiCompanionButton.ToolTip=if($Open){'Hide AI choices'}else{'Choose an AI companion'}
 $script:aiChevron.Text=if($Open){[string][char]0x2303}else{[string][char]0x2304}
 $height=if($Open){44.0}else{0.0}
 $script:aiChooser.IsHitTestVisible=$Open
 if($script:expanded -and -not $script:orbySettings.ReducedMotion -and [Windows.SystemParameters]::ClientAreaAnimation){
  Invoke-OrbyMotion $script:aiChooser ([Windows.FrameworkElement]::HeightProperty) $height .20
 }else{$script:aiChooser.BeginAnimation([Windows.FrameworkElement]::HeightProperty,$null);$script:aiChooser.Height=$height}
 Update-OrbyCompactMenus
}
function Initialize-OrbySharedCompanion {
 $u=$script:compactMenuControls
 foreach($button in $script:providerNav.Values){$button.Visibility='Collapsed'}
 $button=[Windows.Controls.Button]::new();$button.Style=$script:referenceHome.Resources.NavButton
 $button.Width=58;$button.ToolTip='Choose an AI companion';$button.SetValue([Windows.Automation.AutomationProperties]::NameProperty,'AI companions')
 $label=[Windows.Controls.StackPanel]::new();$label.Orientation='Horizontal'
 $text=[Windows.Controls.TextBlock]::new();$text.Text='AI';$text.FontSize=12;$text.FontWeight='SemiBold'
 $script:aiChevron=[Windows.Controls.TextBlock]::new();$script:aiChevron.Text=[string][char]0x2304;$script:aiChevron.Margin='6,0,0,0'
 [void]$label.Children.Add($text);[void]$label.Children.Add($script:aiChevron);$button.Content=$label
 $button.Add_Click({Invoke-OrbySafeAction {Set-OrbyAIChooser (-not $script:aiChooserOpen)} 'Toggle AI choices'})
 $button.Add_PreviewKeyDown({param($sender,$e)if($e.Key -eq 'Escape'){Set-OrbyAIChooser $false;$e.Handled=$true}})
 $script:aiCompanionButton=$button;$u.MenuNav.Children.Insert(1,$button)
 $script:multiHome.Children.Clear();$script:multiHome.RowDefinitions.Clear();$script:multiHome.ColumnDefinitions.Clear()
 [xml]$x=@'
<Grid xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
 <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
 <Border x:Name="Chooser" Height="0" ClipToBounds="True" IsHitTestVisible="False"><UniformGrid x:Name="Choices" Columns="3" Margin="0,2,0,5"/></Border>
 <Grid x:Name="CardHost" Grid.Row="1" Margin="0,5,0,0"/>
</Grid>
'@
 $script:sharedCompanionView=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($x))
 $script:aiChooser=$script:sharedCompanionView.FindName('Chooser');$script:companionCardHost=$script:sharedCompanionView.FindName('CardHost')
 $choices=$script:sharedCompanionView.FindName('Choices')
 foreach($id in @('claude','chatgpt','gemini')){
  $choice=[Windows.Controls.Button]::new();$choice.CommandParameter=$id;$choice.Margin='0,0,6,0';$choice.Padding='9,4'
  $row=[Windows.Controls.StackPanel]::new();$row.Orientation='Horizontal';$row.VerticalAlignment='Center'
  $logo=New-OrbyProviderLogo $id 16;$logo.Margin='0,0,7,0';[void]$row.Children.Add($logo)
  $name=[Windows.Controls.TextBlock]::new();$name.Text=$script:providerCatalog[$id].Name;$name.FontSize=12;$name.FontWeight='SemiBold';[void]$row.Children.Add($name)
  $choice.Content=$row;$choice.ToolTip='Show '+$name.Text+' companion and usage'
  $choice.Add_Click({param($sender,$e)Invoke-OrbySafeAction {Select-OrbyCompanion ([string]$sender.CommandParameter)} 'Select AI companion'})
  [void]$choices.Children.Add($choice);$script:companionChoices[$id]=$choice
 }
 [void]$script:multiHome.Children.Add($script:sharedCompanionView)
 $script:compactMenus.Add_PreviewKeyDown({param($sender,$e)if($e.Key -eq 'Escape' -and $script:aiChooserOpen){Set-OrbyAIChooser $false;$script:aiCompanionButton.Focus()|Out-Null;$e.Handled=$true}})
 $window.Add_Closed({Stop-OrbyAllOpeningFeedback})
 Update-OrbyMultiProvider;Update-OrbyCompactMenus
}
function Update-OrbyCardTasks {
 param($Card,$Status,[object[]]$Tasks,[bool]$Visible)
 $c=$Card.Controls;$reduced=[bool]$script:orbySettings.ReducedMotion -or -not [Windows.SystemParameters]::ClientAreaAnimation
 Update-OrbyInlineUsage $Card $Visible
 $opening=Test-OrbyOpeningFeedback $Card.Id $Status
 $Card.Tasks=@($Tasks)
 $c.TaskListButton.Visibility=if($Tasks.Count){'Visible'}else{'Collapsed'}
 $c.ActiveCount.Text=if($Tasks.Count){[string]$Tasks.Count+' active task'+$(if($Tasks.Count -ne 1){'s'}else{''})}else{''}
 $c.Title.Text=if($Tasks.Count){$Tasks[0].Title}elseif($Status.Sleeping){if($Status.Open){'Sleeping · resting'}else{'Sleeping · app closed'}}elseif($Status.State -eq 'error'){'Task error'}else{'Ready'}
 $c.Detail.Text=if($Tasks.Count){$Tasks[0].Action}elseif($Status.Sleeping){'Wakes when activity returns'}elseif($Status.State -eq 'error'){$Status.Detail}else{'Ready for your next chat'}
 if($opening -and -not $Status.Open){$c.Title.Text='Opening '+$Status.Name+'…';$c.Detail.Text='Waiting for the app to respond'}
 Update-OrbySelectedTaskText $Card
 Update-OrbyTaskMenu $Card
 $c.Title.ToolTip=$c.Title.Text;$c.Detail.ToolTip=$c.Detail.Text
 $c.SleepLabel.Visibility=if($Status.Sleeping -and -not $opening){'Visible'}else{'Collapsed'}
 $Card.Renderer.Suspended=-not $Visible;$Card.Renderer.ReducedMotion=$reduced;$Card.Renderer.EyeEffects=[bool]$script:orbySettings.EyeEffects
 $primaryAction=if($Tasks.Count){[string]$Tasks[0].Action}else{$Status.Detail}
 $Card.Renderer.SetState($(if($opening){'idle'}elseif($Tasks.Count){$Tasks[0].State}elseif($Status.Sleeping){'sleep'}else{'idle'}),$primaryAction)
 $Card.Renderer.StatusConnected=$Status.Open -and $Status.Readable
 Set-OrbyProviderAccent $Card.Parts $Status.Id ($Status.Sleeping -and -not $opening) ($Visible -and -not $reduced)
 for($i=0;$i -lt $Card.Buddies.Count;$i++){
  $b=$Card.Buddies[$i];$task=if($Tasks.Count -gt ($i+1)){$Tasks[$i+1]}else{$null};$slot=if($task){$i}else{-1}
  if($b.Slot -ne $slot){
   if($b.Host.Parent -is [Windows.Controls.Panel]){$b.Host.Parent.Children.Remove($b.Host)}
   if($task){
    $b.Host.Width=62;$b.Host.Height=64;$b.Host.Margin='0'
    [Windows.Controls.Canvas]::SetLeft($b.Host,@(64,0,64,0)[$i]);[Windows.Controls.Canvas]::SetTop($b.Host,@(0,0,72,72)[$i]);[Windows.Controls.Panel]::SetZIndex($b.Host,10-$i)
    [void]$c.AvatarStage.Children.Add($b.Host)
   }else{$b.Host.Width=24;$b.Host.Height=29;$b.Host.Margin='0,0,7,0';[void]$c.BuddyRow.Children.Add($b.Host)}
   $b.Slot=$slot
   if($task -and $Visible -and -not $reduced){$fade=[Windows.Media.Animation.DoubleAnimation]::new(0,1,[timespan]::FromSeconds(.22));$b.Host.BeginAnimation([Windows.UIElement]::OpacityProperty,$fade)}
  }
  $b.TaskId=if($task){[string]$task.Id}else{''}
  $b.Host.Tag=if($task){@{Provider=$Card.Id;TaskId=[string]$task.Id}}else{$null}
  $b.Host.IsEnabled=[bool]$task;$b.Host.Focusable=[bool]$task;$b.Host.IsHitTestVisible=[bool]$task
  $b.Host.Cursor=if($task){[Windows.Input.Cursors]::Hand}else{[Windows.Input.Cursors]::Arrow}
  $b.Renderer.ShowStatusDot=[bool]$task;$b.Renderer.StatusConnected=[bool]$task
  $b.Renderer.Suspended=-not $Visible;$b.Renderer.ReducedMotion=$reduced;$b.Renderer.EyeEffects=$false
  $b.Renderer.SetState($(if($task){$task.State}else{'sleep'}),$(if($task){$task.Action}else{''}))
  $b.Host.ToolTip=if($task){'Task '+($i+2)+': '+$task.Title+' · '+$task.Action+' · Click for details'}else{'Resting · no additional task'}
  $b.Host.SetValue([Windows.Automation.AutomationProperties]::NameProperty,([string]$b.Host.ToolTip))
 }
}
function Update-OrbyMultiProvider {
 if(-not $script:sharedCompanionView){return}
 $ids=@(Get-OrbyPairedProviders);if(-not $ids.Count){$ids=@('chatgpt')}
 $statuses=@();foreach($id in $ids){$statuses+=Get-OrbyIndependentStatus $id;if(-not $script:providerCards[$id]){$script:providerCards[$id]=New-OrbyProviderCard $id}}
 if($script:companionSelection -notin $ids){
  $active=$statuses | Where-Object {$_.State -in @('working','attention','error')} | Select-Object -First 1
  $script:companionSelection=if($active){$active.Id}elseif($script:orbySettings.PrimaryProvider -in $ids){$script:orbySettings.PrimaryProvider}else{$ids[0]}
 }
 $selected=$script:companionSelection;$card=$script:providerCards[$selected]
 if($card.View.Parent -ne $script:companionCardHost){
  $script:companionCardHost.Children.Clear()
  if($card.View.Parent -is [Windows.Controls.Panel]){$card.View.Parent.Children.Remove($card.View)}
  $card.View.Margin='0';[void]$script:companionCardHost.Children.Add($card.View)
 }
 $visible=$script:expanded -and -not $script:fullscreenHidden -and $script:compactMenuPage -eq 'home' -and $script:dashboardRoute -ne 'home' -and -not $script:orbyEventMode -and -not ($script:dropPanel -and $script:dropPanel.Visibility -eq 'Visible')
 # Update each renderer to its final visibility once; a suspend/resume pair
 # every poll restarts live rendering even when the selected card has not changed.
 foreach($entry in $script:providerCards.GetEnumerator()){if($entry.Key -notin $ids){$entry.Value.Controls.TaskListButton.ContextMenu.IsOpen=$false;$entry.Value.Renderer.Suspended=$true;foreach($b in $entry.Value.Buddies){$b.Renderer.Suspended=$true}}}
 foreach($status in $statuses){
  if($status.Id -ne $selected -or -not $visible){$script:providerCards[$status.Id].Controls.TaskListButton.ContextMenu.IsOpen=$false}
  $tasks=@(Get-OrbyProviderTasks $status.Id $status)
  Update-OrbyCardTasks $script:providerCards[$status.Id] $status $tasks ($visible -and $status.Id -eq $selected)
 }
 foreach($id in $script:companionChoices.Keys){
  $choice=$script:companionChoices[$id];$choice.Tag=if($id -eq $selected){'Selected'}else{$null}
  $choice.Foreground=[Windows.Media.BrushConverter]::new().ConvertFromString($(if($id -eq $selected){switch($id){claude{'#E5A28C'}chatgpt{'#91C5FF'}default{'#D5C3EE'}}}else{'#C6C8D0'}))
  $choice.Background=[Windows.Media.BrushConverter]::new().ConvertFromString($(if($id -eq $selected){'#262B37'}else{'#18191F'}))
  $choice.Opacity=if($id -in $ids){1}else{.5}
 }
 foreach($button in $script:providerNav.Values){$button.Visibility='Collapsed'}
 $script:multiProviderStatuses=$statuses
 $script:referenceControls.RefConnection.Text=($statuses | ForEach-Object {$_.Name+' · '+$(if($_.Sleeping){'Sleeping'}elseif($_.State -in @('unknown','idle')){'Ready'}else{$_.State})}) -join ' | '
 $active=$statuses | Where-Object {$_.State -in @('attention','working','error')} | Select-Object -First 1
 if($script:avatarRenderer -and -not $script:waterPriority){$script:avatarRenderer.SetState($(if($active){$active.State}elseif(@($statuses | Where-Object {-not $_.Sleeping}).Count){'idle'}else{'sleep'}),$(if($active){$active.Detail}else{''}))}
}
. (Join-Path $PSScriptRoot 'Task-Inspector.ps1')
Initialize-OrbySharedCompanion
