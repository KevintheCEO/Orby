function Initialize-OrbyMinis {
 $script:miniOrbys=@()
 $hostCanvas=$window.FindName('MiniOrbyHost')
 $colors=@('#E74766','#A765ED','#45BCB8','#EDAE46')
 for($i=0;$i -lt 4;$i++){
  $parts=New-OrbitAvatar
  $parts.OrbBody.Background=[Windows.Media.BrushConverter]::new().ConvertFromString($colors[$i])
  $parts.Root.RenderTransform=[Windows.Media.ScaleTransform]::new(0.34,0.34)
  [Windows.Controls.Canvas]::SetLeft($parts.Root,($i%2)*17-1)
  [Windows.Controls.Canvas]::SetTop($parts.Root,[math]::Floor($i/2)*17-1)
  $parts.Root.Opacity=0.35
  [void]$hostCanvas.Children.Add($parts.Root)
  $renderer=New-Object OrbyAvatarRenderer ($parts);$renderer.SetState('idle','')
  $script:miniOrbys+=@{Parts=$parts;Renderer=$renderer;TaskId=''}
 }
}
function Update-OrbyMinis {
 param([object[]]$Tasks,[bool]$ReducedMotion)
 for($i=0;$i -lt $script:miniOrbys.Count;$i++){
  $mini=$script:miniOrbys[$i];$task=$null
  if($i+1 -lt $Tasks.Count){$task=$Tasks[$i+1]}
  $buddy=if($task){$script:compactTaskStack.Buddies[[string]$task.Id]}else{$null}
  if($buddy){
   $mini.Renderer.SyncWith=$buddy.Renderer
   $mini.Parts.OrbBody.Background=$buddy.Parts.OrbBody.Background
   $mini.Parts.Root.Opacity=1;$mini.Parts.Root.ToolTip=$task.Title+' - '+$task.Action
   $mini.TaskId=[string]$task.Id
  }else{
   $mini.Renderer.SyncWith=$null;$mini.Renderer.ReducedMotion=$ReducedMotion;$mini.Renderer.SetState('idle','')
   $mini.Parts.Root.Opacity=0.35;$mini.Parts.Root.ToolTip='No additional task';$mini.TaskId=''
  }
 }
}
function Stop-OrbyMinis {foreach($mini in $script:miniOrbys){$mini.Renderer.SyncWith=$null;$mini.Renderer.Dispose()}}
