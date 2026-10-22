# V1: independent paired providers. Selecting a quota page does not disconnect a provider.
. (Join-Path $PSScriptRoot 'Provider-Accents.ps1')
Add-Type -Path (Join-Path $PSScriptRoot 'Provider-Lifecycle.cs')
$script:providerLife=[OrbyProviderLifecycle]::new()
$script:providerCards=@{}
$script:providerNav=@{}
$script:singleProviderView=${function:Update-OrbyProviderView}

function Get-OrbyPairedProviders {
 @('chatgpt','claude','gemini') | Where-Object {$_ -in ([string]$script:orbySettings.ProviderEnabled -split ',')}
}
function Get-OrbyIndependentStatus {
 param([string]$Id,[datetime]$Now=[datetime]::UtcNow)
 $snap=Get-OrbyProviderSnapshot $Id
 $presence=$script:orbyShared.ProviderPresence
 $fresh=$presence -and ($Now-$presence.At).TotalSeconds -lt 8
 $open=[bool]($snap -and $snap.AppOpen)
 if($fresh -and $Id -eq 'chatgpt'){$open=$open -or 'ChatGPT' -in $presence.Names}
 if($fresh -and $Id -eq 'claude'){$open=$open -or @($presence.Names | Where-Object {$_ -eq 'Claude' -or $_ -like 'claude-*'}).Count -gt 0}
 if($fresh -and $Id -eq 'gemini'){$open=$open -or 'Gemini' -in $presence.Names -or 'GoogleGemini' -in $presence.Names}
 $readable=[bool]($snap -and $snap.StatusReadable);$state=if($readable){$snap.State}else{'unknown'}
 # Retain ChatGPT/Codex's existing independent feed; account sign-in alone is not activity.
 if($Id -eq 'chatgpt' -and ($script:chatConnectionPresent -or $script:petFeedAvailable)){
  $open=$true;$readable=$true;$fresh=$true;$state=if($script:chatLogState){$script:chatLogState}else{'idle'}
 }
 if($snap){$fresh=$true}
 $life=$script:providerLife.Evaluate($Id,[bool]$fresh,[bool]$open,$readable,[string]$state,$Now)
 $title=$script:providerCatalog[$Id].Name
 $action=$life.Detail
 if($Id -eq 'chatgpt' -and $life.State -in @('working','attention','error')){
  $title=Get-NotchTaskTitle 'ChatGPT task';if($script:chatLogMessage){$action=$script:chatLogMessage}
 }elseif($snap -and $snap.StatusReadable -and $snap.State -eq $life.State -and -not $life.Sleeping){$action=$snap.Detail}
 [pscustomobject]@{Id=$Id;Name=$script:providerCatalog[$Id].Name;State=$life.State;Sleeping=$life.Sleeping;Title=$title;Detail=$action;Open=$open;Readable=$readable;Snapshot=$snap}
}
function New-OrbyProviderLogo {
 param([string]$Id,[double]$Size=17)
 $path=[Windows.Shapes.Path]::new();$path.Width=$Size;$path.Height=$Size;$path.Stretch='Uniform'
 switch($Id){
  claude {$path.Data=$script:providerIconResources.ClaudeLogo;$path.Fill=$script:providerIconResources.ClaudeBrush}
  gemini {$path.Data=$script:providerIconResources.GeminiLogo;$path.Fill=$script:providerIconResources.GeminiBrush}
  default {$path.Data=$script:openAiLogo;$path.Fill=[Windows.Media.Brushes]::White}
 }
 return $path
}
function Select-OrbyProviderPage {
 param([string]$Id)
 $script:orbySettings.PrimaryProvider=$Id;Save-OrbySettings
 Set-OrbyHomePage 'agents'
 foreach($key in $script:providerNav.Keys){$script:providerNav[$key].Tag=if($key -eq $Id){'Selected'}else{$null}}
 # Always keep OpenAI's logo on its own button.
 Set-OrbyProviderIcon 'chatgpt'
}
function Disconnect-OrbyProvider {
 param([string]$Id)
 $script:orbySettings.ProviderEnabled=(@(Get-OrbyPairedProviders | Where-Object {$_ -ne $Id})) -join ','
 if($script:orbySettings.PrimaryProvider -eq $Id){$script:orbySettings.PrimaryProvider='chatgpt'}
 Save-OrbySettings;Update-OrbyMultiProvider
}
function New-OrbyProviderCard {
 param([string]$Id)
 [xml]$x=@'
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Background="#111116" BorderBrush="#292932" BorderThickness="1" CornerRadius="18" Padding="14,10" UseLayoutRounding="True" SnapsToDevicePixels="True" TextElement.FontFamily="Segoe UI" TextElement.FontWeight="Normal" TextOptions.TextFormattingMode="Display" TextOptions.TextRenderingMode="Grayscale">
 <Grid><Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="82"/></Grid.RowDefinitions><Grid.ColumnDefinitions><ColumnDefinition Width="148"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
 <Canvas x:Name="AvatarStage" Width="148" Height="140" VerticalAlignment="Center">
  <Ellipse Width="84" Height="96" Canvas.Left="20" Canvas.Top="18" IsHitTestVisible="False"><Ellipse.Fill><RadialGradientBrush x:Name="GlowBrush"><GradientStop x:Name="Glow" Color="#00FFFFFF"/><GradientStop Color="#00FFFFFF" Offset="1"/></RadialGradientBrush></Ellipse.Fill></Ellipse>
  <Viewbox x:Name="MainHost" Width="108" Height="112" Canvas.Left="6" Canvas.Top="14" Panel.ZIndex="20"/>
  <TextBlock x:Name="SleepLabel" Text="z z" Foreground="#8D94A0" FontSize="10" Canvas.Left="92" Canvas.Top="10" Visibility="Collapsed"/>
 </Canvas>
 <Grid Grid.Column="1" Margin="12,4,0,0"><Grid.RowDefinitions><RowDefinition Height="27"/><RowDefinition Height="32"/><RowDefinition Height="32"/><RowDefinition Height="30"/></Grid.RowDefinitions>
  <DockPanel><Button x:Name="Menu" Content="···" DockPanel.Dock="Right" Width="26" Height="24" Padding="0" ToolTip="Provider options"/><Button x:Name="TaskListButton" DockPanel.Dock="Right" Padding="7,2" Margin="6,0,8,0" ToolTip="View all active tasks"><TextBlock x:Name="ActiveCount" Foreground="#AAB2C0" FontSize="11" VerticalAlignment="Center"/></Button><StackPanel Orientation="Horizontal"><ContentControl x:Name="Logo" Width="18" Height="18" Margin="0,0,7,0"/><TextBlock x:Name="Name" FontSize="16" FontWeight="SemiBold" Foreground="#F4F4F6"/></StackPanel></DockPanel>
  <TextBlock Grid.Row="1" x:Name="Title" FontSize="13" Foreground="#E8E8EB" TextTrimming="CharacterEllipsis" TextWrapping="Wrap" MaxHeight="32" VerticalAlignment="Center"/>
  <TextBlock Grid.Row="2" x:Name="Detail" FontSize="12" Foreground="#ACB1BC" TextTrimming="CharacterEllipsis" TextWrapping="Wrap" MaxHeight="32" VerticalAlignment="Center"/>
  <StackPanel Grid.Row="3" Orientation="Horizontal" VerticalAlignment="Center"><TextBlock x:Name="TaskPosition" Foreground="#91C5FF" FontSize="11" VerticalAlignment="Center" MaxWidth="200" TextTrimming="CharacterEllipsis" Margin="0,0,9,0"/><StackPanel x:Name="BuddyRow" Orientation="Horizontal" VerticalAlignment="Center"/></StackPanel>
 </Grid>
 <Grid x:Name="InlineUsage" Grid.Row="1" Grid.ColumnSpan="2" Margin="0,8,0,0" Background="Transparent">
  <Grid.RowDefinitions><RowDefinition Height="26"/><RowDefinition Height="26"/><RowDefinition Height="22"/></Grid.RowDefinitions>
  <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="112"/><ColumnDefinition Width="*"/><ColumnDefinition Width="112"/></Grid.ColumnDefinitions>
   <TextBlock x:Name="InlineSessionLabel" Text="5-hour window" FontSize="12" VerticalAlignment="Center"/>
   <ProgressBar x:Name="InlineSessionBar" Grid.Column="1" Minimum="0" Maximum="100" Height="6" Background="#343943" Foreground="#48D68D" VerticalAlignment="Center"/>
   <TextBlock x:Name="InlineSessionValue" Grid.Column="2" Text="Not available" FontSize="12" HorizontalAlignment="Right" VerticalAlignment="Center"/>
  </Grid>
  <Grid Grid.Row="1"><Grid.ColumnDefinitions><ColumnDefinition Width="112"/><ColumnDefinition Width="*"/><ColumnDefinition Width="112"/></Grid.ColumnDefinitions>
   <TextBlock x:Name="InlineWeekLabel" Text="Weekly usage" FontSize="12" VerticalAlignment="Center"/>
   <ProgressBar x:Name="InlineWeekBar" Grid.Column="1" Minimum="0" Maximum="100" Height="6" Background="#343943" Foreground="#48D68D" VerticalAlignment="Center"/>
   <TextBlock x:Name="InlineWeekValue" Grid.Column="2" Text="Not available" FontSize="12" HorizontalAlignment="Right" VerticalAlignment="Center"/>
  </Grid>
  <DockPanel Grid.Row="2"><Button x:Name="InlineUsageAction" Content="Refresh usage" DockPanel.Dock="Right" Padding="8,1" FontSize="11" Height="22" Margin="10,0,0,0"/><TextBlock x:Name="InlineUsageNote" Foreground="#A9B2BC" FontSize="11" TextTrimming="CharacterEllipsis" VerticalAlignment="Center"/></DockPanel>
 </Grid></Grid>
</Border>
'@
 $view=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($x));$c=@{}
 foreach($name in @('MainHost','SleepLabel','BuddyRow','Logo','Name','Menu','Title','Detail','Glow','GlowBrush','AvatarStage','ActiveCount','TaskListButton','TaskPosition','InlineUsage','InlineSessionLabel','InlineSessionBar','InlineSessionValue','InlineWeekLabel','InlineWeekBar','InlineWeekValue','InlineUsageAction','InlineUsageNote')){$c[$name]=$view.FindName($name)}
 $c.Name.Text=$script:providerCatalog[$Id].Name;$c.Logo.Content=New-OrbyProviderLogo $Id 14
 $parts=New-OrbitAvatar;$renderer=[OrbyAvatarRenderer]::new($parts);$renderer.StatusConnected=$false
 $c.MainHost.Child=$parts.Root
 $buddies=@();foreach($color in @('#E74766','#A765ED','#45BCB8','#EDAE46')){
  $p=New-OrbitAvatar;$p.OrbBody.Background=[Windows.Media.BrushConverter]::new().ConvertFromString($color)
  $r=[OrbyAvatarRenderer]::new($p);$r.ShowStatusDot=$false;$r.EyeEffects=$false
  $avatarView=[Windows.Controls.Viewbox]::new();$avatarView.Child=$p.Root
  $hostView=[Windows.Controls.Button]::new();$hostView.Width=24;$hostView.Height=29;$hostView.Margin='0';$hostView.Padding='0';$hostView.Background=[Windows.Media.Brushes]::Transparent;$hostView.BorderThickness='0';$hostView.Content=$avatarView
  [xml]$buttonTemplate='<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="Button"><Border Background="Transparent"><ContentPresenter/></Border></ControlTemplate>'
  $hostView.Template=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($buttonTemplate))
  $hostView.Add_Click({param($sender,$eventArgs)if($sender.Tag -and $sender.Tag.TaskId){Select-OrbyCardTask $sender.Tag.Provider $sender.Tag.TaskId};$eventArgs.Handled=$true})
  [void]$c.BuddyRow.Children.Add($hostView);$buddies+=@{Renderer=$r;Parts=$p;Host=$hostView;Slot=-1;TaskId=''}
 }
 $menu=[Windows.Controls.ContextMenu]::new()
 foreach($action in @('Open app','Connections','Disconnect from Orby')){
  $item=[Windows.Controls.MenuItem]::new();$item.Header=$action;$item.CommandParameter=$Id
  switch($action){
   'Open app' {$item.Add_Click({param($sender,$eventArgs) Invoke-OrbySafeAction { Open-OrbyProvider ([string]$sender.CommandParameter) } 'Open-OrbyProvider'})}
   'Connections' {$item.Add_Click({Invoke-OrbySafeAction {Show-OrbyConnections} 'AI connections'})}
   default {$item.Add_Click({param($sender,$eventArgs) Invoke-OrbySafeAction { Disconnect-OrbyProvider ([string]$sender.CommandParameter) } 'Disconnect-OrbyProvider'})}
  }
  [void]$menu.Items.Add($item)
 }
 $c.Menu.ContextMenu=$menu
 $c.Menu.Add_Click({$this.ContextMenu.PlacementTarget=$this;$this.ContextMenu.IsOpen=$true;$_.Handled=$true})
 $view.Tag=$Id
 $c.InlineUsageAction.CommandParameter=$Id
 $c.InlineUsageAction.Add_Click({param($sender,$eventArgs) Invoke-OrbySafeAction {Invoke-OrbyInlineUsageAction ([string]$sender.CommandParameter)} 'Update account usage';$eventArgs.Handled=$true})
 $c.InlineUsage.Add_MouseLeftButtonUp({param($sender,$eventArgs)$eventArgs.Handled=$true})
 $c.MainHost.Tag=$Id;$c.MainHost.ToolTip='Click for the main task. Double-click to open '+$script:providerCatalog[$Id].Name
 $c.MainHost.Add_MouseLeftButtonDown({param($sender,$eventArgs)if($eventArgs.ClickCount -eq 2){Invoke-OrbySafeAction {Invoke-OrbyAvatarClick ([string]$sender.Tag) 2} 'Open AI app';$eventArgs.Handled=$true}else{Select-OrbyCardPrimaryTask ([string]$sender.Tag);$eventArgs.Handled=$true}})
 $taskMenu=[Windows.Controls.ContextMenu]::new();$taskMenu.Background=[Windows.Media.BrushConverter]::new().ConvertFromString('#151821');$taskMenu.Foreground=[Windows.Media.Brushes]::White;$taskMenu.BorderBrush=[Windows.Media.BrushConverter]::new().ConvertFromString('#394251');$taskMenu.MaxHeight=330;$taskMenu.MaxWidth=380;$taskMenu.Placement='Bottom';$taskMenu.Tag=$Id
 [xml]$taskMenuTemplate='<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="ContextMenu"><Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="12" Padding="4"><ScrollViewer MaxHeight="310" CanContentScroll="True" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled"><ItemsPresenter KeyboardNavigation.DirectionalNavigation="Cycle"/></ScrollViewer></Border></ControlTemplate>'
 $taskMenu.Template=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($taskMenuTemplate))
 [xml]$taskItemTemplate='<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" TargetType="MenuItem"><Border x:Name="Surface" Background="Transparent" CornerRadius="8" Padding="6,2"><Grid><Grid.ColumnDefinitions><ColumnDefinition Width="20"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions><TextBlock x:Name="Selected" Text="&#x2713;" Foreground="#91C5FF" VerticalAlignment="Top" Margin="0,7,0,0" Visibility="Hidden"/><ContentPresenter Grid.Column="1" ContentSource="Header"/></Grid></Border><ControlTemplate.Triggers><Trigger Property="IsHighlighted" Value="True"><Setter TargetName="Surface" Property="Background" Value="#283345"/></Trigger><Trigger Property="IsChecked" Value="True"><Setter TargetName="Selected" Property="Visibility" Value="Visible"/></Trigger></ControlTemplate.Triggers></ControlTemplate>'
 $taskMenu.Resources['TaskItemTemplate']=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($taskItemTemplate))
 $taskMenu.Add_Opened({param($sender,$e)$card=$script:providerCards[[string]$sender.Tag];if($card){Update-OrbyTaskMenu $card -Force}})
 $taskMenu.Add_Closed({if(-not $script:orbyClosing -and $script:hoverExitTimer){$script:hoverExitTimer.Start()}})
 $c.TaskListButton.ContextMenu=$taskMenu
 $c.TaskListButton.Add_Click({param($sender,$e)$sender.ContextMenu.PlacementTarget=$sender;$sender.ContextMenu.IsOpen=-not $sender.ContextMenu.IsOpen;$e.Handled=$true})
 $c.TaskListButton.SetValue([Windows.Automation.AutomationProperties]::NameProperty,'View active tasks')
 $card=@{Id=$Id;View=$view;Controls=$c;Parts=$parts;Renderer=$renderer;Buddies=$buddies;Tasks=@();SelectedTaskId='';TaskMenuSignature=''}
 return $card
}
function Initialize-OrbyMultiProvider {
 $script:multiHome=[Windows.Controls.Grid]::new();[Windows.Controls.Grid]::SetColumnSpan($script:multiHome,3)
 $homePanel=$script:referenceControls.RefHomePage
 # Keep the old elements in their namescope for existing permission/music code.
 foreach($child in $homePanel.Children){$child.Visibility='Collapsed'}
 [void]$homePanel.Children.Add($script:multiHome)
 $nav=$script:referenceControls.RefAgents.Parent
 $script:referenceControls.RefAgents.Add_Click({Select-OrbyProviderPage 'chatgpt'})
 $script:providerNav.chatgpt=$script:referenceControls.RefAgents
 foreach($id in @('claude','gemini')){
  $button=[Windows.Controls.Button]::new();$button.Style=$script:referenceHome.Resources['NavButton']
  $button.Content=New-OrbyProviderLogo $id;$button.ToolTip=$script:providerCatalog[$id].Name+' status';$button.Visibility='Collapsed'
  $button.CommandParameter=$id;$button.Add_Click({param($sender,$eventArgs) Invoke-OrbySafeAction { Select-OrbyProviderPage ([string]$sender.CommandParameter) } 'Select-OrbyProviderPage'});$button.Add_MouseRightButtonUp({Show-OrbyConnections})
  $nav.Children.Insert(3,$button);$script:providerNav[$id]=$button
 }
 $window.Add_Closed({foreach($card in $script:providerCards.Values){$card.Renderer.Dispose();foreach($b in $card.Buddies){$b.Renderer.Dispose()}}})
 Update-OrbyMultiProvider
}
function Update-OrbyMultiProvider {
 if(-not $script:multiHome){return}
 $ids=@(Get-OrbyPairedProviders);if(-not $ids.Count){$ids=@('chatgpt')}
 # Claude first, as approved in V1. Gemini can be paired independently too.
 $ids=@(@('claude','chatgpt','gemini') | Where-Object {$_ -in $ids})
 $key=$ids -join ','
 if($script:multiHomeKey -ne $key){
  $script:multiHome.Children.Clear();$script:multiHome.ColumnDefinitions.Clear();$script:multiHome.RowDefinitions.Clear()
  $columns=[math]::Min(2,$ids.Count);$rows=[int][math]::Ceiling($ids.Count/2.0)
  for($i=0;$i -lt $columns;$i++){[void]$script:multiHome.ColumnDefinitions.Add([Windows.Controls.ColumnDefinition]::new())}
  for($i=0;$i -lt $rows;$i++){[void]$script:multiHome.RowDefinitions.Add([Windows.Controls.RowDefinition]::new())}
  foreach($id in $ids){
   if(-not $script:providerCards[$id]){$script:providerCards[$id]=New-OrbyProviderCard $id}

   $view=$script:providerCards[$id].View;$view.Margin=[Windows.Thickness]::new(0,0,$(if($script:multiHome.Children.Count%2 -eq 0 -and $ids.Count -gt 1){10}else{0}),$(if($ids.Count -gt 2 -and $script:multiHome.Children.Count -lt 2){10}else{0}))
   [Windows.Controls.Grid]::SetColumn($view,$script:multiHome.Children.Count%$columns);[Windows.Controls.Grid]::SetRow($view,[int][math]::Floor($script:multiHome.Children.Count/$columns));[void]$script:multiHome.Children.Add($view)
  }
  $script:multiHomeKey=$key
 }
 if(-not $script:compactMenus -and $script:referenceControls.RefHomePage.Visibility -eq 'Visible'){
  $height=if($ids.Count -gt 2){254}else{156}
  $script:referenceHome.Height=$height;$script:referenceControls.RefContentRow.Height=[Windows.GridLength]::new($height-42)
  if($expandedArea){$expandedArea.Height=$height};if($notch){$notch.ExpandedHeight=$height+14}
 }
 $visible=$script:expanded -and $script:referenceControls.RefHomePage.Visibility -eq 'Visible' -and -not $script:fullscreenHidden
 foreach($cachedCard in $script:providerCards.Values){$cachedCard.Renderer.Suspended=$true;foreach($b in $cachedCard.Buddies){$b.Renderer.Suspended=$true};if($cachedCard.Id -notin $ids){Set-OrbyProviderAccent $cachedCard.Parts $cachedCard.Id $true $false}}
 $statuses=@()
 foreach($id in $ids){
  $status=Get-OrbyIndependentStatus $id;$statuses+=$status;$card=$script:providerCards[$id];$c=$card.Controls
  $c.Title.Text=if($status.Sleeping){$status.Detail}elseif($status.State -eq 'unknown'){$(if($status.Open){'App open'}else{'Waiting for activity'})}elseif($status.State -eq 'idle'){'Ready'}elseif($status.Title -eq $status.Name){$status.Detail}else{$status.Title};$c.Title.ToolTip=$c.Title.Text
  $c.Detail.Text=if($status.Sleeping){'Wakes when activity returns'}elseif($status.Detail -eq $c.Title.Text){''}else{$status.Detail};$c.Detail.ToolTip=$c.Detail.Text
  $c.SleepLabel.Visibility=if($status.Sleeping){'Visible'}else{'Collapsed'}
  $c.Glow.Color=[Windows.Media.Colors]::Transparent
  Set-OrbyProviderAccent $card.Parts $id $status.Sleeping ($visible -and -not $script:orbySettings.ReducedMotion)
  foreach($r in @($card.Renderer)+@($card.Buddies | ForEach-Object {$_.Renderer})){
   $r.Suspended=-not $visible;$r.ReducedMotion=[bool]$script:orbySettings.ReducedMotion;$r.EyeEffects=[bool]$script:orbySettings.EyeEffects
   # An unavailable activity signal does not mean the app/account is offline.
   $r.SetState($(if($status.State -eq 'unknown'){'idle'}else{$status.State}),$status.Detail)
   $r.StatusConnected=$status.Readable -and $status.Open
  }
  $animate=$visible -and -not $script:orbySettings.ReducedMotion
  $motionKey=[string]$animate+'|'+[string]$status.Sleeping
  if($card.MotionKey -ne $motionKey){
   $card.MotionKey=$motionKey;$c.SleepLabel.BeginAnimation([Windows.UIElement]::OpacityProperty,$null)
   $c.GlowBrush.BeginAnimation([Windows.Media.RadialGradientBrush]::CenterProperty,$null)
   if($animate -and -not $status.Sleeping){$drift=[Windows.Media.Animation.PointAnimation]::new([Windows.Point]::new(.46,.46),[Windows.Point]::new(.53,.52),[timespan]::FromSeconds(18));$drift.AutoReverse=$true;$drift.RepeatBehavior=[Windows.Media.Animation.RepeatBehavior]::Forever;$drift.EasingFunction=[Windows.Media.Animation.SineEase]::new();$c.GlowBrush.BeginAnimation([Windows.Media.RadialGradientBrush]::CenterProperty,$drift)}

   if($animate -and $status.Sleeping){$breath=[Windows.Media.Animation.DoubleAnimation]::new(.35,.8,[timespan]::FromSeconds(2.5));$breath.AutoReverse=$true;$breath.RepeatBehavior=[Windows.Media.Animation.RepeatBehavior]::Forever;$c.SleepLabel.BeginAnimation([Windows.UIElement]::OpacityProperty,$breath)}
  }
  # A paired provider keeps its menu even when closed; its card truthfully sleeps.
  $script:providerNav[$id].Visibility='Visible'
 }
 foreach($id in $script:providerNav.Keys){if($id -notin $ids){$script:providerNav[$id].Visibility='Collapsed'}}
 Set-OrbyProviderIcon 'chatgpt'
 $script:referenceControls.RefConnection.Text=($statuses | ForEach-Object {$_.Name+' · '+$(if($_.State -eq 'unknown'){if($_.Open){'App open'}else{'Waiting for activity'}}elseif($_.Sleeping){'Sleeping'}elseif($_.State -eq 'idle'){'Ready'}else{$_.State})}) -join ' | '
 Update-OrbyNeighborGlance $visible
 # Compact Orby follows any active provider, rather than the last chosen account tab.
 $active=$statuses | Where-Object {$_.State -in @('attention','working','error')} | Select-Object -First 1
 $mainState=if($active){$active.State}elseif(@($statuses | Where-Object {-not $_.Sleeping}).Count -eq 0){'sleep'}else{'idle'}
 if($script:avatarRenderer -and -not $script:waterPriority){$script:avatarRenderer.SetState($mainState,$(if($active){$active.Detail}else{''}))}
 $script:multiProviderStatuses=$statuses
}
function Update-OrbyProviderView {
 if($script:referenceControls.RefAgentsPage.Visibility -eq 'Visible' -and $script:orbySettings.PrimaryProvider -ne 'chatgpt'){& $script:singleProviderView}
 Update-OrbyMultiProvider
}
function Update-OrbyNeighborGlance {
 param([bool]$Visible)
 if(-not $Visible -or $script:orbySettings.ReducedMotion){return}
 $left=$script:providerCards.claude;$right=$script:providerCards.chatgpt
 if(-not $left -or -not $right -or $left.View.Parent -ne $script:multiHome -or $right.View.Parent -ne $script:multiHome){return}
 $now=[datetime]::UtcNow
 if(-not $script:nextNeighborGlance){$script:nextNeighborGlance=$now.AddSeconds((Get-Random -Minimum 45 -Maximum 91));return}
 if($now -lt $script:nextNeighborGlance -or -not $left.Renderer.CanGlanceAtNeighbor -or -not $right.Renderer.CanGlanceAtNeighbor){return}
 [void]$left.Renderer.GlanceAtNeighbor(1);[void]$right.Renderer.GlanceAtNeighbor(-1)
 $script:nextNeighborGlance=$now.AddSeconds((Get-Random -Minimum 90 -Maximum 181))
}
function Update-OrbyProviderState {
 Update-OrbyConnections
 $script:primaryProviderSnapshot=$null;$script:primaryProviderState=$null
 Update-OrbyProviderView
}
