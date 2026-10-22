param(
    [switch]$DebugMode,
    [string]$DataDirectory = '',
    [string]$PreviewDirectory = '',
    [switch]$PerformanceCheck
)

$ErrorActionPreference = 'Stop'
if(Test-Path -LiteralPath (Join-Path $PSScriptRoot 'SECURITY-REVIEW-PENDING.txt')){
    Write-Error 'Orby is on hold after a Defender detection. Leave the executable quarantined and obtain a security review before running this build.'
    exit 1
}
Add-Type -Path (Join-Path $PSScriptRoot 'Dpi-Boot.cs')
[OrbyDpiBoot]::Enable()

$logDir = Join-Path $env:LOCALAPPDATA 'Orby'
if ($DataDirectory) { $logDir = $DataDirectory }
$logFile = Join-Path $logDir 'orby.log'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

function Write-OrbitLog {
    param([string]$Message)
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff')  $Message"
    Add-Content -Path $logFile -Value $line -Encoding UTF8
    if ($DebugMode) { Write-Host $line }
}

function Fail-Orbit {
    param([string]$Message)
    Write-OrbitLog "FATAL: $Message"
    if(Test-Path function:Request-OrbyQuit){Request-OrbyQuit}
    if($PerformanceCheck){exit 1}
    try {
        Add-Type -AssemblyName PresentationFramework -ErrorAction SilentlyContinue
        [System.Windows.MessageBox]::Show(
            "$Message`n`nLog:`n$logFile",
            'Orbit Notch - Error',
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
    } catch {}
    exit 1
}

Write-OrbitLog '===== Orby 10.40 desktop companion starting ====='
Write-OrbitLog "PowerShell $($PSVersionTable.PSVersion) / $([Environment]::OSVersion.VersionString)"

try {
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase
    Add-Type -AssemblyName UIAutomationClient
    Add-Type -AssemblyName UIAutomationTypes
} catch {
    Fail-Orbit "Windows UI components could not load: $($_.Exception.Message)"
}

try {
Add-Type @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class OrbitNative {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")]
    public static extern bool EnumChildWindows(IntPtr hWndParent, EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    public static IntPtr[] GetChildWindows(IntPtr parent) {
        var result = new List<IntPtr>();
        EnumChildWindows(parent, delegate (IntPtr hWnd, IntPtr lParam) {
            result.Add(hWnd);
            return true;
        }, IntPtr.Zero);
        return result.ToArray();
    }

    public static string WindowClass(IntPtr hWnd) {
        var b = new StringBuilder(512);
        GetClassName(hWnd, b, b.Capacity);
        return b.ToString();
    }

    public static string WindowText(IntPtr hWnd) {
        var b = new StringBuilder(1024);
        GetWindowText(hWnd, b, b.Capacity);
        return b.ToString();
    }
}
'@
} catch {
    Write-OrbitLog "Native helper warning: $($_.Exception.Message)"
}

Add-Type -Path @((Join-Path $PSScriptRoot 'Liquid-Surface.cs'),(Join-Path $PSScriptRoot 'Monitor-Layout.cs')) -ReferencedAssemblies @('WindowsBase','PresentationCore','PresentationFramework','System.Xaml')
$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" xmlns:local="clr-namespace:;assembly=LIQUID_ASSEMBLY"
        Title="Orby"
        Width="454" Height="58"
        WindowStyle="None"
        AllowsTransparency="True"
        Background="Transparent"
        ResizeMode="NoResize"
        ShowInTaskbar="False"
        Topmost="True"
        Focusable="False"
        SnapsToDevicePixels="True" UseLayoutRounding="True" TextOptions.TextFormattingMode="Display" TextOptions.TextRenderingMode="Grayscale">
    <Grid x:Name="Root" Background="Transparent">
        <local:OrbyLiquidSurface x:Name="Notch" Width="620" Height="374" VerticalAlignment="Top" HorizontalAlignment="Center">
            <Grid Margin="12,0,12,0">
                <Grid.RowDefinitions>
                    <RowDefinition Height="48"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>

                <Grid x:Name="CompactHeader" Grid.Row="0" Width="336" HorizontalAlignment="Center">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="60"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>

                    <Canvas Grid.Column="0" x:Name="PetCanvas" Width="54" Height="38" VerticalAlignment="Center"/>

                    <TextBlock x:Name="CompactTaskTitle" FontFamily="Segoe UI" Grid.Column="1" Text="" Foreground="#F1F2F4" FontSize="12" FontWeight="Bold" VerticalAlignment="Center" Margin="0,0,8,0" TextTrimming="CharacterEllipsis"/>
                    <StackPanel Grid.Column="1" Opacity="0" VerticalAlignment="Center" Margin="0,0,8,0">
                        <TextBlock x:Name="StateText" Text="Orby" Foreground="White" FontSize="13" FontWeight="Bold" TextTrimming="CharacterEllipsis"/>
                        <TextBlock x:Name="DetailText" Text="Waiting for ChatGPT" Foreground="#A9FFFFFF" FontSize="10" Margin="0,2,0,0" TextTrimming="CharacterEllipsis"/>
                    </StackPanel>



                    <Grid Grid.Column="2" Width="34" Height="34" VerticalAlignment="Center"><Canvas x:Name="MiniOrbyHost" Width="34" Height="34"/>
                        <Ellipse x:Name="StatusDot" Visibility="Collapsed"/>
                        <TextBlock x:Name="StatusTiny" Visibility="Collapsed"/>
                    </Grid>
                </Grid>

                <Grid x:Name="ExpandedArea" Width="596" HorizontalAlignment="Center" Height="180" VerticalAlignment="Top" Grid.Row="0" Grid.RowSpan="2" Margin="0,8,0,0" Opacity="0" Visibility="Collapsed"/>
            </Grid>
        </local:OrbyLiquidSurface>
        <Button x:Name="AlbumCoverButton" Width="32" Height="32" HorizontalAlignment="Center" VerticalAlignment="Top" Margin="230,8,0,0" Visibility="Collapsed" Background="Transparent" BorderThickness="0" Padding="0" Cursor="Hand">
                        <Button.Template><ControlTemplate TargetType="Button"><Grid ClipToBounds="False"><Border CornerRadius="6" Background="#151515"><Border.Clip><RectangleGeometry Rect="0,0,32,32" RadiusX="6" RadiusY="6"/></Border.Clip><Image x:Name="AlbumCoverImage" Stretch="UniformToFill" RenderOptions.BitmapScalingMode="HighQuality"/></Border><local:OrbyArtworkProgress x:Name="AlbumProgress" Width="32" Height="32" IsHitTestVisible="False"/></Grid></ControlTemplate></Button.Template>
                    </Button>
    </Grid>
</Window>
'@
[xml]$xaml=$xaml.Replace('LIQUID_ASSEMBLY',[OrbyLiquidSurface].Assembly.GetName().Name)

try {
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $window = [Windows.Markup.XamlReader]::Load($reader)
} catch {
    Fail-Orbit "Orbit UI failed to load: $($_.Exception.Message)"
}

$notch = $window.FindName('Notch')
$expandedArea = $window.FindName('ExpandedArea')
. (Join-Path $PSScriptRoot 'Panel-Layers.ps1')
$stateText = $window.FindName('StateText')
$detailText = $window.FindName('DetailText')
$statusDot = $window.FindName('StatusDot')
$statusTiny = $window.FindName('StatusTiny')
$expandedTitle = New-Object Windows.Controls.TextBlock
$expandedText = New-Object Windows.Controls.TextBlock
$modeBadge = New-Object Windows.Controls.TextBlock
$workBar = New-Object Windows.Controls.ProgressBar
$hintText = New-Object Windows.Controls.TextBlock
$petBody = $window.FindName('PetBody')
$eyeL = $window.FindName('EyeL')
$eyeR = $window.FindName('EyeR')
$eyeXL = $window.FindName('EyeXL')
$eyeXR = $window.FindName('EyeXR')
$mouth = $window.FindName('Mouth')
$star1 = $window.FindName('Star1')
$star2 = $window.FindName('Star2')
$checkMarks = $window.FindName('CheckMarks')
$busyRing1 = $window.FindName('BusyRing1')
$busyRing2 = $window.FindName('BusyRing2')
$attentionBadge = $window.FindName('AttentionBadge')
. (Join-Path $PSScriptRoot 'Orb-Avatar.ps1')
$script:orbParts = New-OrbitAvatar
[void]$window.FindName('PetCanvas').Children.Add($script:orbParts.Root)


$script:expanded = $false
$script:lastWorking = $false
$script:lastStateKey = ''
$script:finishUntil = [datetime]::MinValue
$script:errorUntil = [datetime]::MinValue
$script:lastErrorText = ''
$script:notificationUntil = [datetime]::MinValue
$script:lastNotificationSignature = ''
$script:scanCounter = 0
$script:petState = 'idle'
$script:animTick = 0
$script:lastBlink = Get-Date
$script:blinkUntil = [datetime]::MinValue
$script:lastElapsedValue = ''
$script:lastElapsedChangedAt = [datetime]::MinValue
$script:lastEvidence = ''
$script:needsInput = $false
$script:needsText = ''
$script:lastStoppedUiText = ''

# v0.7: ChatGPT/Codex local-log bridge imported from the user's previous Orbit pet.
# Local log events are the primary task-state signal; Windows UI Automation remains
# as a fallback for normal chat/open-window detection and visible activity labels.
$script:chatLogState = 'idle'
$script:chatLogMessage = ''
$script:chatLogEvidence = ''
$script:chatLogStateAt = [datetime]::MinValue
$script:chatLogCurrentPath = ''
$script:chatLogCursor = [int64]0
$script:chatLogCarry = ''
$script:chatLogInitialSeen = $false
$script:chatLogLastSearchAt = [datetime]::MinValue
$script:chatLogRoots = @()
$script:chatLogSourceSeen = $false
$script:chatLogActiveConversation = ''
$script:chatLogActiveTurn = ''
$script:chatLogPendingCompleteAt = [datetime]::MinValue
$script:chatLogPendingCompleteEvidence = ''

function Set-Brush {
    param($Element, [string]$Hex)
    $Element.Fill = [Windows.Media.BrushConverter]::new().ConvertFromString($Hex)
}

function Position-Orbit {
    try {
        [OrbyMonitorLayout]::Position($window)
    } catch {
        Write-OrbitLog "Position warning: $($_.Exception.Message)"
        $window.Left = 0
        $window.Top = 0
    }
}

. (Join-Path $PSScriptRoot 'Motion.ps1')
. (Join-Path $PSScriptRoot 'Normal-Chat-Tracker.ps1')

function Set-OrbitExpanded {
    param([bool]$Expand)
    if($script:fullscreenHidden){return}
    if(-not $Expand -and $script:musicPopup -and $script:musicPopup.IsOpen){return}
    if($script:waterPriority){$Expand=$false}
    if(-not $Expand -and $script:orbyEventMode -and -not $script:waterPriority){return}
    if ($script:expanded -eq $Expand) { return }
    # Keep the outgoing page intact while closing. Reset it before the next
    # opening only when needed, instead of rebuilding Home during collapse.
    if($Expand -and $script:referenceControls -and $script:compactMenuPage -and $script:compactMenuPage -ne 'home') {
        Set-OrbyHomePage 'home'
    }
    $script:expanded = $Expand
    if($script:avatarRenderer){$script:avatarRenderer.Suspended=$Expand}
    foreach($mini in $script:miniOrbys){$mini.Renderer.Suspended=$Expand}
    Set-OrbyAlbumPlacement $Expand

    if($script:avatarRenderer){[void]$script:avatarRenderer.Trigger($(if($Expand){'notch_open'}else{'notch_close'}))}
    if($script:referenceRenderer){[void]$script:referenceRenderer.Trigger($(if($Expand){'notch_open'}else{'notch_close'}))}
    $expandedArea.Visibility='Visible'
    if($script:orbySettings.ReducedMotion -or -not [Windows.SystemParameters]::ClientAreaAnimation){[OrbyMotion.Driver]::Snap($notch,[OrbyLiquidSurface]::MorphProperty,[double]$Expand)}else{[OrbyMotion.Driver]::Move($notch,[OrbyLiquidSurface]::MorphProperty,[double]$Expand,$Expand)}
    Set-OrbyCompactLayer ($window.FindName('CompactHeader')) $Expand
    Invoke-OrbyMotion $expandedArea ([Windows.UIElement]::OpacityProperty) $(if($Expand){1}else{0}) 0.16
    if(Test-Path function:Update-OrbyCompactTask){Update-OrbyCompactTask}

}

function Get-AllTopWindows {
    try {
        $root = [System.Windows.Automation.AutomationElement]::RootElement
        return $root.FindAll(
            [System.Windows.Automation.TreeScope]::Children,
            [System.Windows.Automation.Condition]::TrueCondition
        )
    } catch {
        Write-OrbitLog "Top window scan failed: $($_.Exception.Message)"
        return @()
    }
}

function Find-ChatGptWindow {
    # First try the real ChatGPT/OpenAI process main window handle. Newer desktop
    # builds can expose an empty or generic UIA top-level title, which made the
    # older top-window scoring miss normal chat even while the app was visible.
    try {
        foreach ($p in @(Get-Process -ErrorAction SilentlyContinue)) {
            try {
                $pn = [string]$p.ProcessName
                $pt = [string]$p.MainWindowTitle
                if ($pn -match '(?i)chatgpt|openai' -or $pt -match '(?i)chatgpt') {
                    if ($p.MainWindowHandle -ne 0) {
                        $direct = [System.Windows.Automation.AutomationElement]::FromHandle([IntPtr]$p.MainWindowHandle)
                        # Do not return a hidden secondary ChatGPT window. The
                        # normal-chat renderer can keep one around after a
                        # navigation; selecting it made Orby report idle while
                        # the visible chat was searching.
                        if ($null -ne $direct -and -not $direct.Current.IsOffscreen) { return $direct }
                    }
                }
            } catch {}
        }
    } catch {}

    $best = $null
    $bestScore = -1

    foreach ($el in (Get-AllTopWindows)) {
        try {
            $name = [string]$el.Current.Name
            $class = [string]$el.Current.ClassName
            $pid = [int]$el.Current.ProcessId
            if ($name -eq 'Orbit Notch') { continue }

            $score = 0
            if ($name -match '(?i)chatgpt|openai') { $score += 28 }
            if ($class -match '(?i)chrome_widgetwin|applicationframe|winui|xaml|webview') { $score += 2 }

            $processName = ''
            try {
                $p = Get-Process -Id $pid -ErrorAction Stop
                $processName = [string]$p.ProcessName
                if ($processName -match '(?i)chatgpt|openai') { $score += 40 }
                if (($processName -match '(?i)chrome|msedge|firefox') -and ($name -match '(?i)chatgpt')) { $score += 16 }
            } catch {}

            # Exact fingerprints cover both normal chat and Work. Some releases
            # expose only one of these strings, so a strong composer fingerprint
            # is enough by itself rather than requiring two matches.
            if ($score -lt 28) {
                $fingerprints = 0
                foreach ($needle in @('Work with ChatGPT','Message ChatGPT','Ask anything','Search chats','New chat','Full access')) {
                    try {
                        $cond = New-Object System.Windows.Automation.PropertyCondition(
                            [System.Windows.Automation.AutomationElement]::NameProperty,
                            $needle
                        )
                        $hit = $el.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $cond)
                        if ($null -ne $hit) {
                            if ($needle -match '(?i)work with chatgpt|message chatgpt|ask anything') { $score += 28 }
                            elseif ($needle -eq 'Full access') { $score += 12 }
                            else { $score += 9 }
                            $fingerprints++
                        }
                    } catch {}
                }
                if ($fingerprints -ge 2) { $score += 14 }
            }

            if ($score -gt $bestScore -and $score -ge 26) {
                $best = $el
                $bestScore = $score
            }
        } catch {}
    }
    if($best){return $best}

    # Normal ChatGPT may be running in a browser rather than the desktop
    # process. Use visible browser roots as a conservative fallback and only
    # accept one exposing a ChatGPT composer or live activity label.
    foreach($el in (Get-AllTopWindows)){
        try{
            if($el.Current.IsOffscreen){continue}
            $pid=[int]$el.Current.ProcessId;$p=Get-Process -Id $pid -ErrorAction SilentlyContinue
            if(-not $p -or [string]$p.ProcessName -notmatch '(?i)chrome|msedge|firefox|brave|opera'){continue}
            $all=$el.FindAll([System.Windows.Automation.TreeScope]::Descendants,[System.Windows.Automation.Condition]::TrueCondition)
            $limit=[Math]::Min($all.Count,2200);$hit=$false
            for($i=0;$i -lt $limit;$i++){
                $n=[string]$all[$i].Current.Name;$id=[string]$all[$i].Current.AutomationId
                if(($n+' '+$id) -match '(?i)Searching\s+\d+\s+websites|Ask ChatGPT|Message ChatGPT|Stop generating|Generating response'){$hit=$true;break}
            }
            if($hit){return $el}
        }catch{}
    }
    return $null
}

function Get-ChatGptUiRoots {
    param($Root)

    $result = New-Object System.Collections.Generic.List[object]
    $seen = New-Object 'System.Collections.Generic.HashSet[string]'

    function Add-UiRootLocal {
        param($Element, [string]$Tag)
        if ($null -eq $Element) { return }
        try {
            $hwnd = [int64]$Element.Current.NativeWindowHandle
            $pid = [int]$Element.Current.ProcessId
            $name = [string]$Element.Current.Name
            $class = [string]$Element.Current.ClassName
            $key = "$hwnd|$pid|$class|$name"
            if ($seen.Add($key)) {
                $result.Add([pscustomobject]@{
                    Element = $Element
                    Tag = $Tag
                    Hwnd = $hwnd
                    ProcessId = $pid
                    Name = $name
                    ClassName = $class
                })
            }
        } catch {}
    }

    Add-UiRootLocal $Root 'main-uia-root'

    # Newer ChatGPT desktop builds can keep the Chromium/WebView accessibility
    # tree under a child HWND while the top-level UIA element contains almost no
    # descendants. Enumerate child HWNDs and expose each one as an additional UIA
    # root. This is the main v0.8.1 fix for normal ChatGPT chat.
    try {
        $mainHwnd = [int64]$Root.Current.NativeWindowHandle
        if ($mainHwnd -ne 0) {
            $children = [OrbitNative]::GetChildWindows([IntPtr]$mainHwnd)
            $limit = [Math]::Min($children.Length, 120)
            for ($i = 0; $i -lt $limit; $i++) {
                try {
                    $h = $children[$i]
                    $class = [OrbitNative]::WindowClass($h)
                    $title = [OrbitNative]::WindowText($h)
                    $childEl = [System.Windows.Automation.AutomationElement]::FromHandle($h)
                    if ($null -ne $childEl) {
                        Add-UiRootLocal $childEl ("child-hwnd class=[$class] title=[$title]")
                    }
                } catch {}
            }
        }
    } catch {
        if ($DebugMode) { Write-OrbitLog "Child HWND UIA root scan warning: $($_.Exception.Message)" }
    }

    return $result
}

function Get-NamedControls {
    param(
        $Root,
        [System.Windows.Automation.ControlType]$ControlType,
        [int]$Limit = 2000
    )
    $result = New-Object System.Collections.Generic.List[object]
    if ($null -eq $Root) { return $result }

    $typeName = ''
    try { $typeName = [string]$ControlType.ProgrammaticName } catch { $typeName = [string]$ControlType }
    $isButtonType = $typeName -match '(?i)button$'
    $seen = New-Object 'System.Collections.Generic.HashSet[string]'

    foreach ($rootInfo in @(Get-ChatGptUiRoots $Root)) {
        if ($result.Count -ge $Limit) { break }
        try {
            $cond = New-Object System.Windows.Automation.PropertyCondition(
                [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
                $ControlType
            )
            $all = $rootInfo.Element.FindAll([System.Windows.Automation.TreeScope]::Descendants, $cond)
            $remaining = [Math]::Max(0, $Limit - $result.Count)
            $max = [Math]::Min($all.Count, $remaining)
            for ($i = 0; $i -lt $max; $i++) {
                try {
                    $cur = $all[$i].Current
                    $name = ([string]$cur.Name).Trim()
                    $automationId = ([string]$cur.AutomationId).Trim()
                    $helpText = ([string]$cur.HelpText).Trim()
                    $className = ([string]$cur.ClassName).Trim()
                    $rect = $cur.BoundingRectangle
                    $left = [double]$rect.Left
                    $top = [double]$rect.Top
                    $right = [double]$rect.Right
                    $bottom = [double]$rect.Bottom
                    $width = [double]$rect.Width
                    $height = [double]$rect.Height
                    $native = [int64]$cur.NativeWindowHandle
                    $off = [bool]$cur.IsOffscreen
                    $enabled = [bool]$cur.IsEnabled

                    # Keep anonymous buttons too. The active normal-chat Stop icon
                    # may have no Name/AutomationId/HelpText in some ChatGPT builds.
                    if (-not $isButtonType -and [string]::IsNullOrWhiteSpace($name) -and [string]::IsNullOrWhiteSpace($automationId) -and [string]::IsNullOrWhiteSpace($helpText)) { continue }

                    $key = "$typeName|$name|$automationId|$helpText|$className|$left|$top|$right|$bottom|$native"
                    if (-not $seen.Add($key)) { continue }

                    $result.Add([pscustomobject]@{
                        Name = $name
                        AutomationId = $automationId
                        ClassName = $className
                        HelpText = $helpText
                        ControlType = $typeName
                        IsOffscreen = $off
                        IsEnabled = $enabled
                        NativeWindowHandle = $native
                        Left = $left
                        Top = $top
                        Right = $right
                        Bottom = $bottom
                        Width = $width
                        Height = $height
                        RootTag = [string]$rootInfo.Tag
                    })
                } catch {}
            }
        } catch {
            if ($DebugMode) { Write-OrbitLog "Control scan warning ($typeName / $($rootInfo.Tag)): $($_.Exception.Message)" }
        }
    }
    return $result
}

function Get-ChatGptSnapshot {
    param($ChatElement)

    $snapshot = [ordered]@{
        Working = $false
        Failure = $false
        FailureText = ''
        InputRequest = ''
        Stopped = $false
        StoppedText = ''
        Mode = 'CHAT'
        Activity = ''
        Elapsed = ''
        Evidence = ''
    }
    if ($null -eq $ChatElement) { return [pscustomobject]$snapshot }

    $buttonItems = Get-NamedControls $ChatElement ([System.Windows.Automation.ControlType]::Button) 1600
    $textItems = Get-NamedControls $ChatElement ([System.Windows.Automation.ControlType]::Text) 2600
    $customItems = Get-NamedControls $ChatElement ([System.Windows.Automation.ControlType]::Custom) 1200
    $editItems = Get-NamedControls $ChatElement ([System.Windows.Automation.ControlType]::Edit) 500
    $documentItems = Get-NamedControls $ChatElement ([System.Windows.Automation.ControlType]::Document) 900
    $paneItems = Get-NamedControls $ChatElement ([System.Windows.Automation.ControlType]::Pane) 900
    $groupItems = Get-NamedControls $ChatElement ([System.Windows.Automation.ControlType]::Group) 1800

    $names = New-Object System.Collections.Generic.List[string]
    foreach ($collection in @($textItems, $customItems, $editItems, $documentItems, $paneItems, $groupItems, $buttonItems)) {
        foreach ($item in $collection) {
            if ($item.IsOffscreen -or -not $item.IsEnabled) { continue }
            foreach ($value in @([string]$item.Name, [string]$item.HelpText, [string]$item.AutomationId)) {
                $v = $value.Trim()
                if ($v.Length -gt 0 -and $v.Length -le 220 -and -not $names.Contains($v)) { $names.Add($v) }
            }
        }
    }

    $stopEvidence = ''
    foreach ($item in $buttonItems) {
        if ($item.IsOffscreen) { continue }
        $n = [string]$item.Name
        $id = [string]$item.AutomationId
        $help = [string]$item.HelpText
        $buttonSignal = ($n + ' ' + $id + ' ' + $help).Trim()
        if ($buttonSignal -match '(?i)\bstop\b|stop[_ -]?(?:generating|response|streaming|thinking|task)|\binterrupt\b|interrupt[_ -]?(?:generation|response|task)|\bcancel(?: response| generation| task)?\b|abort[_ -]?(?:generation|response|task)') {
            if ($buttonSignal -notmatch '(?i)close|dismiss') {
                $stopEvidence = if ([string]::IsNullOrWhiteSpace($n)) { $buttonSignal } else { $n }
                break
            }
        }
    }

    $elapsedEvidence = ''
    $thinkingEvidence = ''
    $activityCandidates = New-Object System.Collections.Generic.List[string]
    $failureEvidence = ''
    $stoppedEvidence = ''
    $workModeEvidence = $false

    foreach ($n in $names) {
        if ($n -match '(?i)^work with chatgpt$|^working for\s+\d+\s*(?:s|sec|seconds|m|min|minutes)\b') {
            $workModeEvidence = $true
        }

        if ($n -match '(?i)^working for\s+([0-9]+)\s*(s|sec|seconds|m|min|minutes)\b') {
            $elapsedEvidence = $n
            $snapshot.Elapsed = $n
        }

        if ($n -match '(?i)^(thinking|thinking\.\.\.|reasoning|working|working\.\.\.)$') {
            $thinkingEvidence = $n
            if (-not $activityCandidates.Contains($n)) { $activityCandidates.Add($n) }
        }

        if ($n.Length -le 100 -and $n -match '(?i)^(searching|searched|browsing|reading|analyzing|analysing|writing|coding|creating|editing|running|researching|generating|opening|checking|looking up|using|downloading|uploading|preparing|reviewing|summarizing|summarising|calculating|fetching|processing)\b') {
            if (-not $activityCandidates.Contains($n)) { $activityCandidates.Add($n) }
        }

        if ($n.Length -le 180 -and $n -match '(?i)^you\s+(?:stopped|paused)(?:\s+after\s+.+)?$|^(?:stopped|paused)(?:\s+after\s+.+)?$|response\s+(?:stopped|cancelled|canceled)|task\s+(?:stopped|cancelled|canceled)|generation\s+(?:stopped|cancelled|canceled)|cancelled by you|canceled by you') {
            $stoppedEvidence = $n
        }

        if ($n.Length -le 160 -and $n -match '(?i)something went wrong|task failed|response failed|network error|there was an error|unable to complete|couldn.t complete|failed to complete|timed out|connection lost') {
            $failureEvidence = $n
        }
    }

    if ($workModeEvidence) { $snapshot.Mode = 'WORK' }
    # Normal ChatGPT often exposes a concrete activity label such as
    # "Searching 11 websites" without exposing a Stop button. Treat that
    # changing activity as LIVE, while keeping generic historical text out.
    if (-not $workModeEvidence -and $activityCandidates.Count -gt 0 -and
        ($activityCandidates | Where-Object {$_ -match '(?i)^(searching|browsing|reading|analyzing|analysing|generating|processing|fetching|looking up)\b'} | Select-Object -First 1)) {
        $snapshot.Working = $true
        $snapshot.Evidence = 'activity:' + $activityCandidates[$activityCandidates.Count-1]
    }

    # Work mode exposes a live elapsed timer such as "Working for 19s". Track
    # whether that value is changing so completed historical text is not treated
    # as a permanently-running task.
    $elapsedIsLive = $false
    if (-not [string]::IsNullOrWhiteSpace($elapsedEvidence)) {
        if ($elapsedEvidence -ne $script:lastElapsedValue) {
            $hadElapsed = -not [string]::IsNullOrWhiteSpace($script:lastElapsedValue)
            $script:lastElapsedValue = $elapsedEvidence
            if ($hadElapsed) {
                $script:lastElapsedChangedAt = Get-Date
                $elapsedIsLive = $true
            } else {
                $script:lastElapsedChangedAt = [datetime]::MinValue
            }
        } elseif ((Get-Date) -lt $script:lastElapsedChangedAt.AddSeconds(4.5)) {
            $elapsedIsLive = $true
        }
    } else {
        $script:lastElapsedValue = ''
        $script:lastElapsedChangedAt = [datetime]::MinValue
    }

    if (-not [string]::IsNullOrWhiteSpace($stopEvidence)) {
        $snapshot.Working = $true
        $snapshot.Evidence = "button:$stopEvidence"
    } elseif ($elapsedIsLive) {
        $snapshot.Working = $true
        $snapshot.Evidence = "timer:$elapsedEvidence"
    }

    if (-not [string]::IsNullOrWhiteSpace($failureEvidence)) {
        $snapshot.Failure = $true
        $snapshot.FailureText = $failureEvidence
    }

    if (-not [string]::IsNullOrWhiteSpace($stoppedEvidence)) {
        $snapshot.Stopped = $true
        $snapshot.StoppedText = $stoppedEvidence
    }

    if ($activityCandidates.Count -gt 0) {
        # Prefer a concrete action over a generic "Thinking" label.
        $selected = ''
        for ($i = $activityCandidates.Count - 1; $i -ge 0; $i--) {
            $candidate = $activityCandidates[$i]
            if ($candidate -notmatch '(?i)^(thinking|reasoning|working)(\.\.\.)?$') {
                $selected = $candidate
                break
            }
        }
        if ([string]::IsNullOrWhiteSpace($selected)) { $selected = $activityCandidates[$activityCandidates.Count - 1] }
        $snapshot.Activity = $selected
    } elseif (-not [string]::IsNullOrWhiteSpace($thinkingEvidence)) {
        $snapshot.Activity = $thinkingEvidence
    } elseif ($snapshot.Working) {
        $snapshot.Activity = 'Generating response'
    }

    # Require blocking controls; scheduler reminders and ordinary prose are content.
    $snapshot.InputRequest = Get-OrbyUiInputRequest @($names) @($buttonItems)

    if ($DebugMode -and $snapshot.Evidence -ne $script:lastEvidence) {
        $script:lastEvidence = $snapshot.Evidence
        Write-OrbitLog "DETECT evidence=$($snapshot.Evidence) mode=$($snapshot.Mode) activity=$($snapshot.Activity) elapsed=$($snapshot.Elapsed) buttons=$($buttonItems.Count) names=$($names.Count)"
    }

    return [pscustomobject]$snapshot
}

function Get-LiveChatGptNotification {
    param($ChatElement)
    try {
        foreach ($top in (Get-AllTopWindows)) {
            if ($null -ne $ChatElement -and $top.Equals($ChatElement)) { continue }
            $topName = ''
            $class = ''
            try {
                $topName = [string]$top.Current.Name
                $class = [string]$top.Current.ClassName
            } catch { continue }

            if ($topName -eq 'Orbit Notch') { continue }
            if ($topName -match '(?i)widgets|widget board|search|task view') { continue }
            if (($topName -notmatch '(?i)notification|toast|new notification') -and
                ($class -notmatch '(?i)toast|notification|corewindow')) {
                continue
            }

            $all = $top.FindAll(
                [System.Windows.Automation.TreeScope]::Descendants,
                [System.Windows.Automation.Condition]::TrueCondition
            )
            $names = New-Object System.Collections.Generic.List[string]
            $hasChatGpt = $false
            $limit = [Math]::Min($all.Count, 320)
            for ($i = 0; $i -lt $limit; $i++) {
                try {
                    $n = ([string]$all[$i].Current.Name).Trim()
                    if ([string]::IsNullOrWhiteSpace($n)) { continue }
                    if ($n -match '(?i)chatgpt') { $hasChatGpt = $true }
                    if ($names.Count -lt 14 -and -not $names.Contains($n)) { $names.Add($n) }
                } catch {}
            }
            if ($hasChatGpt) {
                $useful = New-Object System.Collections.Generic.List[string]
                foreach ($item in $names) {
                    if ($item -match '(?i)^widgets?$|weather|partly cloudy|mostly cloudy|sunny|taskbar|system tray') { continue }
                    if (-not $useful.Contains($item)) { $useful.Add($item) }
                }
                $text = ($useful -join ' | ')
                if ($text.Length -gt 260) { $text = $text.Substring(0,260) }
                if ($text.Length -gt 0) { return $text }
                return 'New ChatGPT notification'
            }
        }
    } catch {
        Write-OrbitLog "Notification scan warning: $($_.Exception.Message)"
    }
    return $null
}

# =========================================================
# CHATGPT / CODEX LOCAL LOG BRIDGE
# Imported from the user's previous Orbit pet integration.
# =========================================================

function Add-UniqueLogRoot {
    param([System.Collections.Generic.List[string]]$Roots, [string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    try {
        $full = [IO.Path]::GetFullPath($Path)
        if ((Test-Path -LiteralPath $full) -and -not $Roots.Contains($full)) {
            $Roots.Add($full)
        }
    } catch {}
}

function Get-ChatGptLogRoots {
    $roots = New-Object 'System.Collections.Generic.List[string]'

    if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        $local = $env:LOCALAPPDATA
        Add-UniqueLogRoot $roots (Join-Path $local 'Packages\OpenAI.Codex_2p2nqsd0c76g0\LocalCache\Local\Codex\Logs')
        Add-UniqueLogRoot $roots (Join-Path $local 'OpenAI\Codex\Logs')
        Add-UniqueLogRoot $roots (Join-Path $local 'OpenAI\ChatGPT\Logs')

        # Discover other OpenAI/ChatGPT package log folders once. This covers
        # desktop app package-name changes without hard-coding every build name.
        $packages = Join-Path $local 'Packages'
        if (Test-Path -LiteralPath $packages) {
            try {
                Get-ChildItem -LiteralPath $packages -Directory -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -match '(?i)openai|chatgpt|codex' } |
                    ForEach-Object {
                        try {
                            Get-ChildItem -LiteralPath $_.FullName -Directory -Recurse -Filter 'Logs' -ErrorAction SilentlyContinue |
                                ForEach-Object { Add-UniqueLogRoot $roots $_.FullName }
                        } catch {}
                    }
            } catch {}
        }

        try {
            Get-ChildItem -LiteralPath (Join-Path $local 'OpenAI') -Directory -Recurse -Filter 'Logs' -ErrorAction SilentlyContinue |
                ForEach-Object { Add-UniqueLogRoot $roots $_.FullName }
        } catch {}
    }

    if (-not [string]::IsNullOrWhiteSpace($env:APPDATA)) {
        try {
            $roamingOpenAi = Join-Path $env:APPDATA 'OpenAI'
            if (Test-Path -LiteralPath $roamingOpenAi) {
                Get-ChildItem -LiteralPath $roamingOpenAi -Directory -Recurse -Filter 'Logs' -ErrorAction SilentlyContinue |
                    ForEach-Object { Add-UniqueLogRoot $roots $_.FullName }
            }
        } catch {}
    }

    return @($roots)
}

function Find-LatestChatGptLogFile {
    if ($script:chatLogRoots.Count -eq 0) {
        $script:chatLogRoots = @(Get-ChatGptLogRoots)
        if ($script:chatLogRoots.Count -gt 0) {
            Write-OrbitLog ('LOG roots => ' + ($script:chatLogRoots -join ' | '))
        }
    }

    $bestMain = $null
    $bestMainTime = [datetime]::MinValue
    $bestAny = $null
    $bestAnyTime = [datetime]::MinValue

    foreach ($root in $script:chatLogRoots) {
        try {
            Get-ChildItem -LiteralPath $root -File -Recurse -Filter '*.log' -ErrorAction SilentlyContinue | ForEach-Object {
                $modified = $_.LastWriteTimeUtc
                if ($_.Name -match '-t0-') {
                    if ($modified -gt $bestMainTime) {
                        $bestMainTime = $modified
                        $bestMain = $_.FullName
                    }
                } elseif ($modified -gt $bestAnyTime) {
                    $bestAnyTime = $modified
                    $bestAny = $_.FullName
                }
            }
        } catch {}
    }

    if ($null -ne $bestMain) { return $bestMain }
    return $bestAny
}

function Set-ChatLogState {
    param(
        [string]$State,
        [string]$Message,
        [string]$Evidence = ''
    )

    $changed = ($script:chatLogState -ne $State) -or ($script:chatLogMessage -ne $Message)
    $script:chatLogState = $State
    $script:chatLogMessage = $Message
    $script:chatLogEvidence = $Evidence
    $script:chatLogStateAt = Get-Date
    $script:chatLogSourceSeen = $true

    if ($changed) {
        Write-OrbitLog "CHAT LOG => $State | $Message | $Evidence"
    }
}

function Update-ChatLogActivityFromLine {
    param([string]$Lower)
    if ($script:chatLogState -ne 'working') { return }

    $message = ''
    if ($Lower -match 'web_search|search_query|searching the web|tool.{0,30}search') {
        $message = 'Searching the web...'
    } elseif ($Lower -match 'read_page|open_url|fetch_url|reading source|browser.{0,20}(open|read)') {
        $message = 'Reading sources...'
    } elseif ($Lower -match 'apply_patch|write_file|edit_file|file_edit|patch applied') {
        $message = 'Editing files...'
    } elseif ($Lower -match 'exec_command|shell_command|run_command|terminal command') {
        $message = 'Running a command...'
    } elseif ($Lower -match 'analyz|reasoning|thinking') {
        $message = 'Thinking...'
    }

    if (-not [string]::IsNullOrWhiteSpace($message) -and $message -ne $script:chatLogMessage) {
        Set-ChatLogState 'working' $message 'log-activity'
    }
}

. (Join-Path $PSScriptRoot 'Chat-State.ps1')
. (Join-Path $PSScriptRoot 'Local-Tasks.ps1')
. (Join-Path $PSScriptRoot 'Pet-Feed.ps1')
. (Join-Path $PSScriptRoot 'Desktop-Connections.ps1')
. (Join-Path $PSScriptRoot 'Media-Art.ps1')
. (Join-Path $PSScriptRoot 'Music-Player.ps1')
. (Join-Path $PSScriptRoot 'Pet-Sounds.ps1')
. (Join-Path $PSScriptRoot 'Compact-Task.ps1')
. (Join-Path $PSScriptRoot 'File-Shelf.ps1')
. (Join-Path $PSScriptRoot 'Desktop-UI.ps1')
$script:desktopPanel=New-OrbyPanel
. (Join-Path $PSScriptRoot 'Animation-Picker.ps1')
. (Join-Path $PSScriptRoot 'Account-Usage.ps1')
. (Join-Path $PSScriptRoot 'Reference-Home.ps1')
[void]$expandedArea.Children.Add((New-OrbyHome))
. (Join-Path $PSScriptRoot 'Event-Cards.ps1')
$script:orbyTaskAlerts=@{}
if ($PreviewDirectory) {
    [void][IO.Directory]::CreateDirectory($PreviewDirectory)
    $window.Width=668;$window.Height=384;$notch.Morph=1
    $expandedArea.Visibility='Visible';$expandedArea.Opacity=1
    $stateText.Text='Orby';$detailText.Text='Your desktop companion';$statusTiny.Text='HOME'
    Update-OrbitAvatar $script:orbParts 'idle' 0
    Update-OrbyHome
    $window.FindName('CompactHeader').Opacity=0
    for ($page=0;$page -lt 1;$page++) {
        $script:desktopControls.DesktopTabs.SelectedIndex=$page
        $window.Content.Measure((New-Object Windows.Size 668,384))
        $window.Content.Arrange((New-Object Windows.Rect 0,0,668,384))
        $window.Content.UpdateLayout()
        $bitmap=New-Object Windows.Media.Imaging.RenderTargetBitmap 668,194,96,96,([Windows.Media.PixelFormats]::Pbgra32)
        $bitmap.Render($window.Content)
        $encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder
        $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
        $path=Join-Path $PreviewDirectory ('Orby-panel-'+$page+'.png')
        $fs=[IO.File]::Create($path);try{$encoder.Save($fs)}finally{$fs.Dispose()}
    }
    $notch.Morph=0;$window.FindName('CompactHeader').Opacity=1;$expandedArea.Opacity=0
    $window.Content.UpdateLayout()
    $bitmap=New-Object Windows.Media.Imaging.RenderTargetBitmap 668,80,96,96,([Windows.Media.PixelFormats]::Pbgra32)
    $bitmap.Render($window.Content)
    $encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder
    $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
    $fs=[IO.File]::Create((Join-Path $PreviewDirectory 'Orby-compact.png'));try{$encoder.Save($fs)}finally{$fs.Dispose()}
    Write-OrbitLog 'Rendered reference home preview'
    exit 0
}


function Set-PetState {
    param([string]$State)

    if($script:greetingActive -and $State -in @('idle','open')){return}
    if($State -ne $script:petState -and $State -in @('success','attention','error')){Invoke-OrbySound $State}
    $script:petState = $State
    if($script:avatarRenderer -and -not $script:waterPriority){$script:avatarRenderer.SetState($State,$script:chatLogMessage)}
    if($script:referenceRenderer){$script:referenceRenderer.SetState($State,$script:chatLogMessage)}
}

function Start-OrbyGreeting {
    if($script:orbySettings.ReducedMotion){return}
    $script:greetingActive=$true
    foreach($renderer in @($script:avatarRenderer,$script:referenceRenderer)){
        if($renderer){$renderer.SetState('idle','');[void]$renderer.Trigger('startup_boot')}
    }
    $script:greetingTimer=New-Object Windows.Threading.DispatcherTimer
    $script:greetingTimer.Interval=[timespan]::FromMilliseconds(1450)
    $script:greetingTimer.Add_Tick({
        $script:greetingTimer.Stop()
        foreach($renderer in @($script:avatarRenderer,$script:referenceRenderer)){if($renderer){[void]$renderer.Trigger('wave')}}
        $script:greetingFinishTimer=New-Object Windows.Threading.DispatcherTimer
        $script:greetingFinishTimer.Interval=[timespan]::FromMilliseconds(1450)
        $script:greetingFinishTimer.Add_Tick({$script:greetingFinishTimer.Stop();$script:greetingActive=$false;Set-PetState 'idle'})
        $script:greetingFinishTimer.Start()
    })
    $script:greetingTimer.Start()
}

function Set-OrbitState {
    param(
        [string]$Key,
        [string]$Title,
        [string]$Detail,
        [string]$Tiny,
        [string]$Dot,
        [string]$ExpandedTitleValue,
        [string]$ExpandedBody,
        [string]$Mode = 'CHAT',
        [bool]$Busy = $false,
        [string]$Pet = 'idle'
    )
    $stateText.Text = $Title
    $detailText.Text = $Detail
    $statusTiny.Text = $Tiny
    Set-Brush $statusDot $Dot
    $expandedTitle.Text = $ExpandedTitleValue
    $expandedText.Text = $ExpandedBody
    $modeBadge.Text = $Mode
    $workBar.Visibility = if ($Busy) { 'Visible' } else { 'Collapsed' }
    $hintText.Visibility = if ($Busy) { 'Collapsed' } else { 'Visible' }
    Set-PetState $Pet

    if ($script:lastStateKey -ne $Key) {
        Write-OrbitLog "STATE => $Key | $Title | $Detail | mode=$Mode"
        $script:lastStateKey = $Key
    }
}

function Focus-ChatGpt {
    try {
        $el = Find-ChatGptWindow
        if ($null -eq $el) {
            $expandedText.Text = 'ChatGPT is not open right now.'
            return
        }
        try { $el.SetFocus() } catch {}
        $hwnd = [IntPtr]::Zero
        try { $hwnd = [IntPtr]$el.Current.NativeWindowHandle } catch {}
        if ($hwnd -ne [IntPtr]::Zero) {
            try { [OrbitNative]::ShowWindowAsync($hwnd, 9) | Out-Null } catch {}
            try { [OrbitNative]::SetForegroundWindow($hwnd) | Out-Null } catch {}
        }
    } catch {
        Write-OrbitLog "Focus warning: $($_.Exception.Message)"
    }
}

try {
    $script:chatLogRoots = @(Get-ChatGptLogRoots)
    if ($script:chatLogRoots.Count -gt 0) {
        Write-OrbitLog ('Discovered ChatGPT log roots: ' + ($script:chatLogRoots -join ' | '))
    } else {
        Write-OrbitLog 'No ChatGPT/Codex log roots discovered yet; UI fallback remains active.'
    }
} catch {
    Write-OrbitLog "Log root discovery warning: $($_.Exception.Message)"
}

function Test-OrbyPointerInside {
    $cursor=[Windows.Forms.Cursor]::Position
    $source=[Windows.PresentationSource]::FromVisual($window)
    if(-not $source){return $window.IsMouseOver}
    $point=$source.CompositionTarget.TransformFromDevice.Transform((New-Object Windows.Point $cursor.X,$cursor.Y))
    $rect=$notch.Clip.Bounds
    return $notch.Clip.FillContains([Windows.Point]::new($point.X-$window.Left-($window.Width-$notch.Width)/2,$point.Y-$window.Top))
}
$script:hoverExitTimer=New-Object Windows.Threading.DispatcherTimer
$script:hoverExitTimer.Interval=[timespan]::FromMilliseconds(90)
$script:hoverExitTimer.Add_Tick({$script:hoverExitTimer.Stop();if(-not (Test-OrbyPointerInside)){Set-OrbitExpanded $false}})
$window.Add_MouseEnter({if($script:fullscreenHidden){return};$script:hoverExitTimer.Stop();if(-not $script:waterDay -or -not (Get-OrbyWaterTitle)){Set-OrbitExpanded $true}})
$window.Add_MouseLeave({$script:hoverExitTimer.Start()})
$window.Add_MouseDoubleClick({param($sender,$eventArgs)
 if($eventArgs.Handled -or $script:albumCoverButton.IsMouseOver -or ($script:waterDay -and (Get-OrbyWaterTitle))){return}
 $avatarHit=$script:orbParts.Root.IsMouseOver -or ($script:miniNotchParts -and $script:miniNotchParts.Root.IsMouseOver)
 if($avatarHit){
  $id=if(@($script:compactProviderOrder).Count -and $script:compactProviderOrder[0] -in @('chatgpt','claude','gemini')){$script:compactProviderOrder[0]}elseif($script:companionSelection -in @('chatgpt','claude','gemini')){$script:companionSelection}else{$script:orbySettings.PrimaryProvider}
  Invoke-OrbySafeAction {Invoke-OrbyAvatarClick $id 2} 'Open AI app';$eventArgs.Handled=$true
 }
})

$window.Add_SourceInitialized({
    try {
        Position-Orbit
        $notch.Attach($window)
        [OrbyMonitorLayout]::Attach($window,$notch)
        Write-OrbitLog "UI ready at Left=$($window.Left), Top=0"
    } catch {}
})

# Render-paced native animation; no PowerShell callbacks or geometry parsing per frame.
# Renderer sources are compiled once by Motion.ps1 with the correct private/public catalog.
$window.Width=668;$window.Height=384
$script:avatarRenderer=New-Object OrbyAvatarRenderer ($script:orbParts)
$script:referenceRenderer=New-Object OrbyAvatarRenderer ($script:referenceOrb)
# Water reminders are excluded from the sharing edition.
Start-OrbyGreeting
. (Join-Path $PSScriptRoot 'Task-Avatars.ps1')
Initialize-OrbyTaskPack
. (Join-Path $PSScriptRoot 'Mini-Orbys.ps1')
Initialize-OrbyMinis
. (Join-Path $PSScriptRoot 'Home-Buddies.ps1')
Initialize-OrbyHomeBuddies
. (Join-Path $PSScriptRoot 'Ambient-Motion.ps1')
Initialize-OrbyAmbientMotion
. (Join-Path $PSScriptRoot 'Fullscreen-Guard.ps1')
. (Join-Path $PSScriptRoot 'Providers.ps1')
. (Join-Path $PSScriptRoot 'Compact-Menus.ps1')
. (Join-Path $PSScriptRoot 'Home-Dashboard.ps1') -NoNetwork:$PerformanceCheck
Initialize-OrbyAccountUsage
Update-OrbyAgents # Warm cached quota layout before the first menu click.
$window.Add_Closed({Stop-OrbyAmbientMotion;Stop-OrbyHomeBuddies;Stop-OrbyMinis})
$window.Add_Closed({Stop-OrbyTaskPack})
$script:displayHz=[OrbyDisplay]::RefreshHz(([Windows.Forms.Screen]::FromHandle([Windows.Interop.WindowInteropHelper]::new($window).Handle)).DeviceName)
[OrbyRefreshClock]::Configure($script:displayHz)
Write-OrbitLog ('DISPLAY refreshHz='+$script:displayHz+' frameLoop=CompositionTarget.Rendering tier='+([Windows.Media.RenderCapability]::Tier -shr 16))
$window.Add_Closed({Write-OrbitLog ('MOTION frames='+[OrbyMotion.Driver]::FrameCount+' maxGapMs='+[math]::Round([OrbyMotion.Driver]::MaxFrameGapMs,1));[OrbyMotion.Transitions]::StopAll();[OrbyMotion.Driver]::StopAll();if($script:greetingTimer){$script:greetingTimer.Stop()};if($script:greetingFinishTimer){$script:greetingFinishTimer.Stop()};Write-OrbitLog ('RENDER observedFps='+[math]::Round($script:avatarRenderer.ObservedFps,1)+' frames='+$script:avatarRenderer.Frames+' p95FrameMs='+[math]::Round($script:avatarRenderer.P95FrameMs,1)+' maxGapMs='+[math]::Round($script:avatarRenderer.MaxFrameGapMs,1));[OrbyRefreshClock]::Stop();$script:avatarRenderer.Dispose();$script:referenceRenderer.Dispose();if($script:toolsWindow){$script:toolsWindow.Close()};if($script:animationWindow){$script:animationWindow.Close()}})

if($PerformanceCheck){
 $script:perfWatch=[Diagnostics.Stopwatch]::StartNew();$script:perfPhase=0
 $script:perfTimer=New-Object Windows.Threading.DispatcherTimer
 $script:perfTimer.Interval=[timespan]::FromSeconds(2)
 $script:perfTimer.Add_Tick({
  $script:perfPhase++
  if($script:perfPhase -ge 21){$script:perfTimer.Stop();$script:orbyQuitMenuItem.PerformClick();return}
  Set-OrbitExpanded (($script:perfPhase%2) -eq 1)
    if($script:perfPhase -in @(1,3,5)){
   $id=switch($script:perfPhase){1{'chatgpt'}3{'claude'}5{'gemini'}}
   $script:orbySettings.ProviderEnabled='chatgpt,claude,gemini'
   Select-OrbyCompanion $id;Set-OrbyAIChooser $true
   if($script:companionSelection -ne $id -or $script:compactMenuPage -ne 'home'){throw 'Companion click selected the wrong AI or left the main tab'}
   if($script:providerCards[$id].Controls.InlineUsage.Visibility -ne 'Visible'){throw 'Main companion usage bars are hidden'}
   Write-OrbitLog ('CLICK CHECK provider='+$id+' passed')
  }
    if($script:perfPhase -eq 6){Invoke-OrbySafeAction {throw 'Simulated recoverable action failure'} 'Recovery test';Write-OrbitLog 'RECOVERY CHECK safe action returned.'}
    if($script:perfPhase -eq 7){
   Set-OrbyHomePage 'music';Write-OrbitLog 'RECOVERY CHECK music tab still works.'
   if($script:orbyPrivateWater){Show-OrbyAnimations;$script:animationWindow.FindName('WaterSip').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent));if($script:previewAnimationRenderer.ActiveId -ne 'water_sip'){throw 'Private water click failed'};Write-OrbitLog 'PRIVATE WATER CHECK matte preview works.';$script:animationWindow.Close()}
  }
  if($script:perfPhase -eq 8){
   $script:recoveryProbe=[Windows.Controls.Button]::new();$script:recoveryProbe.Add_Click({throw 'Simulated unhandled UI event failure'})
   $window.Dispatcher.BeginInvoke([Action]{$script:recoveryProbe.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))}) | Out-Null
  }
  if($script:perfPhase -eq 9){Select-OrbyCompanion 'claude';Write-OrbitLog 'RECOVERY CHECK tab works after dispatcher error.'}
  if($script:perfPhase -eq 10){
   $script:dropCheckFile=Join-Path $logDir 'drop-fixture.txt';[IO.File]::WriteAllText($script:dropCheckFile,'Native-host fixture only; never sent.')
   if(-not (Set-OrbyDroppedFiles @($script:dropCheckFile))){throw 'Native file drop rejected'}
   Select-OrbyDropProvider 'claude'
   if($script:dropControls.DropProviders.Children.Count -ne 3 -or $expandedArea.Height -ne 322){throw 'Native drop chooser or layout failed'}
   Write-OrbitLog 'DROP CHECK chooser and optional prompt passed.'
  }
  if($script:perfPhase -eq 11){
   Complete-OrbyDropHandoff ([pscustomobject]@{Sent=$true;Message='Local result fixture'})
   if($script:dropBusy -or $script:dropPanel.Visibility -eq 'Visible'){throw 'Native send result left composer stuck'}
   Write-OrbitLog 'DROP CHECK success returned Home.'
  }
  if($script:perfPhase -eq 12){
   $script:orbySettings.ProviderEnabled='gemini';[void](Set-OrbyDroppedFiles @($script:dropCheckFile));Select-OrbyDropProvider 'gemini'
   if($script:orbyEventMode -ne 'drop' -or $script:dropPanel.Visibility -ne 'Visible'){throw 'Gemini-only drop was blocked by ChatGPT connection'}
   Write-OrbitLog 'DROP CHECK Gemini-only connection passed.'
  }
  if($script:perfPhase -eq 13){
   Close-OrbyDropComposer
   if($script:dropBusy -or $script:dropHandle -or $script:orbyEventMode -or $script:compactMenuPage -ne 'home'){throw 'Native Close did not restore Home'}
   Write-OrbitLog 'DROP CHECK Close returned Home.'
  }
  if($script:perfPhase -in @(14,15)){
   $script:orbySettings.ProviderEnabled='chatgpt,claude,gemini'
   $script:orbyActiveTasks=@(
    [pscustomobject]@{Id='native-inspector-main';Provider='chatgpt';State='working';Title='Main fixture task';Action='Checking the first task'},
    [pscustomobject]@{Id='native-inspector-second';Provider='chatgpt';State='working';Title='Second fixture task';Action='Checking secondary task details'})
   Select-OrbyCompanion 'chatgpt';Set-OrbitExpanded $true
   $card=$script:providerCards.chatgpt
   $card.Buddies[0].Host.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
   if($card.SelectedTaskId -ne 'native-inspector-second' -or $card.Controls.Title.Text -ne 'Second fixture task' -or -not $card.Buddies[0].Renderer.ShowStatusDot -or $card.Buddies[0].Host.Width -ne 62){throw 'Native secondary task click, size or orbit failed'}
   Write-OrbitLog 'TASK CHECK secondary task click, size and blue orbit passed.'
   if($script:perfPhase -eq 15){
    $card.Controls.TaskListButton.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
    if(-not $card.Controls.TaskListButton.ContextMenu.IsOpen -or $card.Controls.TaskListButton.ContextMenu.Items.Count -ne 2){throw 'Native task menu failed'}
    Set-OrbitExpanded $false
    if(-not $script:expanded){throw 'Task popup collapsed the notch'}
    Close-OrbyTaskMenus;Write-OrbitLog 'TASK CHECK task list and hover guard passed.'
   }
  }
  if($script:perfPhase -eq 16){
   $script:orbyActiveTasks=@([pscustomobject]@{Id='native-inspector-main';Provider='chatgpt';State='working';Title='Main fixture task';Action='Checking the first task'})
   Update-OrbyMultiProvider
   if($script:providerCards.chatgpt.SelectedTaskId -ne 'native-inspector-main'){throw 'Completed task retained stale selection'}
   Write-OrbitLog 'TASK CHECK completed selection returned to main task.'
  }
  if($script:perfPhase -eq 17){
   Set-OrbyHomePage 'music'
   if((Test-OrbyTaskMenuOpen) -or -not $script:providerCards.chatgpt.Renderer.Suspended){throw 'Task inspector cleanup failed'}
   Write-OrbitLog 'TASK CHECK hidden page cleanup passed.'
  }
  if($script:perfPhase -eq 18){
   $script:orbySettings.ProviderEnabled='chatgpt';$script:orbyActiveTasks=@([pscustomobject]@{Id='native-home-main';Provider='chatgpt';State='working';Title='Home check fixture';Action='Checking the overview'})
   $script:orbySettings.ReducedMotion=$true;Set-OrbitExpanded $true;Set-OrbyHomePage 'home';$window.UpdateLayout()
   if($script:homeDashboard.Visibility -ne 'Visible' -or $script:sharedCompanionView.Visibility -ne 'Collapsed' -or $script:compactMenus.Height -ne 344 -or $notch.Height -lt $script:compactMenus.Height+14){throw 'Native Home dashboard layout failed'}
   if($script:homeControls.ContainsKey('WeatherCard') -or (Test-Path function:Start-OrbyHomeForecast)){throw 'Removed Home weather is still present'}
   if($script:homeProviderTiles.chatgpt.Count.Text -ne '1 task'){throw 'Native Home lost primary activity'}
   Write-OrbitLog 'HOME CHECK overview, task count, neutral cards, no weather and native bounds passed.'
   $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new([int]$window.Width,[int]$window.Height,96,96,[Windows.Media.PixelFormats]::Pbgra32);$bitmap.Render($window)
   $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap));$stream=[IO.File]::Create((Join-Path $logDir 'native-home.png'));try{$encoder.Save($stream)}finally{$stream.Dispose()}
   $script:orbySettings.ReducedMotion=$false
   if($script:personalWaterCard){
    $script:personalTestTime=[datetime]::Now;function Get-OrbyPersonalNow {return $script:personalTestTime}
    $before=[int]$script:personalWater.TotalMl;$originalSize=$script:orbySettings.NotchSize;$script:orbySettings.ReducedMotion=$true
    $script:orbyEventMode='';$script:chatLogState='working';$script:greetingActive=$false
    foreach($size in @('default','mini')){
     $script:orbySettings.NotchSize=$size;$script:personalWater.NextReminder=(Get-OrbyPersonalNow).AddMinutes(-1).ToString('o');Invoke-OrbyPersonalHomeTick;$window.UpdateLayout()
     if(-not $script:personalReminderPending -or -not $script:waterPriority -or $script:expanded -or $script:waterPrompt.Visibility -ne 'Visible' -or $notch.MiniMode){throw 'Private reminder must show Drink/Skip in the expanded compact header for both sizes'}
     if($script:personalWater.TotalMl -ne $before -or $script:avatarRenderer.ActiveId -ne 'water_reminder'){throw 'Reminder changed intake or lost its native animation'}
     $t=$script:avatarRenderer.TimeSeconds;$script:avatarRenderer.Draw($t+5.1)
     if($script:avatarRenderer.ActiveId -ne 'water_wait'){throw 'Reminder animation did not advance to its persistent waiting pose'}
     $script:avatarRenderer.AdvanceIdle($t+400,$true);Update-OrbyMultiProvider;Update-OrbyCompactTask
     if($script:avatarRenderer.ActiveId -ne 'water_wait' -or $script:waterPrompt.Visibility -ne 'Visible'){throw 'Provider refresh or AFK erased the pending reminder'}
     foreach($button in @($script:waterDrinkButton,$script:waterSkipButton)){
      $point=$button.TranslatePoint([Windows.Point]::new(0,0),$window.FindName('CompactHeader'))
      if($point.X -lt 0 -or $point.Y -lt 0 -or $point.Y+$button.ActualHeight -gt 48){throw 'Water action is outside the visible notch'}
     }
     $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new([int]$window.Width,[int]$window.Height,96,96,[Windows.Media.PixelFormats]::Pbgra32);$bitmap.Render($window)
     $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap));$stream=[IO.File]::Create((Join-Path $logDir ('water-prompt-'+$size+'.png')));try{$encoder.Save($stream)}finally{$stream.Dispose()}
     $script:waterSkipButton.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
     if($script:personalReminderPending -or $script:personalWater.TotalMl -ne $before -or $script:avatarRenderer.ActiveId -ne 'water_skip' -or $script:waterPrompt.Visibility -ne 'Collapsed'){throw 'Skip must dismiss the prompt, animate and never log water'}
     if([datetime]::Parse($script:personalWater.NextReminder) -ne (Get-OrbyPersonalNow).AddMinutes($script:personalPreferences.IntervalMinutes)){throw 'Skip did not schedule the next normal reminder'}
     $script:personalTestTime=$script:personalTestTime.AddSeconds(4);Invoke-OrbyPersonalHomeTick
     if($script:waterPriority -or ($size -eq 'mini' -and -not $notch.MiniMode)){throw 'Skip did not restore the original compact size'}
    }
    $script:personalWater.NextReminder=(Get-OrbyPersonalNow).AddMinutes(-1).ToString('o');Invoke-OrbyPersonalHomeTick
    $script:waterDrinkButton.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent));$script:waterDrinkButton.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
    if($script:personalReminderPending -or $script:personalWater.TotalMl -ne $before+$script:personalPreferences.DrinkMl -or $script:avatarRenderer.ActiveId -ne 'water_reveal'){throw 'Drink must log exactly once and start the bottle sequence'}
    $t=$script:avatarRenderer.TimeSeconds;$script:avatarRenderer.Draw($t+.8);if($script:avatarRenderer.ActiveId -ne 'water_sip'){throw 'Bottle reveal did not transition into the drinking animation'}
    $script:avatarRenderer.Draw($t+2.3);if($script:avatarRenderer.ActiveId -ne 'water_progress' -or -not $script:avatarRenderer.WaterVisible){throw 'Drinking did not transition into bottle progress'}
    $script:personalTestTime=$script:personalTestTime.AddSeconds(9);Invoke-OrbyPersonalHomeTick
    if($script:waterPriority -or $script:avatarRenderer.ActiveId.StartsWith('water_')){throw 'Drink animation did not return to normal task activity'}
    $afterDrink=[int]$script:personalWater.TotalMl;$script:personalWater.NextReminder=(Get-OrbyPersonalNow).AddMinutes(-1).ToString('o');Invoke-OrbyPersonalHomeTick
    $script:chatLogState='attention';Invoke-OrbyPersonalHomeTick
    if(-not $script:personalReminderPending -or $script:waterPriority -or $script:waterPrompt.Visibility -ne 'Collapsed'){throw 'Water reminder obscures a newer AI question'}
    $script:chatLogState='working';Invoke-OrbyPersonalHomeTick
    if($script:waterPrompt.Visibility -ne 'Visible'){throw 'Deferred reminder did not return after the question cleared'}
    foreach($flag in @('dropBusy','fullscreenHidden')){
     Set-Variable -Scope Script -Name $flag -Value $true;Invoke-OrbyPersonalHomeTick
     if($script:waterPriority -or $script:waterPrompt.Visibility -ne 'Collapsed'){throw 'Reminder obscures a file handoff or fullscreen app'}
     Set-Variable -Scope Script -Name $flag -Value $false;Invoke-OrbyPersonalHomeTick
     if(-not $script:waterPriority -or $script:waterPrompt.Visibility -ne 'Visible'){throw 'Deferred reminder was lost'}
    }
    Snooze-OrbyPersonalReminder
    if($script:personalReminderPending -or $script:waterPriority -or $script:personalWater.TotalMl -ne $afterDrink -or [datetime]::Parse($script:personalWater.NextReminder) -ne (Get-OrbyPersonalNow).AddMinutes(10)){throw 'Snooze changed intake or left the notch stuck'}
    $saved=Get-Content -LiteralPath (Join-Path $logDir 'water-progress.json') -Raw | ConvertFrom-Json
    if($saved.TotalMl -ne $afterDrink){throw 'Notch Drink was not persisted in the Home log'}
    $script:orbySettings.NotchSize=$originalSize;$script:orbySettings.ReducedMotion=$false;Update-OrbyCompactTask
    Write-OrbitLog 'PRIVATE HOME CHECK notch Drink/Skip, persistent animation, mini/default sizes, reveal/sip/progress, duplicate clicks, permission/fullscreen/drop deferral, no automatic intake and snooze passed.'
   }elseif(Test-Path function:Invoke-OrbyPersonalHomeTick){throw 'Private reminders leaked into public Home'}
  }
  if($script:perfPhase -eq 19){
   Set-OrbyAIChooser $true
   if($script:dashboardRoute -ne 'ai' -or -not $script:aiChooserOpen -or $script:compactMenus.Width -ne 596){throw 'Native separate AI route failed'}
   Set-OrbyHomePage 'home'
   if($script:aiChooserOpen -or $script:homeDashboard.Visibility -ne 'Visible'){throw 'Native return to Home failed'}
   Write-OrbitLog 'HOME CHECK separate AI chooser and return passed.'
  }
  if($script:perfPhase -eq 20){
   $script:orbyActiveTasks=@();Update-OrbyMultiProvider
   foreach($tile in $script:homeProviderTiles.Values){if(-not $tile.Renderer.Suspended){throw 'Hidden Home animation kept rendering'}}
   Write-OrbitLog 'HOME CHECK hidden animation cleanup passed.'
  }
 })
 $window.Add_ContentRendered({$script:perfTimer.Start()})
}

