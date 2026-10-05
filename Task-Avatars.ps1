function Get-OrbyTaskPack {
 param([object[]]$Tasks)
 # One companion per chat, not per tool call or duplicate journal entry.
 $seen=@{}
 foreach($task in $Tasks){
  if(-not $task -or -not $task.Id -or $task.State -notin @('working','attention') -or $seen.ContainsKey([string]$task.Id)){continue}
  $seen[[string]$task.Id]=$true
  $task
 }
}
function New-OrbyTaskStack {
 param($HostCanvas,$Primary)
 [Windows.Controls.Panel]::SetZIndex($Primary.Root,20)
 return @{Host=$HostCanvas;Primary=$Primary;Buddies=@{}}
}
function Initialize-OrbyTaskPack {
 $script:compactTaskStack=New-OrbyTaskStack ($window.FindName('PetCanvas')) $script:orbParts
 $stackCanvas=New-Object Windows.Controls.Canvas
 $stackCanvas.Width=54;$stackCanvas.Height=56
 $script:referenceControls.RefOrbHost.Child=$null
 [void]$stackCanvas.Children.Add($script:referenceOrb.Root)
 $script:referenceControls.RefOrbHost.Child=$stackCanvas
 $script:expandedTaskStack=New-OrbyTaskStack $stackCanvas $script:referenceOrb
}
function Update-OrbyTaskStack {
 param($Stack,[object[]]$Tasks,[bool]$ReducedMotion=$false)
 if(-not $Stack){return}
 $colors=@('#E74766','#A765ED','#45BCB8','#EDAE46')
 $positions=@(@(-6,-8),@(25,-6),@(-7,18),@(27,18))
 $wanted=@{}
 for($i=1;$i -lt [Math]::Min(5,$Tasks.Count);$i++){
  $task=$Tasks[$i];$id=[string]$task.Id;$wanted[$id]=$true
  $buddy=$Stack.Buddies[$id]
  if(-not $buddy){
   $parts=New-OrbitAvatar
   $parts.Root.RenderTransform=New-Object Windows.Media.ScaleTransform(0.72,0.72)
   $renderer=New-Object OrbyAvatarRenderer ($parts)
   $buddy=@{Parts=$parts;Renderer=$renderer;Slot=-1}
   $Stack.Buddies[$id]=$buddy
   [void]$Stack.Host.Children.Add($parts.Root)
   if(-not $ReducedMotion){
    $fade=New-Object Windows.Media.Animation.DoubleAnimation(0,1,[Windows.Duration]::new([timespan]::FromMilliseconds(220)))
    $parts.Root.BeginAnimation([Windows.UIElement]::OpacityProperty,$fade)
   }
  }
  $slot=$i-1
  if($buddy.Slot -ne $slot){
   $brush=New-Object Windows.Media.RadialGradientBrush
   $brush.GradientOrigin=[Windows.Point]::new(0.32,0.22);$brush.Center=$brush.GradientOrigin
   $color=[Windows.Media.ColorConverter]::ConvertFromString($colors[$slot])
   $brush.GradientStops.Add([Windows.Media.GradientStop]::new($color,0))
   $dark=[Windows.Media.Color]::FromRgb([byte]($color.R*0.72),[byte]($color.G*0.72),[byte]($color.B*0.72))
   $brush.GradientStops.Add([Windows.Media.GradientStop]::new($dark,1));$brush.Freeze()
   $buddy.Parts.OrbBody.Background=$brush
   [Windows.Controls.Canvas]::SetLeft($buddy.Parts.Root,$positions[$slot][0])
   [Windows.Controls.Canvas]::SetTop($buddy.Parts.Root,$positions[$slot][1])
   [Windows.Controls.Panel]::SetZIndex($buddy.Parts.Root,10-$slot)
   $buddy.Slot=$slot
  }
  $buddy.Parts.Root.ToolTip=$task.Title+' - '+$task.Action
  $buddy.Renderer.ReducedMotion=$ReducedMotion
  $buddy.Renderer.SetState($task.State,$task.Action)
 }
 foreach($id in @($Stack.Buddies.Keys)){
  if(-not $wanted.ContainsKey($id)){
   $buddy=$Stack.Buddies[$id];$buddy.Renderer.Dispose()
   $Stack.Host.Children.Remove($buddy.Parts.Root);$Stack.Buddies.Remove($id)
  }
 }
}
function Update-OrbyTaskPack {
 $tasks=@(Get-OrbyTaskPack @($script:orbyActiveTasks))
 $reduced=([bool]$script:orbySettings.ReducedMotion -or -not [Windows.SystemParameters]::ClientAreaAnimation)
 Update-OrbyTaskStack $script:compactTaskStack $tasks $reduced
 Update-OrbyTaskStack $script:expandedTaskStack $tasks $reduced
 Update-OrbyMinis $tasks $reduced
 if($tasks.Count -gt 1){
  $tip=($tasks | ForEach-Object {$_.Title+' - '+$_.Action}) -join "`n"
  $label=$window.FindName('CompactTaskTitle')
  $label.Text=(Get-NotchTaskTitle 'ChatGPT task')+'  +'+($tasks.Count-1)
  $label.ToolTip=$tip;$script:orbParts.Root.ToolTip=$tip
 }else{$script:orbParts.Root.ToolTip=$null}
}
function Stop-OrbyTaskPack {
 foreach($stack in @($script:compactTaskStack,$script:expandedTaskStack)){
  if($stack){foreach($buddy in $stack.Buddies.Values){$buddy.Renderer.Dispose()}}
 }
}
