function Update-OrbyCompactTask {
 $label=$window.FindName('CompactTaskTitle')
 $title='No active task'
 if($script:chatLogState -in @('working','attention','success','error','stopped')){
  $title=Get-NotchTaskTitle 'ChatGPT task'
 }
 $label.Text=$title;$label.ToolTip=$title
 $label.Foreground=[Windows.Media.BrushConverter]::new().ConvertFromString($(if($title -eq 'No active task'){'#8E929A'}else{'#F1F2F4'}))
 $label.Margin=[Windows.Thickness]::new(0,0,$(if($script:albumCoverButton.Visibility -eq 'Visible'){48}else{8}),0)
}
