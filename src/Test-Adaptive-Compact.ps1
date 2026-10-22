param([string]$PreviewDirectory='')
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Xaml
Add-Type -Path @((Join-Path $PSScriptRoot 'Liquid-Surface.cs'),(Join-Path $PSScriptRoot 'Monitor-Layout.cs')) -ReferencedAssemblies WindowsBase,PresentationCore,PresentationFramework,System.Xaml
. (Join-Path $PSScriptRoot 'Orb-Avatar.ps1')
. (Join-Path $PSScriptRoot 'Motion.ps1')
. (Join-Path $PSScriptRoot 'Compact-Task.ps1')
function Assert($ok,$why){if(-not $ok){throw $why}}
function Pump([double]$Seconds=.5){$frame=[Windows.Threading.DispatcherFrame]::new();$timer=[Windows.Threading.DispatcherTimer]::new();$timer.Interval=[timespan]::FromSeconds($Seconds);$timer.Add_Tick({$timer.Stop();$frame.Continue=$false}.GetNewClosure());$timer.Start();[Windows.Threading.Dispatcher]::PushFrame($frame)}
function Status($Id,$State,$Detail){[pscustomobject]@{Id=$Id;Name=$(if($Id -eq 'chatgpt'){'ChatGPT'}else{'Claude'});Title=$(if($Id -eq 'chatgpt'){'ChatGPT'}else{'Claude'});State=$State;Detail=$Detail;Sleeping=$false}}
$script:compactProviderOrder=@()
$idle=Get-OrbyCompactModel @((Status claude unknown 'unavailable'),(Status chatgpt idle 'ready'))
Assert ($idle.Text -eq '' -and -not $idle.Split) 'Idle or unavailable provider text leaked'
$solo=Get-OrbyCompactModel @((Status claude idle 'ready'),(Status chatgpt working 'Reviewing your code')) 1100 $true
Assert ($solo.Text -eq 'ChatGPT · Reviewing your code' -and -not $solo.Split) 'Idle second provider included'
$dual=Get-OrbyCompactModel @((Status claude working 'Writing a reply'),(Status chatgpt working 'Reviewing code')) 1100 $true
Assert ($dual.Split -and $dual.Items[0].Id -eq 'chatgpt') 'First-active ordering changed'
$remaining=Get-OrbyCompactModel @((Status claude working 'Writing a reply'),(Status chatgpt idle 'ready'))
Assert ($remaining.Items[0].Id -eq 'claude' -and -not $remaining.Split) 'Finished task retained'
$long=Get-OrbyCompactModel @((Status claude working 'Checking your project for connection issues')) 1100 $true
Assert ($long.Width -gt 360 -and $long.Text -match 'connection issues') 'Long text did not widen notch'
$huge=Get-OrbyCompactModel @((Status claude working ('A very long task description '*100))) 640 $true
Assert ($huge.Width -le 640 -and $huge.Text -eq 'Claude · Working' -and $huge.Tooltip.Length -gt 1000) 'Width cap or readable summary lost'
$source=Get-Content (Join-Path $PSScriptRoot 'Orby.ps1') -Raw
$markup=[regex]::Match($source,'(?s)\$xaml = @''\r?\n(.*?)\r?\n''@').Groups[1].Value
$markup=$markup.Replace('LIQUID_ASSEMBLY',[OrbyLiquidSurface].Assembly.GetName().Name)
$window=[Windows.Markup.XamlReader]::Parse($markup);$window.ShowActivated=$false;$window.Width=640;$window.Height=384
$notch=$window.FindName('Notch');$expandedArea=$window.FindName('ExpandedArea')
$script:orbParts=New-OrbitAvatar;[void]$window.FindName('PetCanvas').Children.Add($script:orbParts.Root)
$script:avatarRenderer=[OrbyAvatarRenderer]::new($script:orbParts)
$script:orbySettings=@{ReducedMotion=$false;EyeEffects=$false};$script:expanded=$false
$script:albumCoverButton=$window.FindName('AlbumCoverButton');$script:albumCoverButton.Visibility='Collapsed'
. (Join-Path $PSScriptRoot 'Mini-Orbys.ps1');Initialize-OrbyMinis
function Position-Orbit {[OrbyMonitorLayout]::Position($window)}
$script:albumMove=[Windows.Media.TranslateTransform]::new();$script:albumScale=[Windows.Media.ScaleTransform]::new(1,1,16,16);$group=[Windows.Media.TransformGroup]::new();$group.Children.Add($script:albumScale);$group.Children.Add($script:albumMove);$script:albumCoverButton.RenderTransform=$group
$artSource=Get-Content (Join-Path $PSScriptRoot 'Media-Art.ps1') -Raw
. ([scriptblock]::Create($artSource.Substring($artSource.IndexOf('function Set-OrbyAlbumPlacement'),$artSource.IndexOf('$script:artTimer=')-$artSource.IndexOf('function Set-OrbyAlbumPlacement'))))
$window.Show();$notch.Attach($window);Initialize-OrbyAdaptiveCompact
$script:albumCoverButton.ApplyTemplate() | Out-Null
$artImage=$script:albumCoverButton.Template.FindName('AlbumCoverImage',$script:albumCoverButton)
$drawing=[Windows.Media.GeometryDrawing]::new([Windows.Media.Brushes]::SlateGray,$null,[Windows.Media.RectangleGeometry]::new([Windows.Rect]::new(0,0,32,32)))
$artImage.Source=[Windows.Media.DrawingImage]::new($drawing);$script:albumCoverButton.Visibility='Visible'
$captures=@()
function Assert-ArtworkGap {
 $root=$window.FindName('Root')
 $artRight=$script:albumCoverButton.TranslatePoint([Windows.Point]::new(32,16),$root).X
 $minisLeft=$script:compactMinisHost.TranslatePoint([Windows.Point]::new(0,0),$root).X
 Assert ([math]::Abs(($minisLeft-$artRight)-9) -lt .5) 'Artwork-to-companions gap does not reserve 5 pixels beyond the new outline'
}
function Capture($Name){
 Pump .6;$window.UpdateLayout()
 $rect=$notch.Clip.Bounds;$root=$window.FindName('Root');$offset=$notch.TranslatePoint([Windows.Point]::new(0,0),$root);$bmp=[Windows.Media.Imaging.RenderTargetBitmap]::new([int]$window.Width,374,96,96,[Windows.Media.PixelFormats]::Pbgra32);$bmp.Render($root)
 $crop=[Windows.Media.Imaging.CroppedBitmap]::new($bmp,[Windows.Int32Rect]::new([int][math]::Round($rect.X+$offset.X),0,[int][math]::Round($rect.Width),58));$crop.Freeze()
 $script:captures+=,[pscustomobject]@{Name=$Name;Image=$crop}
 if($PreviewDirectory){[void][IO.Directory]::CreateDirectory($PreviewDirectory);$e=[Windows.Media.Imaging.PngBitmapEncoder]::new();$e.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($crop));$f=[IO.File]::Create((Join-Path $PreviewDirectory ($Name+'.png')));try{$e.Save($f)}finally{$f.Dispose()}}
}
$script:multiProviderStatuses=@((Status claude unknown 'unavailable'),(Status chatgpt idle 'ready'));Update-OrbyCompactTask
Assert ($window.FindName('CompactTaskTitle').Text -eq '') 'Actual idle label not blank'
Capture '01-idle'
Assert-ArtworkGap
$script:multiProviderStatuses=@((Status chatgpt working 'Reviewing your code'),(Status claude idle 'ready'));Update-OrbyCompactTask
Capture '02-one-active'
Assert-ArtworkGap
$script:multiProviderStatuses=@((Status claude working 'Checking your project for connection issues'),(Status chatgpt idle 'ready'));Update-OrbyCompactTask
Capture '03-long-task'
Assert-ArtworkGap
$script:multiProviderStatuses=@((Status claude idle 'ready'),(Status chatgpt working 'Reviewing code'));Update-OrbyCompactTask
$script:multiProviderStatuses=@((Status claude working 'Writing a reply'),(Status chatgpt working 'Reviewing code'));Update-OrbyCompactTask
Assert ($script:compactSecond.View.Visibility -eq 'Visible' -and $script:compactMinisHost.Visibility -eq 'Collapsed') 'Dual avatars/hidden companions missing'
Assert ($script:compactSecond.Arrival.HasAnimatedProperties) 'Second Orby slide-in missing'
Assert ($script:compactSecond.Renderer.ActiveId -eq 'working_normal') 'Second Orby not animated'
Assert ($script:orbParts.AccentId -eq 'chatgpt' -and $script:compactSecond.Parts.AccentId -eq 'claude') 'Provider accents crossed between dual slots'
Capture '04-both-active'
Assert ([math]::Abs($script:compactSecond.Arrival.X) -lt .1) 'Slide-in did not settle'
Assert ($window.FindName('CompactTaskTitle').ActualWidth -ge (Get-OrbyCompactTextWidth $window.FindName('CompactTaskTitle').Text)-2) 'First text clipped'
Assert ($script:compactSecond.Title.ActualWidth -ge (Get-OrbyCompactTextWidth $script:compactSecond.Title.Text)-2) 'Second text clipped'
$artCenter=$script:albumCoverButton.TranslatePoint([Windows.Point]::new(16,16),$window.FindName('Root'));$edge=$notch.Clip.Bounds.Right-[OrbyLiquidSurface]::Shoulder+$notch.TranslatePoint([Windows.Point]::new(0,0),$window.FindName('Root')).X
Assert ([math]::Abs(($edge-$artCenter.X)-28) -lt 2) 'Cover art did not stay at right edge of dual layout'
$script:expanded=$true;Update-OrbyCompactTask
Assert ($script:compactSecond.Renderer.Suspended) 'Hidden secondary renderer still running'
$notch.Morph=1;Pump .1
Assert ([math]::Abs($notch.Clip.Bounds.Width-(620+2*[OrbyLiquidSurface]::Shoulder)) -lt 1 -and $expandedArea.Width -eq 596) 'Expanded menu resized with compact notch'
$notch.Morph=0;$script:expanded=$false;$script:orbySettings.ReducedMotion=$true
$script:multiProviderStatuses=@((Status claude working 'Writing a reply'),(Status chatgpt idle 'ready'));Update-OrbyCompactTask
Assert ($script:compactSecond.View.Visibility -eq 'Collapsed' -and $script:compactMinisHost.Visibility -eq 'Visible') 'Solo layout did not return'
Assert ($script:orbParts.AccentId -eq 'claude') 'Remaining provider did not carry its accent to the main Orby'
$script:multiProviderStatuses=@((Status claude working 'Writing a reply'),(Status chatgpt working 'Reviewing code'));Update-OrbyCompactTask
Assert (-not $script:compactSecond.Arrival.HasAnimatedProperties -and -not $script:compactSecond.View.HasAnimatedProperties) 'Reduced motion did not disable arrival'
if($PreviewDirectory){
 $board=[Windows.Controls.StackPanel]::new();$board.Background=[Windows.Media.BrushConverter]::new().ConvertFromString('#101216');$board.Width=1120
 foreach($c in $captures){$title=[Windows.Controls.TextBlock]::new();$title.Text=$c.Name.Replace('-',' ');$title.FontFamily='Segoe UI';$title.FontSize=17;$title.FontWeight='Bold';$title.Foreground=[Windows.Media.Brushes]::White;$title.Margin='28,20,0,12';[void]$board.Children.Add($title);$image=[Windows.Controls.Image]::new();$image.Source=$c.Image;$image.Width=$c.Image.PixelWidth;$image.Height=58;$image.Margin='0,0,0,20';[void]$board.Children.Add($image)}
 $board.Measure([Windows.Size]::new(1120,800));$board.Arrange([Windows.Rect]::new(0,0,1120,$board.DesiredSize.Height));$board.UpdateLayout();$bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new(1120,[int]$board.ActualHeight,96,96,[Windows.Media.PixelFormats]::Pbgra32);$bitmap.Render($board);$encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap));$file=[IO.File]::Create((Join-Path $PreviewDirectory 'Actual-layouts.png'));try{$encoder.Save($file)}finally{$file.Dispose()}
}
$window.Close();$script:avatarRenderer.Dispose();Stop-OrbyMinis
Write-Output 'PASS: blank idle, active-only text, stable order, adaptive width, summary cap, dual animated avatars, slide-in, restored minis, independent expanded size and reduced motion.'
