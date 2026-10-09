$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

try {
Add-Type @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class OrbitCaptureNative {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
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
} catch {}

$outDir = Join-Path $env:LOCALAPPDATA 'OrbitNotch'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$outFile = Join-Path $outDir 'chatgpt-ui-capture.txt'

function Get-AllTopWindows {
    $root = [System.Windows.Automation.AutomationElement]::RootElement
    $root.FindAll([System.Windows.Automation.TreeScope]::Children,[System.Windows.Automation.Condition]::TrueCondition)
}

function Score-ChatWindow {
    param($el)
    $score = 0
    try {
        $name = [string]$el.Current.Name
        $pid = [int]$el.Current.ProcessId
        if ($name -match '(?i)chatgpt|openai') { $score += 28 }
        try {
            $p = Get-Process -Id $pid -ErrorAction Stop
            if ($p.ProcessName -match '(?i)chatgpt|openai') { $score += 40 }
            if (($p.ProcessName -match '(?i)chrome|msedge|firefox') -and ($name -match '(?i)chatgpt')) { $score += 16 }
        } catch {}
    } catch {}
    return $score
}

$chat = $null
$best = -1
$chatHandle = [IntPtr]::Zero
$topSummary = New-Object System.Collections.Generic.List[string]

# Prefer the real ChatGPT/OpenAI process main window.
try {
    foreach ($p in @(Get-Process -ErrorAction SilentlyContinue)) {
        try {
            if ($p.ProcessName -match '(?i)chatgpt|openai' -or $p.MainWindowTitle -match '(?i)chatgpt') {
                if ($p.MainWindowHandle -ne 0) {
                    $candidate = [System.Windows.Automation.AutomationElement]::FromHandle([IntPtr]$p.MainWindowHandle)
                    if ($null -ne $candidate) {
                        $chat = $candidate
                        $chatHandle = [IntPtr]$p.MainWindowHandle
                        $best = 100
                        break
                    }
                }
            }
        } catch {}
    }
} catch {}

foreach ($el in (Get-AllTopWindows)) {
    try {
        $name = [string]$el.Current.Name
        $pid = [int]$el.Current.ProcessId
        $proc = ''
        try { $proc = (Get-Process -Id $pid -ErrorAction Stop).ProcessName } catch {}
        $score = Score-ChatWindow $el
        $topSummary.Add("SCORE=$score PID=$pid PROC=[$proc] WINDOW=[$name]")
        if ($null -eq $chat -and $score -gt $best) {
            $best = $score
            $chat = $el
            try { $chatHandle = [IntPtr][int64]$el.Current.NativeWindowHandle } catch {}
        }
    } catch {}
}

if ($null -eq $chat -or $best -lt 24) {
    # Browser-hosted normal ChatGPT fallback. A normal chat can be open in
    # Chrome/Edge while no ChatGPT.exe process exists.
    foreach($candidate in (Get-AllTopWindows)){
        try{
            $pid=[int]$candidate.Current.ProcessId;$proc=(Get-Process -Id $pid -ErrorAction SilentlyContinue).ProcessName
            if($proc -notmatch '(?i)chrome|msedge|firefox|brave|opera' -or $candidate.Current.IsOffscreen){continue}
            $items=$candidate.FindAll([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.Condition]::TrueCondition)
            $hit=$false;for($i=0;$i -lt [Math]::Min($items.Count,2200);$i++){if(([string]$items[$i].Current.Name+' '+[string]$items[$i].Current.AutomationId)-match '(?i)Searching\s+\d+\s+websites|Ask ChatGPT|Message ChatGPT|Stop generating'){ $hit=$true;break }}
            if($hit){$chat=$candidate;$chatHandle=[IntPtr][int64]$candidate.Current.NativeWindowHandle;$best=30;break}
        }catch{}
    }
}
if ($null -eq $chat -or $best -lt 24) {
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('ChatGPT window not found. Keep ChatGPT open and run this again.')
    $lines.Add("Capture time: $(Get-Date)")
    $lines.Add('')
    $lines.Add('===== TOP WINDOWS SEEN =====')
    foreach ($l in $topSummary) { $lines.Add($l) }
    $lines | Set-Content $outFile -Encoding UTF8
    Write-Host 'ChatGPT window not found. Diagnostic top-window list was saved.'
    Write-Host "Output: $outFile"
    exit 1
}

$roots = New-Object System.Collections.Generic.List[object]
$rootKeys = New-Object 'System.Collections.Generic.HashSet[string]'
function Add-CaptureRoot {
    param($Element, [string]$Tag, [IntPtr]$Handle)
    if ($null -eq $Element) { return }
    try {
        $pid = [int]$Element.Current.ProcessId
        $name = [string]$Element.Current.Name
        $class = [string]$Element.Current.ClassName
        $native = [int64]$Element.Current.NativeWindowHandle
        $key = "$native|$pid|$class|$name"
        if ($rootKeys.Add($key)) {
            $roots.Add([pscustomobject]@{
                Element = $Element
                Tag = $Tag
                Handle = [int64]$Handle
                Native = $native
                ProcessId = $pid
                Name = $name
                ClassName = $class
            })
        }
    } catch {}
}

Add-CaptureRoot $chat 'main-uia-root' $chatHandle

# The ChatGPT accessibility tree can live under a Chromium/WebView child HWND.
# Capture every child HWND as its own UIA root so we can see the real controls.
if ($chatHandle -ne [IntPtr]::Zero) {
    try {
        $children = [OrbitCaptureNative]::GetChildWindows($chatHandle)
        $limit = [Math]::Min($children.Length, 160)
        for ($i = 0; $i -lt $limit; $i++) {
            $h = $children[$i]
            try {
                $class = [OrbitCaptureNative]::WindowClass($h)
                $title = [OrbitCaptureNative]::WindowText($h)
                $el = [System.Windows.Automation.AutomationElement]::FromHandle($h)
                if ($null -ne $el) {
                    Add-CaptureRoot $el ("child-hwnd class=[$class] title=[$title]") $h
                }
            } catch {}
        }
    } catch {}
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("Orbit ChatGPT UI capture v0.8.1 - $(Get-Date)")
$lines.Add("Detection score: $best")
$lines.Add("Window: $([string]$chat.Current.Name)")
try { $lines.Add("Process ID: $([int]$chat.Current.ProcessId)") } catch {}
$lines.Add("UI roots: $($roots.Count)")
$lines.Add('')
$lines.Add('===== TOP WINDOWS SEEN =====')
foreach ($l in $topSummary) { $lines.Add($l) }
$lines.Add('')

$signals = New-Object System.Collections.Generic.List[string]
$signalSeen = New-Object 'System.Collections.Generic.HashSet[string]'

$rootIndex = 0
foreach ($rootInfo in $roots) {
    $rootIndex++
    $lines.Add("===== ROOT $rootIndex / $($roots.Count) =====")
    $lines.Add("TAG=[$($rootInfo.Tag)] HWND=[$($rootInfo.Handle)] NATIVE=[$($rootInfo.Native)] PID=[$($rootInfo.ProcessId)] CLASS=[$($rootInfo.ClassName)] NAME=[$($rootInfo.Name)]")

    try {
        $items = $rootInfo.Element.FindAll(
            [System.Windows.Automation.TreeScope]::Descendants,
            [System.Windows.Automation.Condition]::TrueCondition
        )
        $lines.Add("DESCENDANTS=$($items.Count)")

        $typeCounts = @{}
        $max = [Math]::Min($items.Count, 7000)
        for ($i = 0; $i -lt $max; $i++) {
            try {
                $cur = $items[$i].Current
                $typeName = ''
                try { $typeName = [string]$cur.ControlType.ProgrammaticName } catch {}
                if ([string]::IsNullOrWhiteSpace($typeName)) {
                    try { $typeName = [string]$cur.ControlType } catch { $typeName = 'UNKNOWN' }
                }
                if (-not $typeCounts.ContainsKey($typeName)) { $typeCounts[$typeName] = 0 }
                $typeCounts[$typeName]++

                $n = ([string]$cur.Name).Trim()
                $id = ([string]$cur.AutomationId).Trim()
                $cls = ([string]$cur.ClassName).Trim()
                $help = ([string]$cur.HelpText).Trim()
                $enabled = [bool]$cur.IsEnabled
                $off = [bool]$cur.IsOffscreen
                $native = [int64]$cur.NativeWindowHandle
                $rect = $cur.BoundingRectangle
                $left = [double]$rect.Left
                $top = [double]$rect.Top
                $right = [double]$rect.Right
                $bottom = [double]$rect.Bottom
                $width = [double]$rect.Width
                $height = [double]$rect.Height

                # Keep all named elements, all buttons, and anything carrying IDs/help.
                $important = (-not [string]::IsNullOrWhiteSpace($n)) -or
                             (-not [string]::IsNullOrWhiteSpace($id)) -or
                             (-not [string]::IsNullOrWhiteSpace($help)) -or
                             ($typeName -match '(?i)button|edit|document|pane|group')
                if ($important) {
                    $lines.Add("TYPE=[$typeName] NAME=[$n] ID=[$id] HELP=[$help] CLASS=[$cls] ENABLED=[$enabled] OFFSCREEN=[$off] HWND=[$native] RECT=[$left,$top,$right,$bottom] SIZE=[$width x $height]")
                }

                $signalText = ($n + ' ' + $id + ' ' + $help).Trim()
                if ($signalText -match '(?i)thinking|working|searching|reading|analy|generat|stop|interrupt|cancel|failed|error|stopped|paused|work with chatgpt|message chatgpt|ask anything') {
                    $sig = "ROOT=$rootIndex TYPE=[$typeName] SIGNAL=[$signalText] RECT=[$left,$top,$right,$bottom] ENABLED=[$enabled] OFFSCREEN=[$off]"
                    if ($signalSeen.Add($sig)) { $signals.Add($sig) }
                }
            } catch {}
        }

        $lines.Add('--- CONTROL TYPE COUNTS ---')
        foreach ($k in @($typeCounts.Keys | Sort-Object)) {
            $lines.Add("$k = $($typeCounts[$k])")
        }
    } catch {
        $lines.Add("ROOT_SCAN_ERROR=[$($_.Exception.Message)]")
    }
    $lines.Add('')
}

$header = New-Object System.Collections.Generic.List[string]
$header.Add('===== DETECTION SIGNALS FOUND =====')
if ($signals.Count -eq 0) {
    $header.Add('No obvious state text/button signal was exposed by UI Automation.')
} else {
    foreach ($sig in $signals) { $header.Add($sig) }
}
$header.Add('')
$header.Add('===== FULL ACCESSIBILITY DUMP =====')
$header.Add('')

@($header + $lines) | Set-Content $outFile -Encoding UTF8
Write-Host 'Captured ChatGPT UI Automation tree, including child WebView/Chromium HWND roots.'
Write-Host "Output: $outFile"
Write-Host "Roots captured: $($roots.Count)"
