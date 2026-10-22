# Cached, local Spotify artwork; decoding happens only when the worker publishes new art.
$script:albumCoverButton=$window.FindName('AlbumCoverButton')
$script:albumArtKey=''
Add-Type -Path (Join-Path $PSScriptRoot 'Artwork-Palette.cs') -ReferencedAssemblies WindowsBase,PresentationCore
$script:compactArtworkAccent=[Windows.Media.Colors]::Transparent
function Get-OrbyCompactArtworkAccent {
 param($Bitmap)
 return [OrbyArtworkPalette]::Sample($Bitmap)
}
function Update-OrbyArtworkProgress {
 param([datetime]$Now=[datetime]::UtcNow)
 if(-not $script:albumProgress){
  $script:albumCoverButton.ApplyTemplate() | Out-Null
  $script:albumProgress=$script:albumCoverButton.Template.FindName('AlbumProgress',$script:albumCoverButton)
 }
 if(-not $script:albumProgress){return}
 $media=$script:orbyShared.SelectedMusic
 if($script:albumCoverButton.Visibility -ne 'Visible' -or $script:expanded -or $script:fullscreenHidden -or $script:waterPriority -or -not $media -or $media.Duration -le 0 -or -not $script:orbySettings.Music){
  $script:albumProgress.Progress=0;$script:albumProgress.Visibility='Collapsed';return
 }
 $position=Get-OrbySmoothMusicPosition $media $Now
 $script:albumProgress.Progress=[math]::Max(0.0,[math]::Min(1.0,($position-$media.Start)/$media.Duration))
 $script:albumProgress.Visibility='Visible'
}
function Convert-OrbyAlbumBitmap {
 param([byte[]]$Bytes)
 if(-not $Bytes -or $Bytes.Length -gt 8388608){return $null}
 $stream=New-Object IO.MemoryStream (,$Bytes)
 try{
  $bitmap=New-Object Windows.Media.Imaging.BitmapImage
  $bitmap.BeginInit();$bitmap.CacheOption=[Windows.Media.Imaging.BitmapCacheOption]::OnLoad
  $bitmap.StreamSource=$stream;$bitmap.EndInit();$bitmap.Freeze()
  return $bitmap
 }finally{$stream.Dispose()}
}
function Open-OrbySpotify {
 try{Start-Process 'spotify:' -ErrorAction Stop}catch{Write-OrbitLog ('Spotify launch failed: '+$_.Exception.Message)}
}
$script:albumCoverButton.Add_Click({param($sender,$eventArgs)$eventArgs.Handled=$true;Set-OrbitExpanded $true;Set-OrbyHomePage 'music'})
function Update-OrbyAlbumArt {
 $media=$script:orbyShared.SelectedMusic
 $diagnostic=([string]$script:orbyShared.MediaError)+' | '+([string]$script:orbyShared.ArtworkError)+' | apps='+(@($script:orbyShared.MediaApps) -join ',')
 if($diagnostic -ne $script:albumDiagnostic){$script:albumDiagnostic=$diagnostic;Write-OrbitLog ('MEDIA ART '+$diagnostic)}
 $button=$script:albumCoverButton
 if($script:orbyEventMode -or -not $script:orbySettings.Music -or -not $media -or -not $media.ArtworkBytes){
  $button.Visibility='Collapsed';$script:albumArtKey='';$script:compactArtworkAccent=[Windows.Media.Colors]::Transparent;$notch.SetArtworkAccent($script:compactArtworkAccent,$false,$false);return
 }
 $button.ToolTip=($media.Title+' - '+$media.Artist+$(if($media.Playing){''}else{' (paused)'})+' | Music controls')
 if($script:albumRetryKey -eq $media.ArtworkKey -and $script:albumRetryAt -and [datetime]::UtcNow -lt $script:albumRetryAt){$notch.SetArtworkAccent($script:compactArtworkAccent,$false,$false);return}
 $motion=-not [bool]$script:orbySettings.ReducedMotion -and [Windows.SystemParameters]::ClientAreaAnimation
 $notch.SetArtworkAccent($script:compactArtworkAccent,(-not $script:waterPriority -and -not $script:expanded),$motion)
 if($script:albumArtKey -eq $media.ArtworkKey){return}
 try{
  $bitmap=Convert-OrbyAlbumBitmap $media.ArtworkBytes
  $button.ApplyTemplate() | Out-Null
  $image=$button.Template.FindName('AlbumCoverImage',$button)
  $image.Source=$bitmap;$button.Visibility='Visible';$script:compactArtworkAccent=Get-OrbyCompactArtworkAccent $bitmap;$script:albumArtKey=$media.ArtworkKey;$script:albumRetryKey='';$script:albumRetryAt=$null;$notch.SetArtworkAccent($script:compactArtworkAccent,(-not $script:waterPriority -and -not $script:expanded),$motion);Write-OrbitLog ('MEDIA ART loaded '+$media.Title+' bytes='+$media.ArtworkBytes.Length)
 }catch{$script:albumRetryKey=$media.ArtworkKey;$script:albumRetryAt=[datetime]::UtcNow.AddSeconds(2);$button.Visibility='Collapsed';$notch.SetArtworkAccent($script:compactArtworkAccent,$false,$false);Write-OrbitLog ('Album artwork decode failed: '+$_.Exception.Message)}
}

