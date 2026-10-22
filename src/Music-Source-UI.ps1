function Reset-OrbyMusicSelection {
 $script:orbyShared.SelectedMusic=$null;$script:orbyShared.Media=$null;$script:orbyShared.MusicResult=''
 $script:pendingMusicSeek=$null;$script:referenceMusicDragging=$false;$script:musicDragging=$false
 $script:referenceMusicArtKey='';$script:albumArtKey='';$script:compactArtworkAccent=[Windows.Media.Colors]::Transparent
 if($script:referenceControls){$script:referenceControls.RefMusicCover.Source=$null}
 if($script:albumCoverButton){$script:albumCoverButton.Visibility='Collapsed';$script:albumCoverButton.ApplyTemplate() | Out-Null;$image=$script:albumCoverButton.Template.FindName('AlbumCoverImage',$script:albumCoverButton);if($image){$image.Source=$null}}
 if($notch){$notch.SetArtworkAccent([Windows.Media.Colors]::Transparent,$false,$false)}
}
function Set-OrbyPreferredMusicSource {
 param([string]$Id='')
 if([string]$script:orbySettings.MediaApp -eq $Id){return}
 $script:orbySettings.MediaApp=$Id;Reset-OrbyMusicSelection;Save-OrbySettings
 if(Test-Path function:Update-OrbyMusicTab){Update-OrbyMusicTab}
 if(Test-Path function:Update-OrbyCompactMenus){Update-OrbyCompactMenus}
}
function Show-OrbyMusicSources {
 param($Button)
 $menu=[Windows.Controls.ContextMenu]::new();$menu.Background=[Windows.Media.BrushConverter]::new().ConvertFromString('#17191F');$menu.Foreground=[Windows.Media.Brushes]::White
 foreach($option in @(Get-OrbyMusicSourceOptions $script:orbyShared.MusicSources ([string]$script:orbySettings.MediaApp))){
  $item=[Windows.Controls.MenuItem]::new();$item.Header=$option.Name;$item.IsCheckable=$true;$item.IsChecked=$option.Id -eq [string]$script:orbySettings.MediaApp
  $item.CommandParameter=[string]$option.Id;$item.Add_Click({param($sender,$eventArgs) Invoke-OrbySafeAction { Set-OrbyPreferredMusicSource ([string]$sender.CommandParameter) } 'Set-OrbyPreferredMusicSource'});[void]$menu.Items.Add($item)
 }
 [void]$menu.Items.Add([Windows.Controls.Separator]::new())
 $note=[Windows.Controls.MenuItem]::new();$note.Header='Open your music app and play a song to add it';$note.IsEnabled=$false;[void]$menu.Items.Add($note)
 $script:musicSourceMenu=$menu
 $menu.Add_Closed({$script:musicSourceMenu=$null;if((Test-Path function:Test-OrbyPointerInside) -and -not (Test-OrbyPointerInside)){Set-OrbitExpanded $false}})
 $Button.ContextMenu=$menu;$menu.PlacementTarget=$Button;$menu.IsOpen=$true
}
function Adjust-OrbyMusicVolume {
 param([double]$Delta=0,[switch]$Mute)
 $m=$script:orbyShared.SelectedMusic;if(-not $m){return}
 $channel=[OrbyVolumeWorker]::ForSource($m.App);$snap=$channel.Snapshot
 if(-not $snap -or $snap.Error){$channel.Refresh();return}
 if(-not $script:musicPreviousVolumes){$script:musicPreviousVolumes=@{}}
 $value=if($Mute){if($snap.Value -gt 0){$script:musicPreviousVolumes[$m.App]=$snap.Value;0}else{if($script:musicPreviousVolumes[$m.App]){$script:musicPreviousVolumes[$m.App]}else{50}}}else{$snap.Value+$Delta}
 [void]$channel.Set($value)
}
