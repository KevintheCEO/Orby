# Compact display owns active-provider text; unreadable/idle providers do not become tasks.
. (Join-Path $PSScriptRoot 'Provider-Accents.ps1')
. (Join-Path $PSScriptRoot 'Mini-Notch.ps1')
function Get-OrbyCompactTextWidth {
 param([string]$Text,[double]$FontSize=12)
 $face=[Windows.Media.Typeface]::new([Windows.Media.FontFamily]::new('Segoe UI'),[Windows.FontStyles]::Normal,[Windows.FontWeights]::Bold,[Windows.FontStretches]::Normal)
 if($FontSize -lt 12){
  $dpi=if($window){[Windows.Media.VisualTreeHelper]::GetDpi($window).PixelsPerDip}else{1.0}
  $formatted=[Windows.Media.FormattedText]::new($Text,[Globalization.CultureInfo]::CurrentCulture,[Windows.FlowDirection]::LeftToRight,$face,$FontSize,[Windows.Media.Brushes]::White,$null,[Windows.Media.TextFormattingMode]::Display,$dpi)
 }else{$formatted=[Windows.Media.FormattedText]::new($Text,[Globalization.CultureInfo]::CurrentCulture,[Windows.FlowDirection]::LeftToRight,$face,$FontSize,[Windows.Media.Brushes]::White)}
 return [math]::Ceiling($formatted.WidthIncludingTrailingWhitespace)
}
function Get-OrbyCompactModel {
 param([object[]]$Statuses,[double]$MaxWidth=1100,[bool]$HasArtwork=$false)
 $active=@($Statuses | Where-Object {$_.State -in @('working','attention','error')})
 $ids=@($active | ForEach-Object {$_.Id})
 $script:compactProviderOrder=@($script:compactProviderOrder | Where-Object {$_ -in $ids})
 foreach($id in $ids){if($id -notin $script:compactProviderOrder){$script:compactProviderOrder+=,$id}}
 $active=@($script:compactProviderOrder | ForEach-Object {$id=$_;$active | Where-Object {$_.Id -eq $id}} | Select-Object -First 2)
 $items=@()
 foreach($status in $active){
  $detail=([string]$status.Detail -replace '\s+',' ').Trim()
  $detail=$detail -replace '^(Claude|ChatGPT)\s*(chat|Code)?\s*[·:]\s*',''
  $name=[string]$status.Name
  $task=([string]$status.Title -replace '\s+',' ').Trim()
  if($task -and $task -ne $name -and $task -ne 'ChatGPT task'){$detail=$task+$(if($detail){' · '+$detail})}
  $full=$name+' · '+$detail
  $items+= [pscustomobject]@{Id=$status.Id;State=$status.State;Detail=$status.Detail;Text=$full;Full=$full;Sleeping=$status.Sleeping}
 }
 $split=$items.Count -gt 1
 $reserve=if($split){172+$(if($HasArtwork){48}else{0})}else{126+$(if($HasArtwork){57}else{0})}
 $width=360.0
 if($items.Count){$measure=@($items | ForEach-Object {Get-OrbyCompactTextWidth $_.Text});$required=if($split){2*($measure | Measure-Object -Maximum).Maximum}else{$measure[0]};$width=[math]::Max(360,$reserve+$required)}
 $width=[math]::Min([math]::Max(360,$MaxWidth),$width)
 $budget=($width-$reserve)/[math]::Max(1,$items.Count)
 foreach($item in $items){
  if((Get-OrbyCompactTextWidth $item.Text) -gt $budget){
   $name=($active | Where-Object {$_.Id -eq $item.Id} | Select-Object -First 1).Name
   $item.Text=$name+' · '+$(switch($item.State){attention{'Needs input'}error{'Task error'}default{'Working'}})
  }
 }
 [pscustomobject]@{Items=$items;Split=$split;Width=$width;Text=$(if($items.Count){$items[0].Text}else{''});Tooltip=($items | ForEach-Object {$_.Full}) -join "`n";HasArtwork=$HasArtwork}
}
function Initialize-OrbyAdaptiveCompact {
 if($script:compactSecond){return}
 $header=$window.FindName('CompactHeader')
 if(-not $header -or -not $script:avatarRenderer){return}
 $miniHost=$window.FindName('MiniOrbyHost')
 if(-not $miniHost){return}
 $script:compactMinisHost=$miniHost.Parent
 [Windows.Controls.Grid]::SetColumn($script:compactMinisHost,3)
 $miniColumn=[Windows.Controls.ColumnDefinition]::new();$miniColumn.Width=[Windows.GridLength]::Auto;[void]$header.ColumnDefinitions.Add($miniColumn)
 $second=[Windows.Markup.XamlReader]::Parse('<Grid xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Visibility="Collapsed" VerticalAlignment="Center"><Grid.ColumnDefinitions><ColumnDefinition Width="18"/><ColumnDefinition Width="54"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions><Border Width="1" Height="30" Background="#35FFFFFF"/><Canvas x:Name="AvatarHost" Grid.Column="1" Width="54" Height="38"/><TextBlock x:Name="Title" Grid.Column="2" Foreground="#F1F2F4" FontFamily="Segoe UI" FontSize="12" FontWeight="Bold" VerticalAlignment="Center" TextTrimming="CharacterEllipsis"/><Grid.RenderTransform><TranslateTransform x:Name="Arrival"/></Grid.RenderTransform></Grid>')
 [Windows.Controls.Grid]::SetColumn($second,2);[void]$header.Children.Add($second)
 $parts=New-OrbitAvatar;[void]$second.FindName('AvatarHost').Children.Add($parts.Root)
 $renderer=[OrbyAvatarRenderer]::new($parts);$renderer.Suspended=$true
 $script:compactSecond=@{View=$second;Parts=$parts;Renderer=$renderer;Title=$second.FindName('Title');Arrival=$second.FindName('Arrival')}
 $window.Add_Closed({if($script:compactSecond){$script:compactSecond.Renderer.Dispose()}})
}
function Set-OrbyCompactWidth {
 param([double]$Width)
 if($script:compactTargetWidth -eq $Width){return}
 $script:compactTargetWidth=$Width
 if($notch -and $notch.PSObject.Methods['ReserveWidth']){
  if($Width -gt $notch.Width){$notch.ReserveWidth($Width);if(Test-Path function:Position-Orbit){Position-Orbit}}
  if($script:orbySettings.ReducedMotion){$notch.BeginAnimation([OrbyLiquidSurface]::CompactWidthProperty,$null);$notch.CompactWidth=$Width}
  else{Invoke-OrbyMotion $notch ([OrbyLiquidSurface]::CompactWidthProperty) $Width .28}
 }
 $header=$window.FindName('CompactHeader')
 if($script:orbySettings.ReducedMotion -or [double]::IsNaN($header.Width)){$header.BeginAnimation([Windows.FrameworkElement]::WidthProperty,$null);$header.Width=$Width-24}else{Invoke-OrbyMotion $header ([Windows.FrameworkElement]::WidthProperty) ($Width-24) .28}
 if(Test-Path function:Set-OrbyAlbumPlacement){Set-OrbyAlbumPlacement ([bool]$script:expanded)}
}
function Update-OrbyCompactTask {
 Initialize-OrbyAdaptiveCompact
 $label=$window.FindName('CompactTaskTitle')
 $hasArt=$script:albumCoverButton -and $script:albumCoverButton.Visibility -eq 'Visible'
 $maxWidth=1100.0
 if('OrbyMonitorLayout' -as [type]){$maxWidth=[math]::Min(1100,[OrbyMonitorLayout]::AvailableWidth($window)-40)}
 $statuses=@($script:multiProviderStatuses)
 if(-not $statuses.Count -and $script:chatLogState -in @('working','attention','error')){
  $statuses=@([pscustomobject]@{Id='chatgpt';Name='ChatGPT';Title=(Get-NotchTaskTitle 'ChatGPT task');State=$script:chatLogState;Detail=$script:chatLogMessage})
 }
 $model=Get-OrbyCompactModel $statuses $maxWidth $hasArt
 $waterTitle=if($script:waterDay){Get-OrbyWaterTitle}else{''}
 $script:compactProviderMode=[bool]$script:multiProviderStatuses
 $split=$model.Split -and -not $waterTitle
 $changed=$script:compactDual -ne $split
 $script:compactDual=$split
 $label.Text=if($waterTitle){$waterTitle}else{$model.Text}
 $label.ToolTip=if($waterTitle){(Get-OrbyWaterSummary)}else{$model.Tooltip}
 $label.Foreground=if($waterTitle){[Windows.Media.Brushes]::LightSkyBlue}else{[Windows.Media.Brushes]::White}
 $label.Cursor=if($waterTitle){[Windows.Input.Cursors]::Hand}else{[Windows.Input.Cursors]::Arrow}
 if($script:compactSecond){
  $second=$script:compactSecond
  $second.View.Visibility=if($split){'Visible'}else{'Collapsed'}
  $second.Renderer.Suspended=-not $split -or $script:expanded -or $script:fullscreenHidden
  $second.Renderer.ReducedMotion=[bool]$script:orbySettings.ReducedMotion
  $second.Renderer.EyeEffects=[bool]$script:orbySettings.EyeEffects
  if(-not $split -and $second.Parts.AccentId){Set-OrbyProviderAccent $second.Parts $second.Parts.AccentId $false $false}
  $script:compactMinisHost.Visibility=if($split){'Collapsed'}else{'Visible'}
  foreach($mini in $script:miniOrbys){$mini.Renderer.Suspended=$split -or $script:expanded -or $script:fullscreenHidden}
  if($split){
   $right=$model.Items[1];$second.Title.Text=$right.Text;$second.Title.ToolTip=$right.Full
   Set-OrbyProviderAccent $second.Parts $right.Id $false (-not $script:expanded -and -not $script:fullscreenHidden -and -not $script:orbySettings.ReducedMotion)
   $second.Renderer.StatusConnected=$true;$second.Renderer.SetState($right.State,$right.Detail)
   $second.View.Width=72+($model.Width-172-$(if($hasArt){48}else{0}))/2+$(if($hasArt){48}else{0})
   $second.Title.Margin=[Windows.Thickness]::new(0,0,$(if($hasArt){48}else{6}),0)
   if($changed){
    $second.Arrival.BeginAnimation([Windows.Media.TranslateTransform]::XProperty,$null);$second.View.BeginAnimation([Windows.UIElement]::OpacityProperty,$null)
    if(-not $script:orbySettings.ReducedMotion){
     $slide=[Windows.Media.Animation.DoubleAnimation]::new(52,0,[timespan]::FromSeconds(.36));$slide.EasingFunction=[Windows.Media.Animation.CubicEase]::new();$slide.EasingFunction.EasingMode='EaseOut'
     if($script:displayHz -gt 0){[Windows.Media.Animation.Timeline]::SetDesiredFrameRate($slide,$script:displayHz)}
     $second.Arrival.BeginAnimation([Windows.Media.TranslateTransform]::XProperty,$slide)
     $fade=[Windows.Media.Animation.DoubleAnimation]::new(0,1,[timespan]::FromSeconds(.24));if($script:displayHz -gt 0){[Windows.Media.Animation.Timeline]::SetDesiredFrameRate($fade,$script:displayHz)};$second.View.BeginAnimation([Windows.UIElement]::OpacityProperty,$fade)
    }else{$second.Arrival.X=0;$second.View.Opacity=1}
   }
  }
 }
 if($model.Items.Count -and -not $waterTitle -and -not $script:waterPriority){
  $first=$model.Items[0];$script:avatarRenderer.StatusConnected=$true;$script:avatarRenderer.SetState($first.State,$first.Detail)
  $script:compactAccentId=$first.Id
 }
 if($script:orbParts){Set-OrbyProviderAccent $script:orbParts $(if($script:compactAccentId){$script:compactAccentId}else{'chatgpt'}) $false (-not $script:expanded -and -not $script:fullscreenHidden -and -not $script:orbySettings.ReducedMotion)}
 $label.Margin=[Windows.Thickness]::new(0,0,$(if($hasArt -and -not $split){57}else{8}),0)
 $width=if($waterTitle){[math]::Max(360,118+$(if($hasArt){44}else{0})+(Get-OrbyCompactTextWidth $waterTitle))}else{$model.Width}
 Set-OrbyCompactWidth $width
 if($changed -and (Test-Path function:Set-OrbyAlbumPlacement)){Set-OrbyAlbumPlacement ([bool]$script:expanded)}
 Update-OrbyMiniNotch $model
 if($script:waterDay){Update-OrbyWaterPrompt}
}
