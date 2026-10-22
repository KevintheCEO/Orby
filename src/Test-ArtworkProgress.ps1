param([string]$PreviewDirectory='')
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Xaml
Add-Type -Path @((Join-Path $PSScriptRoot 'Liquid-Surface.cs'),(Join-Path $PSScriptRoot 'Monitor-Layout.cs')) -ReferencedAssemblies WindowsBase,PresentationCore,PresentationFramework,System.Xaml
. (Join-Path $PSScriptRoot 'Orb-Avatar.ps1')
. (Join-Path $PSScriptRoot 'Motion.ps1')
. (Join-Path $PSScriptRoot 'Music-Player.ps1')
$art=Get-Content (Join-Path $PSScriptRoot 'Media-Art.ps1') -Raw
$tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseInput($art,[ref]$tokens,[ref]$errors)
$fn=$ast.Find({param($node)$node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Update-OrbyArtworkProgress'},$true)
. ([scriptblock]::Create($fn.Extent.Text))
function Assert($ok,$message){if(-not $ok){throw $message}}
$source=Get-Content (Join-Path $PSScriptRoot 'Orby.ps1') -Raw
$markup=[regex]::Match($source,'(?s)\$xaml = @''\r?\n(.*?)\r?\n''@').Groups[1].Value.Replace('LIQUID_ASSEMBLY',[OrbyLiquidSurface].Assembly.GetName().Name)
$window=[Windows.Markup.XamlReader]::Parse($markup);$window.ShowActivated=$false;$window.Width=668;$window.Height=384
$notch=$window.FindName('Notch');$script:albumCoverButton=$window.FindName('AlbumCoverButton');$script:albumCoverButton.Visibility='Visible';$script:albumCoverButton.Margin='202,8,0,0'
$window.FindName('CompactTaskTitle').Text='ChatGPT · Thinking'
$parts=New-OrbitAvatar;[void]$window.FindName('PetCanvas').Children.Add($parts.Root);$renderer=[OrbyAvatarRenderer]::new($parts)
. (Join-Path $PSScriptRoot 'Mini-Orbys.ps1');Initialize-OrbyMinis
$window.Show();$notch.Attach($window);$window.UpdateLayout();$script:albumCoverButton.ApplyTemplate() | Out-Null
$renderer.SetState('idle','');$frame=[Windows.Threading.DispatcherFrame]::new();$paintTimer=[Windows.Threading.DispatcherTimer]::new();$paintTimer.Interval=[timespan]::FromMilliseconds(250);$paintTimer.Add_Tick({$paintTimer.Stop();$frame.Continue=$false});$paintTimer.Start();[Windows.Threading.Dispatcher]::PushFrame($frame)
$image=$script:albumCoverButton.Template.FindName('AlbumCoverImage',$script:albumCoverButton)
$brush=[Windows.Media.LinearGradientBrush]::new([Windows.Media.Colors]::SeaGreen,[Windows.Media.Colors]::MidnightBlue,45)
$drawing=[Windows.Media.GeometryDrawing]::new($brush,$null,[Windows.Media.RectangleGeometry]::new([Windows.Rect]::new(0,0,32,32)))
$image.Source=[Windows.Media.DrawingImage]::new($drawing)
$script:orbySettings=@{Music=$true};$script:orbyShared=@{};$now=[datetime]::UtcNow
$media=[pscustomobject]@{TrackKey='song-a';Position=60;Start=0;Duration=120;Playing=$false;At=$now};$script:orbyShared.SelectedMusic=$media
Update-OrbyArtworkProgress $now
Assert ($script:albumProgress.Progress -eq .5) 'Halfway track did not produce half perimeter'
Assert ($script:albumProgress.Opacity -eq .6 -and -not $script:albumProgress.IsHitTestVisible) 'Opacity or click-through differs from approved design'
foreach($item in @(@(0,16,-3),@(.25,35,16),@(.5,16,35),@(.75,-3,16),@(1,16,-3))){$p=$script:albumProgress.PointAt($item[0]);Assert ([math]::Abs($p.X-$item[1]) -lt .2 -and [math]::Abs($p.Y-$item[2]) -lt .2) 'Progress is not clockwise from top center'}
Update-OrbyArtworkProgress ($now.AddSeconds(10));Assert ($script:albumProgress.Progress -eq .5) 'Pause advanced outline'
$media.Playing=$true;Update-OrbyArtworkProgress ($now.AddSeconds(6));Assert ([math]::Abs($script:albumProgress.Progress-.55) -lt .0001) 'Playback did not interpolate'
$script:pendingMusicSeek=[pscustomobject]@{Id='test';TrackKey='song-a';Position=90;At=$now}
Update-OrbyArtworkProgress ($now.AddSeconds(1));Assert ([math]::Abs($script:albumProgress.Progress-(91.0/120)) -lt .0001) 'Seek did not update immediately'
$media.TrackKey='song-b';$media.Position=2;$media.At=$now;Update-OrbyArtworkProgress $now
Assert ($script:albumProgress.Progress -lt .02 -and -not $script:pendingMusicSeek) 'Old track progress leaked into new track'
$media.Start=30;$media.Position=90;$media.Playing=$false;Update-OrbyArtworkProgress $now;Assert ($script:albumProgress.Progress -eq .5) 'Nonzero timeline start ignored'
$media.Position=999;Update-OrbyArtworkProgress $now;Assert ($script:albumProgress.Progress -eq 1) 'End did not clamp'
$media.Duration=0;Update-OrbyArtworkProgress $now;Assert ($script:albumProgress.Visibility -eq 'Collapsed') 'Unknown duration drew misleading outline'
$media.Start=0;$media.Duration=120;$media.Position=60
foreach($flag in @('expanded','fullscreenHidden','waterPriority')){Set-Variable -Scope Script -Name $flag -Value $true;Update-OrbyArtworkProgress $now;Assert ($script:albumProgress.Visibility -eq 'Collapsed') ('Hidden context still drew outline: '+$flag);Set-Variable -Scope Script -Name $flag -Value $false}
$script:orbySettings.Music=$false;Update-OrbyArtworkProgress $now;Assert ($script:albumProgress.Visibility -eq 'Collapsed') 'Disabled music still drew outline'
$script:orbySettings.Music=$true
if($PreviewDirectory){
 [void][IO.Directory]::CreateDirectory($PreviewDirectory)
 foreach($fraction in @(.25,.5,.75,1)){
  $media.Position=120*$fraction;Update-OrbyArtworkProgress $now;$window.UpdateLayout()
  $root=$window.FindName('Root');$bmp=[Windows.Media.Imaging.RenderTargetBitmap]::new(668,384,96,96,[Windows.Media.PixelFormats]::Pbgra32);$bmp.Render($root)
  $rect=$notch.Clip.Bounds;$offset=$notch.TranslatePoint([Windows.Point]::new(0,0),$root)
  $crop=[Windows.Media.Imaging.CroppedBitmap]::new($bmp,[Windows.Int32Rect]::new([int]($rect.X+$offset.X),0,[int]$rect.Width,58))
  $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($crop));$stream=[IO.File]::Create((Join-Path $PreviewDirectory ('Progress-'+[int]($fraction*100)+'.png')));try{$encoder.Save($stream)}finally{$stream.Dispose()}
 }
}
$script:orbyShared.SelectedMusic=$null;Update-OrbyArtworkProgress $now;Assert ($script:albumProgress.Progress -eq 0) 'Disconnected media retained progress'
$window.Close();$renderer.Dispose();Stop-OrbyMinis
'PASS: rounded perimeter, 60% opacity, clockwise fractions, pause, playback, seek, track change, nonzero start, unknown duration, hidden states and disconnect.'
