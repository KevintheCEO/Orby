# Launch feedback is temporary UI state, never evidence that the provider is open.
$script:openingFeedback=@{}
$script:lastProviderLaunch=@{}
function Stop-OrbyOpeningFeedback {
 param([string]$Id)
 $entry=$script:openingFeedback[$Id]
 if($entry){$entry.Wave.Stop();$entry.Finish.Stop();$script:openingFeedback.Remove($Id)}
}
function Stop-OrbyAllOpeningFeedback {
 foreach($id in @($script:openingFeedback.Keys)){Stop-OrbyOpeningFeedback $id}
}
function Start-OrbyOpeningFeedback {
 param([string]$Id)
 if($script:orbySettings.ReducedMotion -or -not [Windows.SystemParameters]::ClientAreaAnimation){return}
 Stop-OrbyOpeningFeedback $Id
 $card=$script:providerCards[$Id];$status=Get-OrbyIndependentStatus $Id
 $hosts=@();$renderers=@()
 if($card){$hosts+=,$card.Controls.MainHost;$renderers+=,$card.Renderer}
 if($script:avatarRenderer -and -not $script:expanded){$renderers+=,$script:avatarRenderer}
 if(-not $script:expanded -and $script:orbParts -and $script:orbParts.Root.Parent){$hosts+=,$script:orbParts.Root.Parent}
 if(-not $script:expanded -and $script:miniNotchView){$hosts+=,$script:miniNotchView.FindName('FirstHost')}
 foreach($hostView in $hosts){
  if(-not $hostView){continue}
  $scale=[Windows.Media.ScaleTransform]::new(1,1);$hostView.RenderTransformOrigin=[Windows.Point]::new(.5,.65);$hostView.RenderTransform=$scale
  foreach($axis in @('X','Y')){
   $animation=[Windows.Media.Animation.DoubleAnimationUsingKeyFrames]::new();$animation.Duration=[Windows.Duration]::new([timespan]::FromSeconds(.42));$animation.FillBehavior='Stop'
   if($script:displayHz -gt 0){[Windows.Media.Animation.Timeline]::SetDesiredFrameRate($animation,$script:displayHz)}
   foreach($point in @(@(0,1),@(.07,$(if($axis -eq 'Y'){.95}else{1.025})),@(.20,1.025),@(.42,1))){
    $key=[Windows.Media.Animation.EasingDoubleKeyFrame]::new();$key.Value=$point[1];$key.KeyTime=[Windows.Media.Animation.KeyTime]::FromTimeSpan([timespan]::FromSeconds($point[0]));$key.EasingFunction=[Windows.Media.Animation.CubicEase]::new();$key.EasingFunction.EasingMode='EaseOut';[void]$animation.KeyFrames.Add($key)
   }
   $property=if($axis -eq 'X'){[Windows.Media.ScaleTransform]::ScaleXProperty}else{[Windows.Media.ScaleTransform]::ScaleYProperty}
   $scale.BeginAnimation($property,$animation)
  }
 }
 # Working/approval/error activity keeps its own higher-priority avatar state.
 if($status.State -in @('working','attention','error')){return}
 foreach($renderer in $renderers){$renderer.SetState('idle','');[void]$renderer.Trigger('wake_up')}
 $wave=[Windows.Threading.DispatcherTimer]::new();$wave.Interval=[timespan]::FromMilliseconds(820)
 $finish=[Windows.Threading.DispatcherTimer]::new();$finish.Interval=[timespan]::FromSeconds(2.5)
 $entry=@{Id=$Id;Wave=$wave;Finish=$finish;Until=[datetime]::UtcNow.AddSeconds(2.5);Renderers=$renderers;Hosts=$hosts}
 $script:openingFeedback[$Id]=$entry
 $wave.Tag=$entry;$finish.Tag=$entry
 $wave.Add_Tick({param($sender,$eventArgs)
  $sender.Stop();$context=$sender.Tag;$id=$context.Id
  if($script:openingFeedback[$id] -ne $context -or $script:orbySettings.ReducedMotion -or -not [Windows.SystemParameters]::ClientAreaAnimation){return}
  $current=Get-OrbyIndependentStatus $id
  if($current.State -notin @('working','attention','error')){foreach($targetRenderer in $context.Renderers){[void]$targetRenderer.Trigger('wave')}}
 })
 $finish.Add_Tick({param($sender,$eventArgs)$sender.Stop();$context=$sender.Tag;$id=$context.Id;if($script:openingFeedback[$id] -eq $context){Stop-OrbyOpeningFeedback $id;Update-OrbyMultiProvider}})
 $wave.Start();$finish.Start()
}
function Test-OrbyOpeningFeedback {
 param([string]$Id,$Status)
 $entry=$script:openingFeedback[$Id]
 if(-not $entry){return $false}
 if($script:orbySettings.ReducedMotion -or -not [Windows.SystemParameters]::ClientAreaAnimation -or $entry.Until -le [datetime]::UtcNow -or $Status.State -in @('working','attention','error')){
  foreach($hostView in $entry.Hosts){if($hostView.RenderTransform -is [Windows.Media.ScaleTransform]){$hostView.RenderTransform.BeginAnimation([Windows.Media.ScaleTransform]::ScaleXProperty,$null);$hostView.RenderTransform.BeginAnimation([Windows.Media.ScaleTransform]::ScaleYProperty,$null);$hostView.RenderTransform.ScaleX=$hostView.RenderTransform.ScaleY=1}}
  Stop-OrbyOpeningFeedback $Id;return $false
 }
 return $true
}
