Add-Type -AssemblyName System.Windows.Forms,System.Drawing,System.Net.Http
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class OrbyDesktopNative {
 [DllImport("user32.dll")] static extern void keybd_event(byte key,byte scan,uint flags,UIntPtr extra);
 public static void Key(byte key){keybd_event(key,0,0,UIntPtr.Zero);keybd_event(key,0,2,UIntPtr.Zero);}
 public static void Hotkey(byte modifier,byte key){keybd_event(modifier,0,0,UIntPtr.Zero);Key(key);keybd_event(modifier,0,2,UIntPtr.Zero);}
}
'@
$script:orbySettingsPath=Join-Path $logDir 'settings.json'
$script:orbyReminderPath=Join-Path $logDir 'reminders.json'
$script:orbyAlertPath=Join-Path $logDir 'alerts.json'
$script:orbySettings=[ordered]@{ReducedMotion=$false;Music=$true;Health=$true;Notifications=$true;Downloads=$true;Tasks=$true;Watchlist=$true;AllowPublicNews=$false;NotificationApps='';MediaApp='';WatchTopics='';DownloadFolder='';Quiet=$false;Preview=$true;StartWithWindows=$true;FocusMinutes=25;BreakMinutes=0;Favorites=@()}
$script:orbySettings['Sounds']=$true
try{if(Test-Path -LiteralPath $script:orbySettingsPath){$saved=Get-Content $script:orbySettingsPath -Raw | ConvertFrom-Json;foreach($key in @($script:orbySettings.Keys)){if($saved.PSObject.Properties[$key]){$script:orbySettings[$key]=$saved.$key}}}}catch{Write-OrbitLog 'Settings could not be read; using defaults'}
if(-not $script:orbySettings.DownloadFolder){
    try{$path=(Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders').'{374DE290-123F-4565-9164-39C4925E467B}';$script:orbySettings.DownloadFolder=[Environment]::ExpandEnvironmentVariables($path)}catch{}
    if(-not $script:orbySettings.DownloadFolder){$script:orbySettings.DownloadFolder=Join-Path $env:USERPROFILE 'Downloads'}
}
function Set-OrbyStartupRegistration {
    param([bool]$Enabled)
    try {
        $runKey='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
        $name='Orby'
        if($Enabled){
            $path=Join-Path $PSScriptRoot 'Start-Orby.cmd'
            $value='cmd.exe /c ""'+$path+'""'
            New-Item -Path $runKey -Force | Out-Null
            Set-ItemProperty -Path $runKey -Name $name -Value $value
            $script:orbyStartupStatus='Starts with Windows'
        } else {
            Remove-ItemProperty -Path $runKey -Name $name -ErrorAction SilentlyContinue
            $script:orbyStartupStatus='Manual start'
        }
    } catch {
        $script:orbyStartupStatus='Startup setting unavailable'
        Write-OrbitLog ('Startup registration warning: '+$_.Exception.Message)
    }
}
Set-OrbyStartupRegistration ([bool]$script:orbySettings.StartWithWindows)
$script:orbyReminders=New-Object System.Collections.Generic.List[object]
try{if(Test-Path -LiteralPath $script:orbyReminderPath){foreach($r in @(Get-Content $script:orbyReminderPath -Raw | ConvertFrom-Json)){if($r -and -not $r.Done){$script:orbyReminders.Add($r)}}}}catch{}
$script:orbyAlerts=New-Object System.Collections.Generic.List[object]
try{if(Test-Path -LiteralPath $script:orbyAlertPath){foreach($a in @(Get-Content $script:orbyAlertPath -Raw | ConvertFrom-Json)){if($a){$script:orbyAlerts.Add($a)}}}}catch{}
$script:orbyDownloads=@{};$script:orbyDownloadStarted=[datetime]::UtcNow
$script:orbyDownloadAt=[datetime]::MinValue;$script:orbyHealthFlags=@{}
$script:orbyBannerUntil=[datetime]::MinValue;$script:orbyBanner=$null;$script:orbyFocusEnd=[datetime]::MinValue
$script:orbyNextBreak=[datetime]::UtcNow
$script:orbyShared=[hashtable]::Synchronized(@{Stop=$false;Started=[datetime]::UtcNow;Settings=[pscustomobject]$script:orbySettings;Events=(New-Object 'System.Collections.Concurrent.ConcurrentQueue[object]');Commands=(New-Object 'System.Collections.Concurrent.ConcurrentQueue[string]');Media=$null;Health=$null;News=@();MediaApps=@();NotificationMode='Connecting';MediaError='Connecting';WatchError='';NotificationError='';WatchAt=$null})

$script:orbyShared.SpotifyCommands=New-Object 'System.Collections.Concurrent.ConcurrentQueue[object]'
function Save-OrbyJson {param($Value,[string]$Path) $json=ConvertTo-Json -InputObject $Value -Depth 7;[IO.File]::WriteAllText($Path+'.tmp',$json,(New-Object Text.UTF8Encoding $false));Move-Item -LiteralPath ($Path+'.tmp') -Destination $Path -Force}
function Save-OrbySettings {Save-OrbyJson ([pscustomobject]$script:orbySettings) $script:orbySettingsPath;$script:orbyShared.Settings=[pscustomobject]$script:orbySettings}
function Save-OrbyReminders {Save-OrbyJson @($script:orbyReminders.ToArray()) $script:orbyReminderPath}
function Add-OrbyAlert {
    param([string]$Kind,[string]$Title,[string]$Detail,[string]$Url='')
    $record=[pscustomobject]@{Id=[guid]::NewGuid().ToString('N');Kind=$Kind;Title=$Title;Detail=$Detail;At=[datetime]::UtcNow.ToString('o');Url=$Url;Read=$false}
    if($script:avatarRenderer -and $Kind -in @('notification','reminder','break','health','download','file')){
        $motion=if($Kind -eq 'break'){'coffee_break'}elseif($Kind -eq 'download'){'notification'}elseif($Kind -eq 'health' -and $Title -match 'Battery'){'battery_warning'}elseif($Kind -eq 'health' -and $Title -match 'Network'){'internet_lost'}else{'notification'}
        [void]$script:avatarRenderer.Trigger($motion)
        if($script:referenceRenderer){[void]$script:referenceRenderer.Trigger($motion)}
    }
    $script:orbyAlerts.Insert(0,$record)
    while($script:orbyAlerts.Count -gt 80){$script:orbyAlerts.RemoveAt($script:orbyAlerts.Count-1)}
    Save-OrbyJson @($script:orbyAlerts.ToArray()) $script:orbyAlertPath
    if(-not $script:orbySettings.Quiet){$script:orbyBanner=$record;$script:orbyBannerUntil=[datetime]::UtcNow.AddSeconds(8)}
}

function Add-OrbyReminder {
    param([string]$Title,[int]$Minutes)
    if(-not $Title.Trim() -or $Minutes -lt 1 -or $Minutes -gt 10080){throw 'Enter a name and 1 to 10080 minutes'}
    $script:orbyReminders.Add([pscustomobject]@{Id=[guid]::NewGuid().ToString('N');Title=$Title.Trim();Due=[datetime]::UtcNow.AddMinutes($Minutes).ToString('o');Done=$false})
    Save-OrbyReminders
}

function Update-OrbyLocal {
    param([datetime]$Now=[datetime]::UtcNow)
    $event=$null
    while($script:orbyShared.Events.TryDequeue([ref]$event)){Add-OrbyAlert $event.Kind $event.Title $event.Detail $event.Url}
    foreach($r in $script:orbyReminders){if(-not $r.Done -and [datetimeoffset]::Parse($r.Due).UtcDateTime -le $Now){$r.Done=$true;Add-OrbyAlert 'reminder' $r.Title 'Your reminder is due';Save-OrbyReminders}}
    if($script:orbyFocusEnd -ne [datetime]::MinValue -and $Now -ge $script:orbyFocusEnd){$script:orbyFocusEnd=[datetime]::MinValue;Add-OrbyAlert 'focus' 'Focus complete' 'Time for a short break'}
    if($script:orbySettings.BreakMinutes -gt 0 -and $Now -ge $script:orbyNextBreak){$script:orbyNextBreak=$Now.AddMinutes($script:orbySettings.BreakMinutes);Add-OrbyAlert 'break' 'Stretch break' 'Look away from the screen and move a little'}
    if($script:orbySettings.Health -and $script:orbyShared.Health){
        $h=$script:orbyShared.Health
        $conditions=@{battery=($null -ne $h.Battery -and $h.Battery -le 20 -and -not $h.Charging);network=(-not $h.Network);cpu=($null -ne $h.Cpu -and $h.Cpu -ge 90)}
        foreach($key in $conditions.Keys){
            if($conditions[$key] -and -not $script:orbyHealthFlags[$key]){
                $label=switch($key){battery{'Battery low'}network{'Network disconnected'}cpu{'Computer is busy'}}
                Add-OrbyAlert 'health' $label ('CPU '+$h.Cpu+'% | Battery '+$h.Battery+'%')
            }
            $script:orbyHealthFlags[$key]=$conditions[$key]
        }
    }
    if($script:orbySettings.Downloads -and ($Now-$script:orbyDownloadAt).TotalSeconds -ge 2){
        $script:orbyDownloadAt=$Now;$folder=$script:orbySettings.DownloadFolder
        if(Test-Path -LiteralPath $folder){
            foreach($file in @(Get-ChildItem -LiteralPath $folder -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 200)){
                $key=$file.FullName;$old=$script:orbyDownloads[$key]
                if(-not $old){$script:orbyDownloads[$key]=@{Length=$file.Length;Changed=$Now;Announced=($file.LastWriteTimeUtc -lt $script:orbyDownloadStarted);Partial=($file.Name -match '\.(crdownload|part|partial|download|tmp)$')};continue}
                if($old.Length -ne $file.Length){$old.Length=$file.Length;$old.Changed=$Now}
                if(-not $old.Partial -and -not $old.Announced -and ($Now-$old.Changed).TotalSeconds -ge 4){$old.Announced=$true;Add-OrbyAlert 'download' 'File ready' $file.Name}
            }
            foreach($key in @($script:orbyDownloads.Keys)){if(-not (Test-Path -LiteralPath $key)){$script:orbyDownloads.Remove($key)}}
        }
    }
}

function Get-OrbyDownloads {
    return @($script:orbyDownloads.GetEnumerator() | Where-Object {$_.Value.Partial} | ForEach-Object {([IO.Path]::GetFileName($_.Key))+' - '+[Math]::Round($_.Value.Length/1MB,1)+' MB received'})
}

function Get-OrbyStatus {
    $now=[datetime]::UtcNow
    if($script:orbySettings.Tasks -and $script:chatLogState -in @('working','attention','success','error','stopped')){return $null}
    if($script:orbyBanner -and $now -lt $script:orbyBannerUntil){$d=$script:orbyBanner.Detail;if(-not $script:orbySettings.Preview){$d='Hover to view your alerts'};return @{Title=$script:orbyBanner.Title;Detail=$d;Tiny='NEW';Pet='notification';Color='#BCA7FF'}}
    if($script:orbyFocusEnd -gt $now){return @{Title='Focus time';Detail=([Math]::Ceiling(($script:orbyFocusEnd-$now).TotalMinutes).ToString()+' minutes left');Tiny='FOCUS';Pet='working';Color='#8DD7FF'}}
    $downloads=@(Get-OrbyDownloads)
    if($script:orbySettings.Downloads -and $downloads.Count){return @{Title='Downloading';Detail=$downloads[0];Tiny='FILE';Pet='working';Color='#8DD7FF'}}
    if($script:orbySettings.Music -and $script:orbyShared.Media -and $script:orbyShared.Media.Playing){$m=$script:orbyShared.Media;return @{Title=$m.Title;Detail=$m.Artist;Tiny='MUSIC';Pet='music';Color='#78FFAE'}}
    return @{Title='Orby';Detail='Hover for music, alerts and quick actions';Tiny='IDLE';Pet='idle';Color='#767676'}
}

function Start-OrbyWorker {
    $script:orbyRunspace=[runspacefactory]::CreateRunspace();$script:orbyRunspace.ApartmentState='STA';$script:orbyRunspace.ThreadOptions='ReuseThread';$script:orbyRunspace.Open()
    $script:orbyWorker=[powershell]::Create();$script:orbyWorker.Runspace=$script:orbyRunspace
    [void]$script:orbyWorker.AddScript([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Desktop-Worker.ps1'))).AddArgument($script:orbyShared).AddArgument($PSScriptRoot).AddArgument($logDir)
    $script:orbyWorkerHandle=$script:orbyWorker.BeginInvoke()
    $script:mediaRunspace=[runspacefactory]::CreateRunspace();$script:mediaRunspace.ApartmentState='STA';$script:mediaRunspace.Open()
    $script:mediaWorker=[powershell]::Create();$script:mediaWorker.Runspace=$script:mediaRunspace
    [void]$script:mediaWorker.AddScript([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Media-Worker.ps1'))).AddArgument($script:orbyShared).AddArgument($PSScriptRoot).AddArgument($logDir)
    $script:mediaWorkerHandle=$script:mediaWorker.BeginInvoke()

}

function Invoke-OrbyQuickAction {
    param([string]$Action)
    switch($Action){
        downloads{Start-Process explorer.exe -ArgumentList ('"'+$script:orbySettings.DownloadFolder+'"') -WindowStyle Normal}
        files{Start-Process explorer.exe -WindowStyle Normal}
        notifications{[OrbyDesktopNative]::Hotkey(0x5B,0x4E)}
        screenshot{
            $folder=Join-Path $logDir 'Screenshots';[void][IO.Directory]::CreateDirectory($folder)
            $rect=[Windows.Forms.SystemInformation]::VirtualScreen
            $bitmap=New-Object Drawing.Bitmap $rect.Width,$rect.Height
            $graphics=[Drawing.Graphics]::FromImage($bitmap)
            try{$graphics.CopyFromScreen($rect.Left,$rect.Top,0,0,$bitmap.Size);$path=Join-Path $folder ('Orby-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'.png');$bitmap.Save($path,[Drawing.Imaging.ImageFormat]::Png)}finally{$graphics.Dispose();$bitmap.Dispose()}
            Add-OrbyAlert 'screenshot' 'Screenshot saved' $path
        }
        mute{$script:orbyShared.Commands.Enqueue('mute')}
        focus{if($script:orbyFocusEnd -eq [datetime]::MinValue){$script:orbyFocusEnd=[datetime]::UtcNow.AddMinutes($script:orbySettings.FocusMinutes)}else{$script:orbyFocusEnd=[datetime]::MinValue}}
    }
}
