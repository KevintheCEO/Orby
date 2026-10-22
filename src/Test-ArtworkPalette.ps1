param([string]$PreviewDirectory='')
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework
Add-Type -Path @((Join-Path $PSScriptRoot 'Artwork-Palette.cs'),(Join-Path $PSScriptRoot 'Liquid-Surface.cs')) -ReferencedAssemblies WindowsBase,PresentationCore,PresentationFramework,System.Xaml
. (Join-Path $PSScriptRoot 'Mini-Notch.ps1')
function Assert($ok,$why){if(-not $ok){throw $why}}
function Make-Art($kind){
 $bytes=New-Object byte[] (32*32*4)
 foreach($y in 0..31){foreach($x in 0..31){
  $color=switch($kind){
   blueblack {if($y -lt 12){@(20,65,210,255)}else{@(0,0,0,255)}}
   bluewhite {if($y -lt 5){@(15,50,220,255)}else{@(245,245,245,255)}}
   pink {@(235,25,155,255)}
   red {@(220,20,25,255)}
   white {@(250,250,250,255)}
   gray {@(90,90,90,255)}
   black {@(0,0,0,255)}
   transparent {@(20,60,210,0)}
   pinprick {if($x -eq 0 -and $y -eq 0){@(10,50,220,255)}else{@(0,0,0,255)}}
   mixed {if($y -lt 24){@(20,65,210,255)}else{@(220,20,25,255)}}
  }
  $i=($y*32+$x)*4;$bytes[$i]=$color[2];$bytes[$i+1]=$color[1];$bytes[$i+2]=$color[0];$bytes[$i+3]=$color[3]
 }}
 $bitmap=[Windows.Media.Imaging.BitmapSource]::Create(32,32,96,96,[Windows.Media.PixelFormats]::Bgra32,$null,$bytes,128);$bitmap.Freeze();return $bitmap
}
$samples=@{}
foreach($kind in @('blueblack','bluewhite','pink','red','white','gray','black','transparent','pinprick','mixed')){$samples[$kind]=[OrbyArtworkPalette]::Sample((Make-Art $kind))}
Assert ($samples.blueblack.B -gt 190 -and $samples.blueblack.R -lt 30 -and $samples.blueblack.G -lt 80 -and $samples.blueblack.A -gt 0) 'Blue/black art washed out or disabled'
Assert ($samples.bluewhite.B -gt 190 -and $samples.bluewhite.R -lt 35) 'White highlights polluted blue accent'
Assert ($samples.pink.R -gt 210 -and $samples.pink.B -gt 130 -and $samples.pink.G -lt 45) 'Pink art no longer produces pink'
Assert ($samples.red.R -gt 200 -and $samples.red.G -lt 40) 'Hue wrap lost red'
Assert ($samples.mixed.B -gt 180 -and $samples.mixed.R -lt 40) 'Conflicting hues averaged into gray'
foreach($kind in @('white','gray','black','transparent','pinprick')){Assert ($samples[$kind].A -eq 0) ('Neutral or insufficient color gained fake glow: '+$kind)}
Assert (([OrbyArtworkPalette]::Sample($null)).A -eq 0) 'Missing cover gained fallback tint'
$surface=[OrbyLiquidSurface]::new();$surface.MiniMode=$true;$surface.Morph=0
$surface.SetArtworkAccent($samples.blueblack,$true,$false);Assert $surface.ArtworkAccentVisible 'Blue accent disabled'
$surface.SetArtworkAccent($samples.white,$true,$true);Assert (-not $surface.ArtworkAccentVisible) 'No-color art left old glow enabled'
$single=[pscustomobject]@{Items=@([pscustomobject]@{Id='chatgpt';State='working';Detail='Searching / reading the web'});Text=('ChatGPT · '+('Long title '*20));HasArtwork=$true}
Assert ((Get-OrbyMiniLabel $single) -eq 'ChatGPT · Searching') 'Mini label is not concise'
$single.Items[0].State='attention';Assert ((Get-OrbyMiniLabel $single) -eq 'ChatGPT · Needs you') 'Mini permission state lost'
Assert ((Get-OrbyMiniLabel $null) -eq '') 'Idle mini label must stay blank'
# Exercise the closed-artwork loader too, including recovery from an invalid image.
$tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'Media-Art.ps1'),[ref]$tokens,[ref]$errors)
foreach($name in @('Get-OrbyCompactArtworkAccent','Convert-OrbyAlbumBitmap','Update-OrbyAlbumArt')){$node=$ast.Find({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name},$true);. ([scriptblock]::Create($node.Extent.Text))}
function Write-OrbitLog($message){}
$script:albumCoverButton=[Windows.Markup.XamlReader]::Parse('<Button xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Width="32" Height="32"><Button.Template><ControlTemplate TargetType="Button"><Image x:Name="AlbumCoverImage"/></ControlTemplate></Button.Template></Button>')
$script:albumArtKey='';$script:compactArtworkAccent=[Windows.Media.Colors]::Transparent;$script:orbySettings=@{Music=$true;ReducedMotion=$true};$notch=$surface
$media=[pscustomobject]@{ArtworkKey='same-key';ArtworkBytes=[byte[]]@(0,1,2);Title='Sample';Artist='Fixture';Playing=$false};$script:orbyShared=@{SelectedMusic=$media}
Update-OrbyAlbumArt;Assert ($script:albumCoverButton.Visibility -eq 'Collapsed' -and $script:albumArtKey -eq '') 'Failed decode cached invalid artwork'
Assert ($script:albumRetryAt -gt [datetime]::UtcNow) 'Failed decode has no retry backoff'
function Encode-Art($bitmap){$encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap));$memory=[IO.MemoryStream]::new();try{$encoder.Save($memory);return ,$memory.ToArray()}finally{$memory.Dispose()}}
$media.ArtworkBytes=Encode-Art (Make-Art 'blueblack');$script:albumRetryAt=[datetime]::UtcNow.AddSeconds(-1);Update-OrbyAlbumArt
Assert ($script:albumArtKey -eq 'same-key' -and $script:albumCoverButton.Visibility -eq 'Visible' -and $script:compactArtworkAccent.B -gt 190) 'Corrected cover did not recover with matching key'
$media.ArtworkKey='white';$media.ArtworkBytes=Encode-Art (Make-Art 'white');Update-OrbyAlbumArt
Assert (-not $notch.ArtworkAccentVisible) 'Neutral next track kept previous blue glow'
if($PreviewDirectory){
 [void][IO.Directory]::CreateDirectory($PreviewDirectory)
 $board=[Windows.Controls.StackPanel]::new();$board.Width=700;$board.Background=[Windows.Media.BrushConverter]::new().ConvertFromString('#15171C')
 foreach($kind in @('blueblack','pink','white','black')){
  $label=[Windows.Controls.TextBlock]::new();$label.Text=$kind+' → '+$(if($samples[$kind].A){$samples[$kind].ToString()}else{'No glow'});$label.Foreground=[Windows.Media.Brushes]::White;$label.FontSize=16;$label.Margin='24,18,0,8';[void]$board.Children.Add($label)
  $row=[Windows.Controls.Grid]::new();$row.Width=668;$row.Height=32
  $s=[OrbyLiquidSurface]::new();$s.MiniMode=$true;$s.Morph=0;$s.HorizontalAlignment='Center';$s.VerticalAlignment='Top';$s.SetArtworkAccent($samples[$kind],$true,$false);[void]$row.Children.Add($s)
  $image=[Windows.Controls.Image]::new();$image.Source=Make-Art $kind;$image.Width=12;$image.Height=12;$image.HorizontalAlignment='Center';$image.VerticalAlignment='Top';$image.Margin='172,4,0,0';[void]$row.Children.Add($image)
  [void]$board.Children.Add($row)
 }
 $board.Measure([Windows.Size]::new(700,800));$board.Arrange([Windows.Rect]::new(0,0,700,$board.DesiredSize.Height));$board.UpdateLayout()
 $preview=[Windows.Window]::new();$preview.ShowActivated=$false;$preview.WindowStyle='None';$preview.Width=700;$preview.Height=$board.DesiredSize.Height;$preview.Content=$board;$preview.Show();$preview.UpdateLayout()
 $frame=[Windows.Threading.DispatcherFrame]::new();$timer=[Windows.Threading.DispatcherTimer]::new();$timer.Interval=[timespan]::FromSeconds(.85);$timer.Add_Tick({$timer.Stop();$frame.Continue=$false});$timer.Start();[Windows.Threading.Dispatcher]::PushFrame($frame)
 $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new(700,[int]$board.ActualHeight,96,96,[Windows.Media.PixelFormats]::Pbgra32);$bitmap.Render($board);$encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap));$file=[IO.File]::Create((Join-Path $PreviewDirectory 'Actual-closed-glow-check.png'));try{$encoder.Save($file)}finally{$file.Dispose();$preview.Close()}
}
'PASS: hue selection, neutral/no-art glow suppression, loader recovery, next-track reset and concise mini labels.'
