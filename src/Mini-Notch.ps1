# Mini uses the same task/context strings as Default, with smaller live controls.
function Get-OrbyMiniLabel {
 param($Model)
 if(-not $Model -or -not $Model.Items.Count){return ''}
 return ($Model.Items | ForEach-Object {$_.Full}) -join ' | '
}
function Get-OrbyMiniModel {
 param($Model,[double]$MaxWidth=1100)
 $items=@();if($Model){$items=@($Model.Items)}
 $art=[bool]($Model -and $Model.HasArtwork);$split=$items.Count -gt 1
 $first=if($items.Count){[string]$items[0].Full}else{''};$second=if($split){[string]$items[1].Full}else{''}
 $a=(Get-OrbyCompactTextWidth $first 9)+4;$b=if($split){(Get-OrbyCompactTextWidth $second 9)+4}else{0}
 $reserve=16+20+7+$(if($art){22}else{0})+$(if($split){39}else{0})
 $width=[math]::Ceiling([math]::Min([math]::Max(200,$MaxWidth),[math]::Max(200,$reserve+$a+$b)))
 $budget=[math]::Max(0,$width-$reserve)
 $right=if($split){[math]::Max([math]::Min(72,$budget/2),[math]::Min($budget-[math]::Min(72,$budget/2),$b))}else{0}
 [pscustomobject]@{Width=$width;First=$first;Second=$second;Split=$split;SecondWidth=$(if($split){39+$right}else{0});HasArtwork=$art}
}
function Initialize-OrbyMiniNotch {
 if($script:miniNotchView){return}
 [xml]$x=@'
<Grid xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Width="184" Height="20" HorizontalAlignment="Center" VerticalAlignment="Top" Visibility="Collapsed" ClipToBounds="True" UseLayoutRounding="True" SnapsToDevicePixels="True">
 <Grid.ColumnDefinitions><ColumnDefinition Width="20"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="0"/></Grid.ColumnDefinitions>
 <Canvas x:Name="FirstHost" Width="20" Height="20"/>
 <TextBlock x:Name="FirstLabel" Grid.Column="1" FontFamily="Segoe UI" FontSize="9" FontWeight="Bold" Foreground="White" VerticalAlignment="Center" Margin="4,0,3,0" TextTrimming="CharacterEllipsis"/>
 <Grid x:Name="Second" Grid.Column="2" Visibility="Collapsed" Height="20" Width="0" ClipToBounds="True"><Grid.ColumnDefinitions><ColumnDefinition Width="12"/><ColumnDefinition Width="20"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
  <Border Width="1" Height="12" Background="#35FFFFFF" VerticalAlignment="Center"/>
  <Canvas x:Name="SecondHost" Grid.Column="1" Width="20" Height="20"/>
  <TextBlock x:Name="SecondLabel" Grid.Column="2" FontFamily="Segoe UI" FontSize="9" FontWeight="Bold" Foreground="White" VerticalAlignment="Center" Margin="4,0,3,0" TextTrimming="CharacterEllipsis"/>
  <Grid.RenderTransform><TranslateTransform x:Name="Arrival"/></Grid.RenderTransform>
 </Grid>
</Grid>
'@
 $view=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($x))
 $parts=New-OrbitAvatar;$parts.Root.RenderTransform=[Windows.Media.ScaleTransform]::new(.36,.36);[void]$view.FindName('FirstHost').Children.Add($parts.Root)
 $renderer=[OrbyAvatarRenderer]::new($parts);$renderer.SyncWith=$script:avatarRenderer;$renderer.Suspended=$true
 $secondParts=New-OrbitAvatar;$secondParts.Root.RenderTransform=[Windows.Media.ScaleTransform]::new(.36,.36);[void]$view.FindName('SecondHost').Children.Add($secondParts.Root)
 $secondRenderer=[OrbyAvatarRenderer]::new($secondParts);$secondRenderer.Suspended=$true
 [void]$window.FindName('Root').Children.Add($view)
 $script:miniNotchView=$view;$script:miniNotchLabel=$view.FindName('FirstLabel');$script:miniNotchRenderer=$renderer;$script:miniNotchParts=$parts
 $script:miniNotchSecond=@{View=$view.FindName('Second');Label=$view.FindName('SecondLabel');Arrival=$view.FindName('Arrival');Parts=$secondParts;Renderer=$secondRenderer}
 $window.Add_Closed({if($script:miniNotchRenderer){$script:miniNotchRenderer.SyncWith=$null;$script:miniNotchRenderer.Dispose()};if($script:miniNotchSecond){$script:miniNotchSecond.Renderer.Dispose()}})
}
function Update-OrbyMiniNotch {
 param($Model)
 $mini=$script:orbySettings.NotchSize -eq 'mini' -and -not $script:waterPriority
 if(-not $mini -and -not $script:miniNotchView){return}
 if($mini){Initialize-OrbyMiniNotch}
 $changed=$script:miniNotchActive -ne $mini;$script:miniNotchActive=$mini
 $notch.MiniMode=$mini
 $view=$script:miniNotchView;$shown=$mini -and -not $script:expanded -and -not $script:fullscreenHidden
 $view.Visibility=if($shown){'Visible'}else{'Collapsed'}
 $script:miniNotchRenderer.Suspended=-not $shown
 $second=$script:miniNotchSecond;$second.Renderer.Suspended=$true
 $header=$window.FindName('CompactHeader')
 if($mini){
  $header.BeginAnimation([Windows.UIElement]::OpacityProperty,$null);$header.Opacity=0
  $script:avatarRenderer.Suspended=$script:expanded -or $script:fullscreenHidden
  foreach($pet in $script:miniOrbys){$pet.Renderer.Suspended=$true}
  if($script:compactSecond){$script:compactSecond.Renderer.Suspended=$true}
  $max=1100.0;if('OrbyMonitorLayout' -as [type]){$max=[math]::Min(1100,[OrbyMonitorLayout]::AvailableWidth($window)-40)}
  $layout=Get-OrbyMiniModel $Model $max
  $reduced=[bool]$script:orbySettings.ReducedMotion -or -not [Windows.SystemParameters]::ClientAreaAnimation
  if($script:miniTargetWidth -ne $layout.Width -or $changed){
   $script:miniTargetWidth=$layout.Width
   if($layout.Width -gt $notch.Width){$notch.ReserveWidth($layout.Width);if(Test-Path function:Position-Orbit){Position-Orbit}}
   if($reduced -or $changed){$notch.BeginAnimation([OrbyLiquidSurface]::MiniWidthProperty,$null);$notch.MiniWidth=$layout.Width;$view.BeginAnimation([Windows.FrameworkElement]::WidthProperty,$null);$view.Width=$layout.Width-16}
   else{Invoke-OrbyMotion $notch ([OrbyLiquidSurface]::MiniWidthProperty) $layout.Width .28;Invoke-OrbyMotion $view ([Windows.FrameworkElement]::WidthProperty) ($layout.Width-16) .28}
   if(Test-Path function:Set-OrbyAlbumPlacement){Set-OrbyAlbumPlacement ([bool]$script:expanded) (-not $reduced)}
  }
  $script:miniNotchLabel.Text=$layout.First;$script:miniNotchLabel.ToolTip=$layout.First
  $second.View.Visibility=if($layout.Split){'Visible'}else{'Collapsed'}
  if($script:miniSecondTargetWidth -ne $layout.SecondWidth -or $changed){
   $script:miniSecondTargetWidth=$layout.SecondWidth
   if($reduced -or $changed -or -not $layout.Split){$second.View.BeginAnimation([Windows.FrameworkElement]::WidthProperty,$null);$second.View.Width=$layout.SecondWidth}
   else{Invoke-OrbyMotion $second.View ([Windows.FrameworkElement]::WidthProperty) $layout.SecondWidth .28}
  }
  $second.Label.Text=$layout.Second;$second.Label.ToolTip=$layout.Second
  $second.Renderer.Suspended=-not ($shown -and $layout.Split);$second.Renderer.ReducedMotion=$reduced;$second.Renderer.EyeEffects=[bool]$script:orbySettings.EyeEffects
  if($layout.Split){
   $item=$Model.Items[1];$second.Renderer.StatusConnected=$true;$second.Renderer.SetState($item.State,$item.Detail)
   Set-OrbyProviderAccent $second.Parts $item.Id $false ($shown -and -not $reduced)
   if(-not $script:miniWasSplit -and $shown -and -not $reduced){$slide=[Windows.Media.Animation.DoubleAnimation]::new(18,0,[timespan]::FromSeconds(.28));$slide.EasingFunction=[Windows.Media.Animation.CubicEase]::new();$slide.EasingFunction.EasingMode='EaseOut';$second.Arrival.BeginAnimation([Windows.Media.TranslateTransform]::XProperty,$slide)}
  }
  if($reduced -or -not $layout.Split){$second.Arrival.BeginAnimation([Windows.Media.TranslateTransform]::XProperty,$null);$second.Arrival.X=0}
  $script:miniWasSplit=$layout.Split
  if($Model.Items.Count){Set-OrbyProviderAccent $script:miniNotchParts $Model.Items[0].Id $false ($shown -and -not $reduced)}
  $view.ColumnDefinitions[3].Width=[Windows.GridLength]::new($(if($layout.HasArtwork){22}else{0}))
  $view.ToolTip=if($Model -and $Model.Tooltip){$Model.Tooltip}else{'Orby · Hover to open the menu'}
 }elseif($changed){
  $header.BeginAnimation([Windows.UIElement]::OpacityProperty,$null);$header.Opacity=if($script:expanded){0}else{1}
 }
 if(-not $shown -and $script:miniNotchParts.AccentId){Set-OrbyProviderAccent $script:miniNotchParts $script:miniNotchParts.AccentId $false $false}
 if((-not $shown -or -not $script:miniWasSplit) -and $second.Parts.AccentId){Set-OrbyProviderAccent $second.Parts $second.Parts.AccentId $false $false}
 if($changed -and (Test-Path function:Set-OrbyAlbumPlacement)){Set-OrbyAlbumPlacement ([bool]$script:expanded) $false}
}
