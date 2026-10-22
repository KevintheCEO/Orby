[xml]$dropXml=Get-Content (Join-Path $PSScriptRoot 'Drop-Composer.xaml') -Raw
$script:dropPanel=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($dropXml))
$script:dropControls=@{}
foreach($name in @('DropClose','DropClear','DropTarget','DropChat','DropChips','DropStatus','DropPrompt','DropSend','DropTargetOrb','DropChatOrb','DropHeading','DropProviders','DropEditor')){$script:dropControls[$name]=$script:dropPanel.FindName($name)}
[void]$expandedArea.Children.Add($script:dropPanel)
$script:dropAvatars=@()
foreach($name in @('DropTargetOrb','DropChatOrb')){
 $parts=New-OrbitAvatar;$script:dropControls[$name].Child=$parts.Root
 $renderer=New-Object OrbyAvatarRenderer ($parts);$renderer.SetState('idle','');$script:dropAvatars+=$renderer
}
function Select-OrbyDropProvider([string]$Id){
 if($script:dropHandle -or $script:dropRequiresReview -or $Id -notin ($script:orbySettings.ProviderEnabled -split ',')){return}
 $script:dropProvider=$Id
 $script:dropControls.DropHeading.Text='Send to '+$script:providerCatalog[$Id].Name
 $script:dropControls.DropEditor.Visibility='Visible'
 $script:dropControls.DropStatus.Text='Add an optional message, or send just the files.'
 $script:dropControls.DropPrompt.IsEnabled=$true;$script:dropControls.DropSend.IsEnabled=$true
 [void]$script:dropControls.DropPrompt.Focus()
}
function Show-OrbyDropComposer {
 $script:dropPanel.Visibility='Visible'
 $script:dropControls.DropTarget.Visibility=if($script:dropFiles.Count){'Collapsed'}else{'Visible'}
 $script:dropControls.DropChat.Visibility=if($script:dropFiles.Count){'Visible'}else{'Collapsed'}
 $script:eventCard.Visibility='Collapsed';$script:referenceHome.Visibility='Collapsed'
 $script:dropControls.DropChips.Children.Clear()
 foreach($file in $script:dropFiles){
  $chip=[Windows.Controls.TextBlock]::new();$chip.Text=[IO.Path]::GetFileName($file);$chip.Foreground=[Windows.Media.Brushes]::White;$chip.FontSize=12;$chip.MaxWidth=160;$chip.TextTrimming='CharacterEllipsis';$chip.Margin='0,4,12,0';$chip.ToolTip=$file;[void]$script:dropControls.DropChips.Children.Add($chip)
 }
 $script:dropControls.DropProviders.Children.Clear()
 foreach($id in @('chatgpt','claude','gemini')){
  $button=[Windows.Controls.Button]::new();$button.Tag=$id;$button.Margin='0,0,6,0';$button.IsEnabled=($id -in ($script:orbySettings.ProviderEnabled -split ',')) -and -not $script:dropHandle
  $row=[Windows.Controls.StackPanel]::new();$row.Orientation='Horizontal'
  $logo=[Windows.Shapes.Path]::new();$logo.Width=22;$logo.Height=22;$logo.Stretch='Uniform';$logo.Margin='0,0,8,0'
  if($id -eq 'chatgpt'){$logo.Data=$script:openAiLogo;$logo.Fill=[Windows.Media.Brushes]::White}else{$logo.Data=$script:providerIconResources[($id.Substring(0,1).ToUpper()+$id.Substring(1)+'Logo')];$logo.Fill=$script:providerIconResources[($id.Substring(0,1).ToUpper()+$id.Substring(1)+'Brush')]}
  [void]$row.Children.Add($logo);$label=[Windows.Controls.TextBlock]::new();$label.Text=$script:providerCatalog[$id].Name;$label.VerticalAlignment='Center';[void]$row.Children.Add($label);$button.Content=$row
  $button.Add_Click({param($sender,$e) Select-OrbyDropProvider ([string]$sender.Tag)})
  [void]$script:dropControls.DropProviders.Children.Add($button)
 }
}
function Close-OrbyDropComposer {
 if($script:dropOperation){$script:dropOperation.Cancelled=$true}
 if($script:dropWorker){[OrbyBackgroundShutdown]::Stop($script:dropWorker,$script:dropRunspace)}
 $script:dropWorker=$null;$script:dropRunspace=$null;$script:dropHandle=$null;$script:dropOperation=$null
 $script:dropFiles=@();$script:dropProvider='';$script:dropBusy=$false;$script:dropRequiresReview=$false
 $script:dropControls.DropPrompt.Text='';$script:dropControls.DropEditor.Visibility='Collapsed';$script:dropPanel.Visibility='Collapsed'
 $script:eventControls.EventDismiss.IsEnabled=$true
 $script:eventDismissed=$script:eventSignature
 Update-OrbyEventCard
 if($script:orbyEventMode -eq 'success'){$script:eventDismissed=$script:eventSignature;Update-OrbyEventCard}
 Set-OrbyHomePage 'home'
}
$script:dropControls.DropClose.Add_Click({Close-OrbyDropComposer})
$script:dropControls.DropClear.Add_Click({
 if($script:dropHandle -or $script:dropRequiresReview){Close-OrbyDropComposer;return}
 $script:dropProvider='';$script:dropControls.DropEditor.Visibility='Collapsed';$script:dropControls.DropHeading.Text='Choose an AI';$script:dropControls.DropStatus.Text='Select where to send these files.'
})
$script:dropControls.DropSend.Add_Click({Submit-OrbyDropPrompt})
$window.Add_Closed({foreach($renderer in $script:dropAvatars){$renderer.Dispose()}})
