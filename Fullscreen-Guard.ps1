Add-Type -Path (Join-Path $PSScriptRoot 'Fullscreen-Detect.cs')
$script:fullscreenHidden=$false
function Set-OrbyFullscreenHidden {
 param([bool]$hide)
 if($hide -eq $script:fullscreenHidden){return}
 $script:fullscreenHidden=$hide
 if($hide){
  $script:hoverExitTimer.Stop()
  if($script:musicPopup){$script:musicPopup.IsOpen=$false}
  $window.Hide();Write-OrbitLog 'FULLSCREEN quiet: notch hidden'
 }else{
  $script:expanded=$false
  $notch.BeginAnimation([OrbyLiquidSurface]::MorphProperty,$null);$notch.Morph=0
  $expandedArea.Visibility='Collapsed';$header=$window.FindName('CompactHeader');$header.BeginAnimation([Windows.UIElement]::OpacityProperty,$null);$header.Opacity=1;Set-OrbyAlbumPlacement $false
  $window.ShowActivated=$false;$window.Show();Position-Orbit;Write-OrbitLog 'FULLSCREEN quiet: notch restored'
 }
}
function Update-OrbyFullscreenGuard {Set-OrbyFullscreenHidden ([bool]$script:orbySettings.HideFullscreen -and [OrbyFullscreen]::Active())}
$script:fullscreenTimer=[Windows.Threading.DispatcherTimer]::new();$script:fullscreenTimer.Interval=[timespan]::FromMilliseconds(200)
$script:fullscreenTimer.Add_Tick({Update-OrbyFullscreenGuard});$script:fullscreenTimer.Start()
$window.Add_Closed({$script:fullscreenTimer.Stop()})

