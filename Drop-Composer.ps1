[xml]$dropXml=Get-Content (Join-Path $PSScriptRoot 'Drop-Composer.xaml') -Raw
$script:dropPanel=[Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader $dropXml))
$script:dropControls=@{}
foreach($name in @('DropClose','DropClear','DropTarget','DropChat','DropChips','DropStatus','DropPrompt','DropSend','DropTargetOrb','DropChatOrb')){$script:dropControls[$name]=$script:dropPanel.FindName($name)}
$script:referenceHome.Parent.Children.Add($script:dropPanel) | Out-Null
$script:dropAvatars=@()
foreach($name in @('DropTargetOrb','DropChatOrb')){
 $parts=New-OrbitAvatar;$script:dropControls[$name].Child=$parts.Root
 $renderer=New-Object OrbyAvatarRenderer ($parts);$renderer.SetState('idle','');$script:dropAvatars+=$renderer
}
function Show-OrbyDropComposer {
 $script:dropPanel.Visibility='Visible';$script:dropControls.DropTarget.Visibility=if($script:dropFiles.Count){'Collapsed'}else{'Visible'}
 $script:dropControls.DropChat.Visibility=if($script:dropFiles.Count){'Visible'}else{'Collapsed'}
 $script:eventCard.Visibility='Collapsed';$script:referenceHome.Visibility='Collapsed'
 $script:dropControls.DropChips.Children.Clear()
 foreach($file in $script:dropFiles){
  $chip=New-Object Windows.Controls.Border;$chip.CornerRadius=[Windows.CornerRadius]::new(9);$chip.Background=[Windows.Media.BrushConverter]::new().ConvertFromString('#2A2B3A');$chip.Padding=[Windows.Thickness]::new(8,3,8,3);$chip.Margin=[Windows.Thickness]::new(0,0,5,4)
  $text=New-Object Windows.Controls.TextBlock;$text.Text=[IO.Path]::GetFileName($file);$text.Foreground=[Windows.Media.Brushes]::White;$text.FontSize=10;$text.MaxWidth=130;$text.TextTrimming='CharacterEllipsis';$chip.ToolTip=$file;$chip.Child=$text
  $script:dropControls.DropChips.Children.Add($chip) | Out-Null
 }
}
function Close-OrbyDropComposer {
 if($script:dropHandle){return}
 $script:dropFiles=@();$script:dropBusy=$false;$script:dropControls.DropPrompt.Text='';$script:dropPanel.Visibility='Collapsed';Update-OrbyEventCard
}
$script:dropControls.DropClose.Add_Click({Close-OrbyDropComposer})
$script:dropControls.DropClear.Add_Click({Close-OrbyDropComposer;$script:dropBusy=$true;Update-OrbyEventCard})
$script:dropControls.DropSend.Add_Click({Submit-OrbyDropPrompt})
$window.Add_Closed({foreach($renderer in $script:dropAvatars){$renderer.Dispose()}})
