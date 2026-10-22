function New-OrbitAvatar {
    Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
    [xml]$xml=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'Avatar.xaml') -Raw
    $root=[Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader $xml))
    $parts=@{Root=$root}
    foreach($name in @('OrbBody','OrbFace','OrbEyeL','OrbEyeR','OrbPattern','OrbWhiteDot','OrbBlackDot','OrbLed','OrbCheck','OrbAsk')) {$parts[$name]=$root.FindName($name)}
    return $parts
}

function Set-OrbGeometry {
    param($Path,[string]$Data)
    $Path.Data=[Windows.Media.Geometry]::Parse($Data)
}

function Update-OrbitAvatar {
    param($Parts,[string]$State,[double]$Seconds,[string]$Action='Thinking')
    $body=$Parts.OrbBody;$face=$Parts.OrbFace
    $left=$Parts.OrbEyeL;$right=$Parts.OrbEyeR;$pattern=$Parts.OrbPattern
    $left.Visibility='Visible';$right.Visibility='Visible';$pattern.Visibility='Collapsed'
    $Parts.OrbWhiteDot.Visibility='Collapsed';$Parts.OrbBlackDot.Visibility='Collapsed'
    $Parts.OrbLed.Opacity=0;$Parts.OrbCheck.Opacity=0;$Parts.OrbAsk.Opacity=0
    $left.Fill=[Windows.Media.Brushes]::Black;$right.Fill=[Windows.Media.Brushes]::Black
    $angle=0.0;$bob=0.0;$scale=1.0
    $blink=($Seconds%4.6) -gt 4.42
    $eye1='M 11,15 A 2.4,3.5 0 1 1 11,22 A 2.4,3.5 0 1 1 11,15 Z'
    $eye2='M 24,15 A 2.4,3.5 0 1 1 24,22 A 2.4,3.5 0 1 1 24,15 Z'
    switch($State){
        music {
            $bob=[Math]::Sin($Seconds*5)*1.7
            $angle=[Math]::Sin($Seconds*3.0)*13
            $scale=1+[Math]::Sin($Seconds*5)*0.035
            $Parts.OrbLed.Fill=[Windows.Media.Brushes]::MediumAquamarine;$Parts.OrbLed.Opacity=1
        }
        working {
            $Parts.OrbLed.Fill=[Windows.Media.Brushes]::LimeGreen;$Parts.OrbLed.Opacity=1
            $bob=[Math]::Sin($Seconds*2.0)*0.8
            $angle=[Math]::Sin($Seconds*1.4)*15
            if($Action -match 'command'){
                $left.Visibility='Collapsed';$right.Visibility='Collapsed';$pattern.Visibility='Visible'
                Set-OrbGeometry $pattern 'M 9,13 A 2,4.5 0 1 1 9,22 A 2,4.5 0 1 1 9,13 Z M 18,11 A 2.5,6.5 0 1 1 18,24 A 2.5,6.5 0 1 1 18,11 Z M 27,13 A 2,4.5 0 1 1 27,22 A 2,4.5 0 1 1 27,13 Z'
                $scale=1+[Math]::Sin($Seconds*4)*0.035
            }elseif($Action -match 'edit|creat'){
                $eye1='M 8,18 Q 11,16 15,16 L 14,20 Q 10,22 8,18 Z'
                $eye2='M 22,16 Q 26,16 29,18 Q 27,22 23,20 Z'
            }elseif($Action -match 'search|read|inspect'){
                $angle=20*[Math]::Sin($Seconds*1.8)
                $eye1='M 12,12 A 2.3,4.5 0 1 1 12,21 A 2.3,4.5 0 1 1 12,12 Z'
                $eye2='M 23,12 A 2.3,4.5 0 1 1 23,21 A 2.3,4.5 0 1 1 23,12 Z'
            }else{
                $left.Visibility='Collapsed';$right.Visibility='Collapsed';$pattern.Visibility='Visible'
                $phase=[int][Math]::Floor($Seconds/3)%2
                if($phase -eq 0){
                    Set-OrbGeometry $pattern 'M 18,5 A 5.4,5.4 0 1 1 18,15.8 A 5.4,5.4 0 1 1 18,5 Z M 12,17 A 5.4,5.4 0 1 1 12,27.8 A 5.4,5.4 0 1 1 12,17 Z M 24,17 A 5.4,5.4 0 1 1 24,27.8 A 5.4,5.4 0 1 1 24,17 Z'
                    $angle=$Seconds*55
                }else{
                    Set-OrbGeometry $pattern 'M 18,0 A 18,18 0 0 1 18,36 A 9,9 0 0 1 18,18 A 9,9 0 0 0 18,0 Z'
                    $Parts.OrbWhiteDot.Visibility='Visible';$Parts.OrbBlackDot.Visibility='Visible'
                    $angle=$Seconds*38
                }
            }
        }
        attention {
            $Parts.OrbAsk.Opacity=0.85+0.15*[Math]::Sin($Seconds*3)
            $Parts.OrbLed.Fill=[Windows.Media.Brushes]::Orange;$Parts.OrbLed.Opacity=1
            $eye1='M 11,12 A 2.8,5 0 1 1 11,22 A 2.8,5 0 1 1 11,12 Z'
            $eye2='M 24,12 A 2.8,5 0 1 1 24,22 A 2.8,5 0 1 1 24,12 Z'
            $angle=[Math]::Sin($Seconds*1.3)*7
        }
        success {
            $Parts.OrbCheck.Opacity=1;$bob=-[Math]::Abs([Math]::Sin($Seconds*3))*1.2
            $eye1='M 7,16 Q 11,21 15,16 Q 14,23 11,23 Q 8,23 7,16 Z'
            $eye2='M 21,16 Q 25,21 29,16 Q 28,23 25,23 Q 22,23 21,16 Z'
        }
        error {
            $Parts.OrbLed.Fill=[Windows.Media.Brushes]::Red;$Parts.OrbLed.Opacity=1
            $eye1='M 8,14 L 10,14 L 15,21 L 13,22 Z M 13,14 L 15,14 L 10,22 L 8,21 Z'
            $eye2='M 21,14 L 23,14 L 28,21 L 26,22 Z M 26,14 L 28,14 L 23,22 L 21,21 Z'
            $angle=[Math]::Sin($Seconds*12)*4
        }
        stopped {$blink=$true;$angle=-8}
        default {$bob=[Math]::Sin($Seconds*1.2)*0.35;$angle=[Math]::Sin($Seconds*0.7)*4}
    }
    if($blink -and $State -notin @('error','success','attention')){
        $eye1='M 8,18 Q 11,17 15,18 L 15,19 Q 11,20 8,19 Z'
        $eye2='M 21,18 Q 25,17 28,18 L 28,19 Q 25,20 21,19 Z'
    }
    Set-OrbGeometry $left $eye1;Set-OrbGeometry $right $eye2
    $face.RenderTransform=New-Object Windows.Media.RotateTransform $angle
    $transforms=New-Object Windows.Media.TransformGroup
    $transforms.Children.Add((New-Object Windows.Media.ScaleTransform $scale,$scale))
    $transforms.Children.Add((New-Object Windows.Media.TranslateTransform 0,$bob))
    $body.RenderTransform=$transforms
}
