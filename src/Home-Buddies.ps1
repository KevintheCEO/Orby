function Initialize-OrbyHomeBuddies {
 $script:homeBuddies=@()
 $colors=@('#45BCB8','#E74766','#EDAE46','#A765ED')
 for($i=0;$i -lt 4;$i++){
  $parts=New-OrbitAvatar
  $parts.OrbBody.Background=[Windows.Media.BrushConverter]::new().ConvertFromString($colors[$i])
  $renderer=[OrbyAvatarRenderer]::new($parts);$renderer.ShowStatusDot=$false;$renderer.EyeEffects=$false;$renderer.SetState('idle','')
  $hostView=$script:referenceHome.FindName('RefBuddyHost'+$i);$hostView.Child=$parts.Root
  $buddy=@{Parts=$parts;Renderer=$renderer;Host=$hostView};$script:homeBuddies+=$buddy
  $hoverRenderer=$renderer
  $hostView.Add_MouseEnter({if(-not $hoverRenderer.ReducedMotion){[void]$hoverRenderer.Trigger('hover_happy')}}.GetNewClosure())
 }
}
function Update-OrbyHomeBuddies {
 if(Test-Path function:Update-OrbyAmbientMotion){Update-OrbyAmbientMotion}
 $tasks=@($script:orbyActiveTasks)
 for($i=0;$i -lt $script:homeBuddies.Count;$i++){
  $buddy=$script:homeBuddies[$i];$buddy.Renderer.ReducedMotion=[bool]$script:orbySettings.ReducedMotion -or -not [Windows.SystemParameters]::ClientAreaAnimation
  $task=if($i -lt $tasks.Count){$tasks[$i]}else{$null}
  if($task){$buddy.Renderer.SetState($task.State,$task.Action)}else{$buddy.Renderer.SetState('idle','')}
 }
}
function Stop-OrbyHomeBuddies {foreach($buddy in $script:homeBuddies){$buddy.Renderer.Dispose()}}
