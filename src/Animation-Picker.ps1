function Show-OrbyAnimations {
 if($script:animationWindow -and $script:animationWindow.IsVisible){[void]$script:animationWindow.Activate();return}
  $previewRoot=if($script:orbyPrivateWater){Join-Path $PSScriptRoot 'Personal'}else{$PSScriptRoot}
 [xml]$xml=Get-Content (Join-Path $previewRoot 'Animation-Picker.xaml') -Raw
 $script:animationWindow=[Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader $xml))
 $script:previewAvatarParts=New-OrbitAvatar
 $script:animationWindow.FindName('PreviewHost').Child=$script:previewAvatarParts.Root
 $script:previewAnimationRenderer=New-Object OrbyAvatarRenderer ($script:previewAvatarParts)
 $list=$script:animationWindow.FindName('Clips');$list.DisplayMemberPath='';foreach($clip in [OrbyPack.Catalog]::All){$entry=[Windows.Controls.ListBoxItem]::new();$entry.Content=$clip.Name;$entry.Tag=$clip;[void]$list.Items.Add($entry)}
 $list.Add_SelectionChanged({param($sender,$args)
  $clip=$sender.SelectedItem.Tag;if($clip){$script:previewAnimationRenderer.Preview($clip.Id);$script:animationWindow.FindName('ClipInfo').Text=$clip.Name+' | '+$clip.Duration+' ms'+$(if($clip.Loop){' | loop'}else{' | one shot'})}
 })
 $reduced=$script:animationWindow.FindName('Reduced');$reduced.IsChecked=[bool]$script:orbySettings.ReducedMotion
 $reduced.Add_Click({param($sender,$args)if(-not $script:orbyPrivateWater){$script:orbySettings.ReducedMotion=[bool]$sender.IsChecked;Save-OrbySettings};$script:previewAnimationRenderer.ReducedMotion=[bool]$sender.IsChecked})
 $script:animationWindow.Add_Closed({$script:previewAnimationRenderer.Dispose()})
 $list.SelectedIndex=0;if($script:orbyPrivateWater){. (Join-Path $PSScriptRoot 'Personal/Water-Preview.ps1');Initialize-OrbyPrivateWaterPreview};$script:animationWindow.Show();[void]$script:animationWindow.Activate()
}
