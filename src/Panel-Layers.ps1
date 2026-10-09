function Set-OrbyCompactLayer {
 param([Windows.UIElement]$Header,[bool]$Expanded)
 if($Expanded){
  # Remove the old fade clock before the expanded surface is drawn.
  $Header.BeginAnimation([Windows.UIElement]::OpacityProperty,$null)
  $Header.Opacity=0
 }else{Invoke-OrbyMotion $Header ([Windows.UIElement]::OpacityProperty) 1 0.14}
}
function Set-OrbyEventUnderlay {
 param([bool]$OverlayActive)
 if($script:referenceControls.RefConnection){
  $script:referenceControls.RefConnection.Visibility=if($OverlayActive){'Collapsed'}else{'Visible'}
 }
}
