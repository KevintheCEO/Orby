function Show-OrbyAnimations {
 if($script:animationWindow -and $script:animationWindow.IsVisible){[void]$script:animationWindow.Activate();return}
 [xml]$xml=Get-Content (Join-Path $PSScriptRoot 'Animation-Picker.xaml') -Raw
 $script:animationWindow=[Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader $xml))
 $script:previewAvatarParts=New-OrbitAvatar
 $script:animationWindow.FindName('PreviewHost').Child=$script:previewAvatarParts.Root
 $script:previewAnimationRenderer=New-Object OrbyAvatarRenderer ($script:previewAvatarParts)
 $list=$script:animationWindow.FindName('Clips');$list.ItemsSource=[OrbyPack.Catalog]::All
 $list.Add_SelectionChanged({param($sender,$args)
  $clip=$sender.SelectedItem;if($clip){$script:previewAnimationRenderer.Preview($clip.Id);$script:animationWindow.FindName('ClipInfo').Text=$clip.Name+' | '+$clip.Duration+' ms'+$(if($clip.Loop){' | loop'}else{' | one shot'})}
 })
 $reduced=$script:animationWindow.FindName('Reduced');$reduced.IsChecked=[bool]$script:orbySettings.ReducedMotion
 $reduced.Add_Click({param($sender,$args)$script:orbySettings.ReducedMotion=[bool]$sender.IsChecked;Save-OrbySettings;$script:previewAnimationRenderer.ReducedMotion=[bool]$sender.IsChecked})
 $script:animationWindow.Add_Closed({$script:previewAnimationRenderer.Dispose()})
 $list.SelectedIndex=0;$script:animationWindow.Show();[void]$script:animationWindow.Activate()
}