# Keep artwork attached to the visible header rather than floating above the menu.
$script:albumScale=[Windows.Media.ScaleTransform]::new(1,1,16,16)
$script:albumMove=New-Object Windows.Media.TranslateTransform
$script:albumTransforms=New-Object Windows.Media.TransformGroup
$script:albumTransforms.Children.Add($script:albumScale)
$script:albumTransforms.Children.Add($script:albumMove)
$script:albumCoverButton.RenderTransform=$script:albumTransforms
function Set-OrbyAlbumPlacement {
 param([bool]$Expand,[bool]$Animate=$true)
 if($script:orbySettings -and $script:orbySettings.ReducedMotion){$Animate=$false}
 $x=0.0;$y=0.0;$scale=1.0
 if(-not $Expand -and $script:compactTargetWidth){$x=$script:compactTargetWidth/2-$(if($script:compactDual){143}else{186})}
 if(-not $Expand -and $script:miniNotchActive){$x=-29.0+$(if($script:miniTargetWidth){($script:miniTargetWidth-200)/2}else{0});$y=-14.0;$scale=.375}
 if($Expand){
  $x=-245.0;$y=-2.0;$scale=0.75
  if($script:referenceControls -and $script:referenceControls.RefSettings.ActualWidth -gt 0){
   $settings=$script:referenceControls.RefSettings
   $point=$settings.TranslatePoint([Windows.Point]::new($settings.ActualWidth+24,$settings.ActualHeight/2),$window.FindName('Root'))
   $x=$point.X-($window.Width/2+115);$y=$point.Y-24
  }
 }
 foreach($item in @(@($script:albumMove,[Windows.Media.TranslateTransform]::XProperty,$x),@($script:albumMove,[Windows.Media.TranslateTransform]::YProperty,$y),@($script:albumScale,[Windows.Media.ScaleTransform]::ScaleXProperty,$scale),@($script:albumScale,[Windows.Media.ScaleTransform]::ScaleYProperty,$scale))){
  if($Animate){Invoke-OrbyMotion $item[0] $item[1] $item[2] 0.18}
  else{$item[0].BeginAnimation($item[1],$null);$item[0].SetValue($item[1],[double]$item[2])}
 }
}


function Write-OrbyMediaWarning {
 param([string]$Area,$ErrorRecord)
 if(-not $script:mediaWarnings){$script:mediaWarnings=@{}}
 $now=[datetime]::UtcNow
 if(-not $script:mediaWarnings[$Area] -or ($now-$script:mediaWarnings[$Area]).TotalSeconds -ge 30){$script:mediaWarnings[$Area]=$now;Write-OrbitLog ($Area+' update failed: '+$ErrorRecord.Exception.GetBaseException().Message)}
}
$script:artTimer=New-Object Windows.Threading.DispatcherTimer ([Windows.Threading.DispatcherPriority]::Background)
$script:artTimer.Interval=[timespan]::FromMilliseconds(200)
$script:artTimer.Add_Tick({try{Update-OrbyAlbumArt;if($script:musicPopup -and $script:musicPopup.IsOpen){Update-OrbyMusicPlayer}}catch{Write-OrbyMediaWarning 'Artwork' $_}})
$script:artTimer.Start()
$script:musicTimelineTimer=New-Object Windows.Threading.DispatcherTimer ([Windows.Threading.DispatcherPriority]::Background)
$script:musicTimelineTimer.Interval=[timespan]::FromMilliseconds(33)
$script:musicTimelineTimer.Add_Tick({try{Update-OrbyArtworkProgress;if($script:referenceControls -and $script:referenceControls.RefMusicPage.Visibility -eq 'Visible'){Update-OrbyMusicTab}}catch{Write-OrbyMediaWarning 'Timeline' $_}})
$script:musicTimelineTimer.Start()
$window.Add_Closed({
 if($script:musicPopup){$script:musicPopup.IsOpen=$false}
 $script:musicTimelineTimer.Stop();$script:artTimer.Stop();$script:orbyShared.Stop=$true
 [OrbyBackgroundShutdown]::Stop($script:mediaControlWorker,$script:mediaControlRunspace)
 
 [OrbyBackgroundShutdown]::Stop($script:mediaWorker,$script:mediaRunspace)
 
})

