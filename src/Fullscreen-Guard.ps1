Add-Type -Path (Join-Path $PSScriptRoot 'Fullscreen-Detect.cs')
$script:fullscreenHidden=$false
function Repair-OrbyFullscreenPresentation {
 $script:expanded=$false
 [OrbyMotion.Driver]::Snap($notch,[OrbyLiquidSurface]::MorphProperty,0)
 $expandedArea.BeginAnimation([Windows.UIElement]::OpacityProperty,$null);$expandedArea.Opacity=0;$expandedArea.Visibility='Collapsed'
 $header=$window.FindName('CompactHeader');$header.BeginAnimation([Windows.UIElement]::OpacityProperty,$null);$header.Opacity=1
 Set-OrbyAlbumPlacement $false $false
 $window.BeginAnimation([Windows.UIElement]::OpacityProperty,$null);$window.Opacity=1
 if($script:avatarRenderer){$script:avatarRenderer.Suspended=$false}
 foreach($mini in $script:miniOrbys){$mini.Renderer.Suspended=$false}
 $window.WindowState=[Windows.WindowState]::Normal;$window.ShowActivated=$false;$window.Show();$window.Topmost=$true
 Position-Orbit
 $notch.Attach($window)
 if(Test-Path function:Update-OrbyCompactTask){Update-OrbyCompactTask}
 [OrbyFullscreen]::RaiseWithoutActivation([Windows.Interop.WindowInteropHelper]::new($window).Handle)
}
function Set-OrbyFullscreenHidden {
 param([bool]$hide)
 if($hide -eq $script:fullscreenHidden){return}
 $script:fullscreenHidden=$hide
 if($hide){
  $script:hoverExitTimer.Stop()
  if($script:musicPopup){$script:musicPopup.IsOpen=$false}
  [OrbyMotion.Driver]::Snap($notch,[OrbyLiquidSurface]::MorphProperty,0)
  $window.Hide();Write-OrbitLog 'FULLSCREEN quiet: notch hidden'
 }else{Repair-OrbyFullscreenPresentation;Write-OrbitLog 'FULLSCREEN quiet: notch restored'}
}
function Get-OrbyFullscreenObservation {
 [OrbyFullscreen]::Observe([Windows.Interop.WindowInteropHelper]::new($window).Handle)
}
$script:fullscreenCandidate=$false
$script:fullscreenCandidateSince=[datetime]::UtcNow
$script:fullscreenForeground=0L
$script:fullscreenForegroundSince=[datetime]::UtcNow
$script:fullscreenRaisedForeground=0L
$script:fullscreenGeometry=''
function Update-OrbyFullscreenGuard {
 param([datetime]$Now=[datetime]::UtcNow)
 try {
  $observation=Get-OrbyFullscreenObservation
  # Screenshot/overlay focus is temporary: preserve the previous stable decision.
  if($observation.Transient -and $script:orbySettings.HideFullscreen){return}
  if($script:fullscreenForeground -ne $observation.Foreground -or $script:fullscreenGeometry -ne [string]$observation.Geometry){$script:fullscreenForeground=$observation.Foreground;$script:fullscreenGeometry=[string]$observation.Geometry;$script:fullscreenForegroundSince=$Now;$script:fullscreenRaisedForeground=0L}
  $hide=[bool]$script:orbySettings.HideFullscreen -and $observation.Fullscreen
  if($hide -ne $script:fullscreenCandidate){$script:fullscreenCandidate=$hide;$script:fullscreenCandidateSince=$Now}
  if(-not $script:orbySettings.HideFullscreen -or ($Now-$script:fullscreenCandidateSince).TotalMilliseconds -ge $(if($hide){600}else{400})){Set-OrbyFullscreenHidden $hide}
  # Windows can reorder topmost windows during a full-screen/normal transition.
  # Reassert once per stable normal foreground, without activating or stealing input.
  if(-not $hide -and -not $script:fullscreenHidden -and ($Now-$script:fullscreenForegroundSince).TotalMilliseconds -ge 600 -and $script:fullscreenRaisedForeground -ne $script:fullscreenForeground){
   $script:fullscreenRaisedForeground=$script:fullscreenForeground
   [OrbyFullscreen]::RaiseWithoutActivation([Windows.Interop.WindowInteropHelper]::new($window).Handle)
  }
 }catch{Write-OrbitLog ('FULLSCREEN guard failed: '+$_.Exception.Message);Set-OrbyFullscreenHidden $false}
}
$script:fullscreenTimer=[Windows.Threading.DispatcherTimer]::new();$script:fullscreenTimer.Interval=[timespan]::FromMilliseconds(200)
$script:fullscreenTimer.Add_Tick({Update-OrbyFullscreenGuard});$script:fullscreenTimer.Start()
$window.Add_Closed({$script:fullscreenTimer.Stop()})
