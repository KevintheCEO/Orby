[xml]$eventXml=Get-Content (Join-Path $PSScriptRoot 'Event-Card.xaml') -Raw
$script:eventCard=[Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader $eventXml))
$script:eventControls=@{}
foreach($name in @('EventOrb','EventColor','EventStatus','EventTitle','EventDetail','EventOpen','EventDismiss','EventPrompt')){$script:eventControls[$name]=$script:eventCard.FindName($name)}
$script:eventAvatar=New-OrbitAvatar
$script:eventControls.EventOrb.Child=$script:eventAvatar.Root
$script:eventRenderer=New-Object OrbyAvatarRenderer ($script:eventAvatar)
$script:referenceHome.Parent.Children.Add($script:eventCard) | Out-Null
$script:eventControls.EventOpen.Add_Click({if($script:orbyEventMode -eq 'drop' -and $script:dropFiles.Count){Submit-OrbyDropPrompt}else{Focus-ChatGpt}})
$script:eventControls.EventDismiss.Add_Click({$script:eventDismissed=$script:eventSignature;$script:dropBusy=$false;$script:dropFiles=@();$script:eventControls.EventPrompt.Text='';Update-OrbyEventCard})
$script:orbyEventMode='';$script:eventSignature='';$script:eventDismissed=''
function Update-OrbyEventCard {
 $mode=if($script:chatLogState -eq 'attention'){'attention'}elseif($script:chatLogState -eq 'success'){'success'}else{''}
 $signature=$mode+'|'+$script:chatLogActiveConversation+'|'+$script:chatLogActiveTurn+'|'+$script:chatLogMessage
 if($signature -eq $script:eventDismissed -and $mode -ne 'attention'){$mode=''}
 if($script:dropBusy){$mode='drop'}
 if($mode -eq $script:orbyEventMode -and $signature -eq $script:eventSignature){return}
 $script:eventControls.EventPrompt.Visibility='Collapsed'
 $script:eventControls.EventDetail.Visibility='Visible'
 $script:eventControls.EventOpen.Content='Open ChatGPT'
 $script:orbyEventMode=$mode;$script:eventSignature=$signature
 if(Get-Command Update-OrbyAlbumArt -ErrorAction SilentlyContinue){Update-OrbyAlbumArt}
 if($script:dropPanel){$script:dropPanel.Visibility='Collapsed'}
 if($mode){
  $script:referenceHome.Visibility='Collapsed';$script:eventCard.Visibility='Visible'
  $script:eventControls.EventTitle.Text=Get-NotchTaskTitle 'ChatGPT task'
  $script:eventControls.EventTitle.ToolTip=$script:eventControls.EventTitle.Text
  $script:eventControls.EventDismiss.Visibility=if($mode -eq 'attention'){'Collapsed'}else{'Visible'}
  $script:eventControls.EventStatus.Text=if($mode -eq 'attention' -and $script:chatLogMessage -match '(?i)permission|approval'){'ChatGPT needs approval'}elseif($mode -eq 'attention'){'ChatGPT needs your input'}elseif($mode -eq 'drop'){'Files for a new chat'}else{'ChatGPT finished'}
  $script:eventControls.EventDetail.Text=if($mode -eq 'attention'){$script:chatLogMessage}elseif($mode -eq 'drop'){'Preparing attachments...'}else{'Task complete'}
  $script:eventControls.EventColor.Color=[Windows.Media.ColorConverter]::ConvertFromString($(if($mode -eq 'attention'){'#614821'}else{'#1C624B'}))
  $script:eventRenderer.SetState($(if($mode -eq 'attention'){'attention'}elseif($mode -eq 'success'){'success'}else{'idle'}),'')
  $script:expanded=$false;Set-OrbitExpanded $true
  if($mode -eq 'drop'){Show-OrbyDropComposer}
  $pulse=New-Object Windows.Media.Animation.DoubleAnimation
  $pulse.From=0.25;$pulse.To=0.72;$pulse.Duration=[Windows.Duration]::new([timespan]::FromSeconds(1.8));$pulse.AutoReverse=$true;$pulse.RepeatBehavior=[Windows.Media.Animation.RepeatBehavior]::Forever
  if(-not $script:orbySettings.ReducedMotion){$script:eventControls.EventColor.BeginAnimation([Windows.Media.GradientStop]::OffsetProperty,$pulse)}
 }else{
  $script:eventControls.EventColor.BeginAnimation([Windows.Media.GradientStop]::OffsetProperty,$null)
  $script:eventCard.Visibility='Collapsed';$script:referenceHome.Visibility='Visible'
  $script:expanded=$true;Set-OrbitExpanded $false
 }
}
$window.Add_Closed({$script:eventRenderer.Dispose()})
. (Join-Path $PSScriptRoot 'Drop-Composer.ps1')
. (Join-Path $PSScriptRoot 'Chat-Drop.ps1')

