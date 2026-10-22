# Neutral Home visuals. Other menus keep their existing resources.
function New-OrbyHomeProviderLogo([string]$Id,[double]$Size){$logo=New-OrbyProviderLogo $Id $Size;if($Id -eq 'gemini'){$brush=[Windows.Media.LinearGradientBrush]::new();$brush.StartPoint='0,1';$brush.EndPoint='1,0';foreach($point in @(@('#4285F4',0),@('#34A8C7',.22),@('#FBBC05',.43),@('#EA4335',.62),@('#A443EF',.82),@('#5279F5',1))){$brush.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.ColorConverter]::ConvertFromString($point[0]),[double]$point[1]))};$brush.Freeze();$logo.Fill=$brush};return $logo}
function New-OrbyHomeSourceLogo([string]$Name){
 [xml]$xml=if($Name -match '(?i)spotify'){@'
<Viewbox xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"><Grid Width="24" Height="24"><Ellipse Fill="#1ED760"/><Path Stroke="#071A10" StrokeThickness="1.7" StrokeStartLineCap="Round" StrokeEndLineCap="Round" Data="M5,8 C9,6 16,6 20,9 M6,12 C10,10.5 15,10.8 18.5,13 M7,16 C11,14.8 14,15 17,17"/></Grid></Viewbox>
'@}else{@'
<Viewbox xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"><Path Fill="#9A9DA7" Data="M9,3 L28,0 L28,22 C28,29 16,31 16,24 C16,20 22,18 25,20 L25,6 L12,8 L12,26 C12,33 0,35 0,28 C0,24 6,22 9,24 Z"/></Viewbox>
'@};return [Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($xml))
}
function New-OrbyHomeProviderTile([string]$Id){
 $button=[Windows.Controls.Button]::new();$button.CommandParameter=$Id;$button.Padding='4,0';$button.HorizontalContentAlignment='Stretch';$button.VerticalContentAlignment='Stretch';$button.Style=$script:homeControls.HomeCanvas.Resources.IconButton
 $grid=[Windows.Controls.Grid]::new();foreach($width in @('48','*')){$c=[Windows.Controls.ColumnDefinition]::new();$c.Width=[Windows.GridLengthConverter]::new().ConvertFromString($width);[void]$grid.ColumnDefinitions.Add($c)}
 $stage=[Windows.Controls.Canvas]::new();$stage.Width=48;$stage.Height=44;$stage.VerticalAlignment='Center'
 $main=New-OrbitAvatar;$renderer=[OrbyAvatarRenderer]::new($main);$avatarHost=[Windows.Controls.Viewbox]::new();$avatarHost.Width=48;$avatarHost.Height=50;$avatarHost.Child=$main.Root;[Windows.Controls.Canvas]::SetLeft($avatarHost,-6);[Windows.Controls.Canvas]::SetTop($avatarHost,-3);[Windows.Controls.Panel]::SetZIndex($avatarHost,10);[void]$stage.Children.Add($avatarHost)
 $palette=if($Id -eq 'gemini'){@('#A764E8','#FA4668','#31C5C8','#F5BC42')}else{@('#FA4668','#A764E8','#31C5C8','#F5BC42')}
 $buddies=@();foreach($color in $palette){$p=New-OrbitAvatar;$p.OrbBody.Background=[Windows.Media.BrushConverter]::new().ConvertFromString($color);$r=[OrbyAvatarRenderer]::new($p);$v=[Windows.Controls.Viewbox]::new();$v.Child=$p.Root;$v.Width=26;$v.Height=27;$v.Visibility='Collapsed';[Windows.Controls.Canvas]::SetLeft($v,(23+$buddies.Count*3));[Windows.Controls.Canvas]::SetTop($v,(-6+$buddies.Count*3));[Windows.Controls.Panel]::SetZIndex($v,(8-$buddies.Count));[void]$stage.Children.Add($v);$buddies+=@{Parts=$p;Renderer=$r;Host=$v}}
 [void]$grid.Children.Add($stage)
 $details=[Windows.Controls.StackPanel]::new();$details.VerticalAlignment='Center';$details.Margin='3,0,0,0';[Windows.Controls.Grid]::SetColumn($details,1)
 $head=[Windows.Controls.StackPanel]::new();$head.Orientation='Horizontal';$logo=New-OrbyHomeProviderLogo $Id 12;$logo.Margin='0,0,4,0';[void]$head.Children.Add($logo);$name=New-OrbyHomeText $script:providerCatalog[$Id].Name 11;$name.FontWeight='SemiBold';[void]$head.Children.Add($name);[void]$details.Children.Add($head)
 $count=New-OrbyHomeText '' 10 '#A6A9B2';$count.Margin='0,2,0,0';[void]$details.Children.Add($count)
 $detail=New-OrbyHomeText '' 10 '#B7BAC3';$detail.Margin='0,2,0,0';[void]$details.Children.Add($detail);[void]$grid.Children.Add($details)
 $line=[Windows.Controls.Border]::new();$line.Width=1;$line.Height=30;$line.HorizontalAlignment='Left';$line.VerticalAlignment='Center';$line.Margin='-4,0,0,0';$line.Background=[Windows.Media.BrushConverter]::new().ConvertFromString('#292B32');[Windows.Controls.Grid]::SetColumnSpan($line,2);[void]$grid.Children.Add($line)
 $button.Content=$grid;$button.Add_Click({param($sender,$e)Select-OrbyCompanion ([string]$sender.CommandParameter)});[void]$script:homeControls.ActiveProviders.Children.Add($button)
 return @{Host=$button;Renderer=$renderer;Parts=$main;Buddies=$buddies;Count=$count;Detail=$detail;Separator=$line}
}
