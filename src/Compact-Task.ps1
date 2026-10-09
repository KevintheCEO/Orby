function Update-OrbyCompactTask {
 $label=$window.FindName('CompactTaskTitle')
 $title='No active task'
 if($script:chatLogState -in @('working','attention','success','error','stopped')){
  $title=Get-NotchTaskTitle 'ChatGPT task'
 }
 if($script:orbySettings.PrimaryProvider -and $script:orbySettings.PrimaryProvider -ne 'chatgpt'){
  $snap=Get-OrbyProviderSnapshot $script:orbySettings.PrimaryProvider;$title=$script:providerCatalog[$script:orbySettings.PrimaryProvider].Name+' · '+$(if($snap){$snap.Detail}else{'Open app to connect'})
 }
 $label.Text=$title;$label.ToolTip=$title
 $label.Foreground=[Windows.Media.BrushConverter]::new().ConvertFromString($(if($title -eq 'No active task'){'#8E929A'}else{'#F1F2F4'}))
 $label.Margin=[Windows.Thickness]::new(0,0,$(if($script:albumCoverButton.Visibility -eq 'Visible'){48}else{8}),0)
}