. (Join-Path $PSScriptRoot 'UI-Input-Classification.ps1')
. (Join-Path $PSScriptRoot 'UI-Scan.ps1')
$scanTimer = New-Object Windows.Threading.DispatcherTimer ([Windows.Threading.DispatcherPriority]::Background)
$scanTimer.Interval = [TimeSpan]::FromMilliseconds(900)
$scanTick = {
    try {
        if([OrbyMotion.Driver]::PendingCount -gt 0){
            if(-not $script:motionScanWait){$script:motionScanWait=[Diagnostics.Stopwatch]::StartNew()}
            if($script:motionScanWait.ElapsedMilliseconds -lt 700){$scanTimer.Interval=[timespan]::FromMilliseconds(50);return}
        }
        $script:motionScanWait=$null;$scanTimer.Interval=[timespan]::FromMilliseconds(900)
        $script:scanCounter++
        $scanWatch=[Diagnostics.Stopwatch]::StartNew()
        $script:avatarRenderer.EyeEffects=$script:referenceRenderer.EyeEffects=[bool]$script:orbySettings.EyeEffects
        $script:avatarRenderer.ReducedMotion=$script:referenceRenderer.ReducedMotion=([bool]$script:orbySettings.ReducedMotion -or -not [Windows.SystemParameters]::ClientAreaAnimation)
        if($script:avatarRenderer.ReducedMotion -and -not $script:motionReducedApplied){
            [OrbyMotion.Driver]::Snap($notch,[OrbyLiquidSurface]::MorphProperty,[double][bool]$script:expanded)
            $notch.BeginAnimation([OrbyLiquidSurface]::ExpandedHeightProperty,$null)
            Set-OrbyAlbumPlacement ([bool]$script:expanded) $false
        }
        $script:motionReducedApplied=$script:avatarRenderer.ReducedMotion
        Update-OrbyShelf
        Update-OrbyLocal
        Update-OrbyAlbumArt
        Update-OrbyPetSounds
        $musicPlaying=[bool]($script:orbySettings.Music -and (($script:orbyShared.SelectedMusic -and $script:orbyShared.SelectedMusic.Playing) -or ($script:orbyShared.Media -and $script:orbyShared.Media.Playing)))
        if($script:avatarRenderer){$script:avatarRenderer.MusicPlaying=$musicPlaying}
        if($script:referenceRenderer){$script:referenceRenderer.MusicPlaying=$musicPlaying}
        Sync-OfficialTaskFeed
        if ($script:orbySettings.Tasks -and $script:chatLogState -in @('success','stopped','error')) {
            $taskKey=$script:chatLogActiveConversation+'|'+$script:chatLogActiveTurn+'|'+$script:chatLogState
            if (-not $script:orbyTaskAlerts.ContainsKey($taskKey)) {
                $script:orbyTaskAlerts[$taskKey]=$true
                $label=switch($script:chatLogState){success{'Task finished'}stopped{'Task stopped'}error{'Task failed'}}
                Add-OrbyAlert 'task' $label (Get-NotchTaskTitle 'ChatGPT task')
            }
        }

        if (-not $script:petFeedAvailable -and -not $script:feedPollTask) {
            Update-ChatGptLogWatcher
            Update-LocalTaskEvidence
            Normalize-TransientLogState
        }
        $ui=$script:uiScanShared.Latest
        $uiFresh=$ui -and ([datetime]::UtcNow-$ui.At).TotalSeconds -lt 12
        $chat=if($uiFresh){$ui.Chat}else{$null}
        $detected=($null -ne $chat) -or $script:petFeedAvailable
        $script:chatConnectionPresent=[bool]($uiFresh -and $ui.Connected)
        $title=if($uiFresh){$ui.Title}else{''}
        $snapshot=if($uiFresh){$ui.Snapshot}else{[pscustomobject]@{Working=$false;Failure=$false;FailureText='';InputRequest='';Stopped=$false;StoppedText='';Mode='CHAT';Activity='';Elapsed='';Evidence=''}}
        Update-OrbyApprovalBridge
        Apply-OrbyBlockingInput $snapshot $script:approvalRequest ([bool]($script:approvalRequestAt -and ([datetime]::UtcNow-$script:approvalRequestAt).TotalSeconds -lt 5))
        # Regular ChatGPT uses a separate UI tracker. Work/Codex feed state
        # cannot suppress these visible normal-chat transitions.
        $normalChatActive = Update-OrbyNormalChatTracker $chat $snapshot
        if($normalChatActive){Show-OrbyNormalChatState $snapshot}

        if (-not $script:petFeedAvailable -and $script:chatLogState -eq 'working' -and ([datetime]::UtcNow - $script:lastActiveActivity).TotalSeconds -ge $script:watchdogSeconds) { Invoke-ChatWatchdog $(if($uiFresh){$ui.Watchdog}else{'unknown'}) }

        # Only treat a stop/pause label as current when it newly appears or
        # changes. Historical "You stopped after ..." text can remain visible in
        # the conversation and must not cancel a later successful turn.
        $stopUiChanged = $false
        if (-not [string]::IsNullOrWhiteSpace($snapshot.StoppedText)) {
            if ($snapshot.StoppedText -ne $script:lastStoppedUiText) {
                $stopUiChanged = $true
                $script:lastStoppedUiText = $snapshot.StoppedText
                Write-OrbitLog "UI STOP EVIDENCE => $($snapshot.StoppedText)"
            }
        }

        # If the UI explicitly says the user stopped/paused the current turn,
        # override a stale log-level WORKING state immediately. This fixes the
        # old latch where Work remained LIVE after Stop/Pause because no cancel
        # record was emitted into the watched Codex log.
        if (-not $script:petFeedAvailable -and $snapshot.Stopped -and $stopUiChanged -and ($script:lastWorking -or $script:chatLogState -eq 'working')) {
            $snapshot.Working = $false
            $snapshot.Evidence = 'ui-stop'
            Set-ChatLogState 'stopped' 'ChatGPT stopped' 'ui-stop'
            $script:needsInput = $false
            $script:needsText = ''
            $script:finishUntil = [datetime]::MinValue
        }

        # Error is only promoted when it appears while/just after an active run,
        # which avoids old error text in conversation history causing false alarms.
        if ($snapshot.Failure -and ($script:lastWorking -or $snapshot.Working)) {
            $script:lastErrorText = $snapshot.FailureText
            $script:errorUntil = (Get-Date).AddSeconds(5)
            $script:needsInput = $false
            $script:needsText = ''
        }

        # Starting/resuming work clears amber input only when no blocking card is visible.
        if ($snapshot.Working) {
            $script:needsInput = $false
            $script:needsText = ''
        }

        # When active work stops, decide whether ChatGPT completed, was stopped,
        # or is waiting for the user. UI state is allowed to reconcile a stale
        # local-log WORKING state so the pet and notch cannot disagree.
        if (-not $script:chatLogSourceSeen -and $script:lastWorking -and -not $snapshot.Working -and -not $snapshot.Failure) {
            if ($snapshot.Stopped -and $stopUiChanged) {
                Set-ChatLogState 'stopped' 'ChatGPT stopped' 'ui-stop-transition'
                $script:needsInput = $false
                $script:needsText = ''
                $script:finishUntil = [datetime]::MinValue
            } elseif (-not [string]::IsNullOrWhiteSpace($snapshot.InputRequest)) {
                $script:needsInput = $true
                $script:needsText = $snapshot.InputRequest
                $script:finishUntil = [datetime]::MinValue
                if ($script:chatLogState -eq 'working') {
                    Set-ChatLogState 'attention' 'ChatGPT needs you' 'ui-needs-input'
                }
                Write-OrbitLog "NEEDS INPUT => $($snapshot.InputRequest)"
            } else {
                $script:needsInput = $false
                $script:needsText = ''
                if ($script:chatLogState -eq 'working') {
                    Set-ChatLogState 'success' 'ChatGPT finished' 'ui-working-ended'
                } else {
                    $script:finishUntil = (Get-Date).AddSeconds(4.2)
                }
            }
        }
        $script:lastWorking = $snapshot.Working

        # Notification scanning is slower, so only do it every ~2.7 seconds.
        if (($script:scanCounter % 3) -eq 0) {
            $note = if($uiFresh){$ui.Notification}else{$null}
            if (-not [string]::IsNullOrWhiteSpace($note)) {
                $sig = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($note))
                if ($sig -ne $script:lastNotificationSignature) {
                    $script:lastNotificationSignature = $sig
                    $script:notificationUntil = (Get-Date).AddSeconds(5)
                    Write-OrbitLog "NOTIFICATION => $note"
                }
            }
        }

        $now = Get-Date

        $desktopStatus=if($normalChatActive){$null}else{Get-OrbyStatus}
        if(-not $desktopStatus){
        # PRIMARY: exact local log states used by the user's previous working pet.
        # FALLBACK: Windows UI Automation for normal chat/open-window visibility.
        if (-not $normalChatActive -and $script:chatLogState -eq 'error') {
            Set-OrbitState 'log-error' 'Task failed' 'ChatGPT reported a task failure' 'FAIL' '#FF6969' 'ChatGPT task failed' 'Synced from the ChatGPT/Codex local desktop log.' $snapshot.Mode $false 'error'
        }
        elseif (-not $normalChatActive -and $script:chatLogState -eq 'working') {
            $logActivity = if ([string]::IsNullOrWhiteSpace($script:chatLogMessage)) { 'ChatGPT is working...' } else { $script:chatLogMessage }
            Set-OrbitState 'log-working' (Get-NotchTaskTitle)  $logActivity 'LIVE' '#5DFF8B' 'Live ChatGPT activity' "Synced from the local ChatGPT/Codex log.`n$logActivity" $snapshot.Mode $true 'working'
        }
        elseif (-not $normalChatActive -and $script:chatLogState -eq 'attention') {
            $ask = if ([string]::IsNullOrWhiteSpace($script:chatLogMessage)) { 'ChatGPT is waiting for your input.' } else { $script:chatLogMessage }
            Set-OrbitState 'log-needs-input' (Get-NotchTaskTitle 'ChatGPT needs you')  $ask 'NEED' '#FFC65C' 'Input needed' 'ChatGPT requested user input. Answer it and Orbit will return to LIVE when the next turn starts.' $snapshot.Mode $false 'attention'
        }
        elseif (-not $normalChatActive -and $script:chatLogState -eq 'success') {
            Set-OrbitState 'log-finished' (Get-NotchTaskTitle 'Task complete')  'ChatGPT finished successfully' 'DONE' '#78FFAE' 'ChatGPT finished' 'Turn-complete was received from the local ChatGPT/Codex log.' $snapshot.Mode $false 'success'
        }
        elseif (-not $normalChatActive -and $script:chatLogState -eq 'stopped') {
            Set-OrbitState 'log-stopped' (Get-NotchTaskTitle 'Task stopped')  'ChatGPT was stopped' 'STOP' '#A0A0A0' 'ChatGPT stopped' 'The current turn was cancelled or stopped.' $snapshot.Mode $false 'stopped'
        }
        elseif ($now -lt $script:errorUntil) {
            $body = if ([string]::IsNullOrWhiteSpace($script:lastErrorText)) { 'ChatGPT reported a task or response error.' } else { $script:lastErrorText }
            Set-OrbitState 'ui-error' 'Task failed' 'ChatGPT reported an error' 'FAIL' '#FF6969' 'ChatGPT task failed' $body $snapshot.Mode $false 'error'
        }
        elseif ($snapshot.Working -and -not $script:chatLogSourceSeen) {
            $activity = if ([string]::IsNullOrWhiteSpace($snapshot.Activity)) { 'Thinking / generating' } else { $snapshot.Activity }
            $detail = $activity
            if (-not [string]::IsNullOrWhiteSpace($snapshot.Elapsed) -and $snapshot.Elapsed -ne $activity) {
                $detail = "$activity  |  $($snapshot.Elapsed)"
            }
            $body = "Windows UI fallback activity: $activity"
            if (-not [string]::IsNullOrWhiteSpace($snapshot.Elapsed)) { $body += "`n$($snapshot.Elapsed)" }
            Set-OrbitState 'ui-working' 'ChatGPT is working' $detail 'LIVE' '#5DFF8B' 'Live ChatGPT activity' $body $snapshot.Mode $true 'working'
        }
        elseif ($script:needsInput) {
            $ask = if ([string]::IsNullOrWhiteSpace($script:needsText)) { 'ChatGPT is waiting for your input.' } else { $script:needsText }
            $shortAsk = if ($ask.Length -gt 92) { $ask.Substring(0,92) + '...' } else { $ask }
            Set-OrbitState 'ui-needs-input' 'ChatGPT needs you' $shortAsk 'NEED' '#FFC65C' 'Input needed' $ask $snapshot.Mode $false 'attention'
        }
        elseif ($now -lt $script:finishUntil) {
            Set-OrbitState 'ui-finished' 'Task complete' 'ChatGPT finished successfully' 'DONE' '#78FFAE' 'ChatGPT finished' 'The Windows UI working signal ended.' $snapshot.Mode $false 'success'
        }
        elseif ($now -lt $script:notificationUntil) {
            Set-OrbitState 'notification' 'ChatGPT notification' 'New activity from ChatGPT' 'NEW' '#59B8FF' 'ChatGPT notification' 'A ChatGPT Windows notification was detected.' $snapshot.Mode $false 'notification'
        }
        elseif ($detected) {
            $shortTitle = if ($title.Length -gt 54) { $title.Substring(0,54) + '...' } else { $title }
            $sourceNote = if ($script:chatLogSourceSeen) { 'Local log sync is active; Windows UI is also available as a fallback.' } else { 'Orbit is waiting for a local task event and also watching Windows UI.' }
            Set-OrbitState 'open' 'ChatGPT is open' $shortTitle 'OPEN' '#A78BFA' 'ChatGPT detected' $sourceNote $snapshot.Mode $false 'open'
        }
        else {
            $script:needsInput = $false
            $script:needsText = ''
            $idleBody = if ($script:chatLogRoots.Count -gt 0) { 'Local ChatGPT/Codex log folders were found. Orbit is waiting for a turn to start.' } else { 'No ChatGPT window or known local log folder is currently visible.' }
            Set-OrbitState 'idle' 'Orbit' 'Waiting for ChatGPT' 'IDLE' '#727272' 'ChatGPT status' $idleBody 'CHAT' $false 'idle'
        }
        }
        if ($desktopStatus) {
            Set-OrbitState ('orby-'+$desktopStatus.Tiny) $desktopStatus.Title $desktopStatus.Detail $desktopStatus.Tiny $desktopStatus.Color 'Orby connections' $desktopStatus.Detail 'DESKTOP' ($desktopStatus.Pet -in @('working','music')) $desktopStatus.Pet
        }
        Update-OrbyEventCard
        Update-OrbyProviderState
        Update-OrbyCompactTask
        Update-OrbyTaskPack
        if ($script:expanded) { Update-OrbyHome };if($script:toolsWindow -and $script:toolsWindow.IsVisible){Update-OrbyPanel}
        if($script:scanCounter%12 -eq 0){
            $currentHz=[OrbyDisplay]::RefreshHz(([Windows.Forms.Screen]::FromHandle([Windows.Interop.WindowInteropHelper]::new($window).Handle)).DeviceName)
            if($currentHz -ne $script:displayHz){$script:displayHz=$currentHz;[OrbyRefreshClock]::Configure($currentHz);Write-OrbitLog ('DISPLAY refreshHz='+$currentHz)}
            Write-OrbitLog ('RENDER observedFps='+[math]::Round($script:avatarRenderer.ObservedFps,1)+' p95FrameMs='+[math]::Round($script:avatarRenderer.P95FrameMs,1)+' maxGapMs='+[math]::Round($script:avatarRenderer.MaxFrameGapMs,1))
        }
        if($PerformanceCheck){Write-OrbitLog ('SCAN ms='+[math]::Round($scanWatch.Elapsed.TotalMilliseconds,1))}
        if ($script:orbyWorkerHandle.IsCompleted -and -not $script:orbyShared.Stop) {
            $errors=$script:orbyWorker.Streams.Error | Out-String
            Write-OrbitLog ('Connection worker stopped: '+$errors)
            $script:desktopControls.ConnectionNote.Text='Connection worker needs a restart'
        }
    } catch {
        Write-OrbitLog "Timer warning: $($_.Exception.Message)"
        Set-OrbitState 'detector-error' 'Orbit detector issue' 'Run Capture-ChatGPT-UI.cmd' 'ERR' '#FF6B6B' 'Detector error' $_.Exception.Message 'CHAT' $false 'error'
    }
}
$scanTimer.Add_Tick($scanTick)

try {
    Start-OrbyUiScanner
    Start-OrbyWorker
    Start-OrbyTray
    # Warm the status and layout paths before displaying the animated greeting.
    & $scanTick
    Update-OrbyHome
    # Native rendering starts with the WPF composition loop.
    $scanTimer.Start()
    Write-OrbitLog 'Animation and detector timers started.'
    $orbyApplication=[Windows.Application]::Current
    if(-not $orbyApplication){$orbyApplication=[Windows.Application]::new()}
    Initialize-OrbyUiRecovery $orbyApplication
    $orbyApplication.ShutdownMode=[Windows.ShutdownMode]::OnMainWindowClose
    $null=$orbyApplication.Run($window)
    Write-OrbitLog 'Window closed normally.'
    exit 0
} catch {
    Request-OrbyQuit
    Fail-Orbit "Orbit crashed: $($_.Exception.Message)"
}

















