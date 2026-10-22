param([string]$OutputDirectory='')
$ErrorActionPreference='Stop'
# Reuse the actual-window adaptive fixture and retain its open window for mode tests.
$fixture=Get-Content (Join-Path $PSScriptRoot 'Test-Adaptive-Compact.ps1') -Raw
$fixture=$fixture.Replace('$window.Close();$script:avatarRenderer.Dispose();Stop-OrbyMinis','')
$fixture=$fixture.Replace('$PSScriptRoot',("'"+$PSScriptRoot.Replace("'","''")+"'"))
. ([scriptblock]::Create($fixture))
$script:orbySettings.NotchSize='mini';$script:orbySettings.ReducedMotion=$true
Update-OrbyCompactTask;Pump .2
$miniModel=Get-OrbyCompactModel $script:multiProviderStatuses 1100 $true
$miniLayout=Get-OrbyMiniModel $miniModel 1100
Assert ($notch.MiniMode -and [math]::Abs($notch.Clip.Bounds.Height-20) -lt .1 -and [math]::Abs($notch.Clip.Bounds.Width-($miniLayout.Width+12)) -lt .1) 'Mini adaptive dimensions do not match its actual content'
Assert ($script:miniNotchSecond.View.Visibility -eq 'Visible' -and $script:miniNotchLabel.Text -eq $miniModel.Items[0].Full -and $script:miniNotchSecond.Label.Text -eq $miniModel.Items[1].Full) 'Mini did not retain both task descriptions'
Assert (-not $script:miniNotchSecond.Renderer.Suspended) 'Mini second avatar is not running'
Assert ($script:miniNotchLabel.ActualWidth -ge (Get-OrbyCompactTextWidth $script:miniNotchLabel.Text 9)-1) ('Mini first task clipped: '+$script:miniNotchLabel.ActualWidth+' measured '+(Get-OrbyCompactTextWidth $script:miniNotchLabel.Text 9)+' layout '+$miniLayout.Width+' right '+$miniLayout.SecondWidth)
Assert ($script:miniNotchSecond.Label.ActualWidth -ge (Get-OrbyCompactTextWidth $script:miniNotchSecond.Label.Text 9)-1) 'Mini second task clipped'
Assert ($script:miniNotchView.Visibility -eq 'Visible' -and $window.FindName('CompactHeader').Opacity -eq 0) 'Default and mini headers overlapped'
Assert ($script:miniNotchRenderer.SyncWith -eq $script:avatarRenderer -and -not $script:miniNotchRenderer.Suspended) 'Mini avatar is not synchronized'
$root=$window.FindName('Root');$point=$script:albumCoverButton.TranslatePoint([Windows.Point]::new(16,16),$root)
Assert ([math]::Abs($point.Y-10) -lt .1 -and [math]::Abs($point.X-($window.Width/2+$miniLayout.Width/2-14)) -lt .1) 'Mini artwork did not follow its adaptive right edge'
$hit=$root.InputHitTest($point);$buttonHit=$false
while($hit){if($hit -eq $script:albumCoverButton){$buttonHit=$true;break};$hit=[Windows.Media.VisualTreeHelper]::GetParent($hit)}
Assert $buttonHit 'Mini header blocks artwork clicks'
if($OutputDirectory){[void][IO.Directory]::CreateDirectory($OutputDirectory);$bmp=[Windows.Media.Imaging.RenderTargetBitmap]::new([int]$window.Width,58,96,96,[Windows.Media.PixelFormats]::Pbgra32);$bmp.Render($root);$enc=[Windows.Media.Imaging.PngBitmapEncoder]::new();$enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bmp));$stream=[IO.File]::Create((Join-Path $OutputDirectory 'Mini-actual.png'));try{$enc.Save($stream)}finally{$stream.Dispose()}}
$script:expanded=$true;$notch.Morph=1;Update-OrbyCompactTask;Pump .1
Assert ([math]::Abs($notch.Clip.Bounds.Width-656) -lt .1 -and $expandedArea.Width -eq 596 -and $script:miniNotchView.Visibility -eq 'Collapsed') 'Mini setting changed expanded menu dimensions'
Assert $script:miniNotchRenderer.Suspended 'Hidden mini renderer kept running'
$script:expanded=$false;$notch.Morph=0;Update-OrbyCompactTask
$script:fullscreenHidden=$true;Update-OrbyCompactTask;Assert $script:miniNotchRenderer.Suspended 'Full-screen mini renderer not suspended'
$script:fullscreenHidden=$false;Update-OrbyCompactTask;Assert (-not $script:miniNotchRenderer.Suspended -and $notch.MiniMode) 'Mini did not return after fullscreen'
$script:waterPriority=$true;Update-OrbyCompactTask;Assert (-not $notch.MiniMode) 'Priority reminder is squeezed into tiny UI'
$script:waterPriority=$false;Update-OrbyCompactTask;Assert $notch.MiniMode 'Mini preference was lost after priority reminder'
$script:hoverExitTimer=[Windows.Threading.DispatcherTimer]::new();function Write-OrbitLog($message){}
. (Join-Path $PSScriptRoot 'Fullscreen-Guard.ps1');$script:fullscreenTimer.Stop()
Set-OrbyFullscreenHidden $true;Set-OrbyFullscreenHidden $false;Pump .1
Assert ($notch.MiniMode -and $notch.Clip.Bounds.Height -eq 20 -and $script:miniNotchView.Visibility -eq 'Visible' -and $window.FindName('CompactHeader').Opacity -eq 0) 'Full-screen restore reverted mini to normal header'
foreach($i in 1..20){$script:orbySettings.NotchSize='default';Update-OrbyCompactTask;$script:orbySettings.NotchSize='mini';Update-OrbyCompactTask}
Assert ($root.Children.Contains($script:miniNotchView)) 'Mode switching detached mini header'
$script:orbySettings.NotchSize='default';Update-OrbyCompactTask;Pump .2
Assert (-not $notch.MiniMode -and $script:miniNotchView.Visibility -eq 'Collapsed' -and $window.FindName('CompactHeader').Opacity -eq 1 -and [math]::Abs($notch.Clip.Bounds.Height-58) -lt .1) 'Default size did not restore'
[xml]$settings=Get-Content (Join-Path $PSScriptRoot 'Settings.xaml') -Raw;$ui=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($settings))
Assert ($ui.FindName('DefaultNotchSize') -and $ui.FindName('MiniNotchSize')) 'Size choices missing from settings'
$json=$script:orbySettings | ConvertTo-Json;$restored=$json | ConvertFrom-Json;Assert ($restored.NotchSize -eq 'default') 'Default choice did not round-trip'
$script:orbySettings.NotchSize='mini';$restored=($script:orbySettings | ConvertTo-Json | ConvertFrom-Json);Assert ($restored.NotchSize -eq 'mini') 'Mini choice did not round-trip'
$window.Close();$script:avatarRenderer.Dispose();Stop-OrbyMinis
'PASS: mini geometry, synchronized pet, artwork input, expanded size, fullscreen, reminder priority, repeated switching, settings choices and persistence.'
