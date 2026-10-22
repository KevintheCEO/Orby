$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework
. (Join-Path $PSScriptRoot 'Music-Player.ps1')
. (Join-Path $PSScriptRoot 'Reference-Home.ps1')
[xml]$x=Get-Content (Join-Path $PSScriptRoot 'Reference-Home.xaml') -Raw
$ui=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($x));$ui.Width=600
$script:referenceControls=@{}
foreach($m in [regex]::Matches($x.OuterXml,'x:Name="([^"]+)"')){$n=$m.Groups[1].Value;$script:referenceControls[$n]=$ui.FindName($n)}
$m=[pscustomobject]@{App='Spotify';TrackKey='fixture';At=[datetime]::UtcNow;Title='Test';Artist='Test';Playing=$true;Position=20;Start=0;Duration=200;SeekMin=0;SeekMax=200;CanSeek=$true;CanPlay=$true;CanPause=$true;CanNext=$true;CanPrevious=$true;CanShuffle=$true;CanRepeat=$true;Shuffle=$false;Repeat='None';ArtworkKey=$null}
$script:orbyShared=@{SelectedMusic=$m;MusicCommands=[Collections.Concurrent.ConcurrentQueue[object]]::new()};$script:orbySettings=@{Music=$true}
$ui.FindName('RefHomePage').Visibility='Collapsed';$ui.FindName('RefMusicPage').Visibility='Visible'
Initialize-OrbyMusicTab;Update-OrbyMusicTab;
$window=[Windows.Window]::new();$window.Width=650;$window.Height=230;$window.Content=$ui;$window.ShowActivated=$false;$window.Show()
$ui.Measure([Windows.Size]::new(616,180));$ui.Arrange([Windows.Rect]::new(0,0,616,180));$ui.UpdateLayout()
foreach($name in 'RefMusicVolume','RefMusicSeek'){
 $slider=$script:referenceControls[$name];$point=$slider.TransformToAncestor($ui).Transform([Windows.Point]::new($slider.ActualWidth*.75,3));$hit=$ui.InputHitTest($point)
 $found=$false;while($hit){if($hit -eq $slider){$found=$true;break};$hit=[Windows.Media.VisualTreeHelper]::GetParent($hit)}
 Write-Host "$name actual=$($slider.ActualWidth)x$($slider.ActualHeight) point=$point enabled=$($slider.IsEnabled) hit=$($ui.InputHitTest($point))";if(-not $found){throw "Slider hit area fails $name"}
}
foreach($name in 'RefMusicPlay','RefMusicNext','RefMusicPrevious','RefMusicShuffle','RefMusicRepeat'){
 $b=$script:referenceControls[$name];if(-not $b.IsEnabled){throw "Button disabled $name"}
 $b.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
}
if($script:orbyShared.MusicCommands.Count -ne 5){throw 'Playback click routing failed'}
$old=[OrbyOutputVolume]::Get()
try{$script:referenceControls.RefMusicVolume.Value=$(if($old -gt 98){$old-1}else{$old+1});if([math]::Abs([OrbyOutputVolume]::Get()-$script:referenceControls.RefMusicVolume.Value) -gt 1){throw 'Slider volume handler failed'}}finally{[OrbyOutputVolume]::Set($old)}
$window.Close()
'PASS: wide slider hit areas, all five playback click handlers, live output-volume slider handler (original level restored).'


