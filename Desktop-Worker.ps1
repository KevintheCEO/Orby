param($Shared,[string]$BaseDirectory,[string]$DataDirectory)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Runtime.WindowsRuntime,System.Windows.Forms,UIAutomationClient,UIAutomationTypes,System.Net.Http
function Await-WinRt {
    param($Operation,[type]$Type)
    $method=[System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {$_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'} | Select-Object -First 1
    $task=$method.MakeGenericMethod($Type).Invoke($null,@($Operation))
    if(-not $task.Wait(2500)){throw 'Connection timed out'}
    return $task.Result
}
. (Join-Path $BaseDirectory 'Media-Stream.ps1')
$manager=$null;$notificationListener=$null
try {
    [void][Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager,Windows.Media.Control,ContentType=WindowsRuntime]
    $manager=Await-WinRt ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]::RequestAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager])
} catch {$Shared.MediaError='Media connection: '+$_.Exception.GetBaseException().Message}
try {
    [void][Windows.UI.Notifications.Management.UserNotificationListener,Windows.UI.Notifications,ContentType=WindowsRuntime]
    $notificationListener=[Windows.UI.Notifications.Management.UserNotificationListener]::Current
    $Shared.NotificationMode=[string]$notificationListener.GetAccessStatus()
} catch {$Shared.NotificationMode='Visible Windows banners only'}
$artKey='';$artBytes=$null;$artAt=[datetime]::MinValue
$lastManager=[datetime]::MinValue
$lastMedia=[datetime]::MinValue;$lastNews=[datetime]::MinValue;$lastToast=[datetime]::MinValue
$seenNews=@{};$newsSeeded=@{};$seenToasts=@{}
$previousCpu=$null
try{$cpu=New-Object Diagnostics.PerformanceCounter 'Processor','% Processor Time','_Total';[void]$cpu.NextValue()}catch{$cpu=$null}
$client=New-Object Net.Http.HttpClient
$client.Timeout=[timespan]::FromSeconds(8)
$client.DefaultRequestHeaders.UserAgent.ParseAdd('Orby/2.0 desktop-companion')
while(-not $Shared.Stop){
    $now=[datetime]::UtcNow
    $settings=$Shared.Settings
    try {
        $power=[Windows.Forms.SystemInformation]::PowerStatus
        $battery=$null
        if($power.BatteryChargeStatus.ToString() -notmatch 'NoSystemBattery|Unknown' -and $power.BatteryLifePercent -ge 0){$battery=[Math]::Round($power.BatteryLifePercent*100)}
        $cpuValue=$null;if($cpu){$cpuValue=[Math]::Round($cpu.NextValue())}
        $Shared.Health=[pscustomobject]@{Battery=$battery;Charging=($power.PowerLineStatus.ToString() -eq 'Online');Cpu=$cpuValue;Network=[Net.NetworkInformation.NetworkInterface]::GetIsNetworkAvailable();At=$now}
    } catch {$Shared.HealthError=$_.Exception.Message}
    $command=$null
    while($Shared.Commands.TryDequeue([ref]$command)){
        try{
            $session=$null
            if($manager){
                if($settings.MediaApp){$session=@($manager.GetSessions() | Where-Object {$_.SourceAppUserModelId -eq $settings.MediaApp}) | Select-Object -First 1}
                if(-not $session){$session=$manager.GetCurrentSession()}
            }
            if($session -and $command -in @('play','next','previous')){
                $op=switch($command){play{$session.TryTogglePlayPauseAsync()}next{$session.TrySkipNextAsync()}previous{$session.TrySkipPreviousAsync()}}
                $ok=Await-WinRt $op ([bool]);if(-not $ok){throw 'The media app declined this control'}
            }else{
                $key=switch($command){play{0xB3}next{0xB0}previous{0xB1}mute{0xAD}volumeup{0xAF}volumedown{0xAE}}
                if($key){[OrbyDesktopNative]::Key([byte]$key)}
            }
            $Shared.CommandResult='Control sent'
        }catch{$Shared.CommandResult=$_.Exception.Message}
    }
    if($settings.Notifications -and ($now-$lastToast).TotalSeconds -ge 2){
        $lastToast=$now
        try{
            $notifications=@()
            $allowed=$false
            if($notificationListener){try{$allowed=$notificationListener.GetAccessStatus().ToString() -eq 'Allowed'}catch{}}
            if($allowed){
                $type=[System.Collections.Generic.IReadOnlyList[Windows.UI.Notifications.UserNotification]]
                $items=Await-WinRt ($notificationListener.GetNotificationsAsync([Windows.UI.Notifications.NotificationKinds]::Toast)) $type
                foreach($item in $items){
                    try{
                        if($item.CreationTime.UtcDateTime -lt $Shared.Started){continue}
                        $binding=$item.Notification.Visual.GetBinding('ToastGeneric')
                        $texts=@($binding.GetTextElements() | ForEach-Object {$_.Text})
                        $notifications += [pscustomobject]@{Id=[string]$item.Id;App=$item.AppInfo.DisplayInfo.DisplayName;Title=($texts | Select-Object -First 1);Body=($texts | Select-Object -Skip 1) -join ' ';At=$item.CreationTime.UtcDateTime}
                    }catch{}
                }
                $Shared.NotificationMode='Windows notification listener'
            }else{
                # Unpackaged builds can read accessible, currently visible toast banners.
                $root=[Windows.Automation.AutomationElement]::RootElement
                $windows=$root.FindAll([Windows.Automation.TreeScope]::Children,[Windows.Automation.Condition]::TrueCondition)
                foreach($w in $windows){
                    if($w.Current.IsOffscreen -or $w.Current.ClassName -notmatch 'Toast|Notification' -and $w.Current.Name -notmatch 'New notification|Notification from'){continue}
                    $condition=New-Object Windows.Automation.PropertyCondition ([Windows.Automation.AutomationElement]::ControlTypeProperty),([Windows.Automation.ControlType]::Text)
                    $texts=@($w.FindAll([Windows.Automation.TreeScope]::Descendants,$condition) | ForEach-Object {$_.Current.Name} | Where-Object {$_})
                    if($texts.Count -lt 2){continue}
                    $notifications += [pscustomobject]@{Id=($texts -join '|');App=$texts[0];Title=$texts[1];Body=($texts | Select-Object -Skip 2) -join ' ';At=$now}
                }
                $Shared.NotificationMode='Visible Windows banners only'
            }
            foreach($n in $notifications){
                $filters=@($settings.NotificationApps -split ',' | ForEach-Object {$_.Trim()} | Where-Object {$_})
                if($filters.Count -and -not @($filters | Where-Object {$n.App.IndexOf($_,[StringComparison]::OrdinalIgnoreCase) -ge 0}).Count){continue}
                if(-not $seenToasts.ContainsKey($n.Id)){$seenToasts[$n.Id]=$true;$Shared.Events.Enqueue(@{Kind='notification';Title=$n.App;Detail=($n.Title+' '+$n.Body).Trim();At=$now;Url=''})}
            }
            $Shared.NotificationError=''
        }catch{$Shared.NotificationError='Windows banner access unavailable'}
    }
    # Topics are sent only after explicit opt-in to this named provider.
    if($settings.Watchlist -and $settings.AllowPublicNews -and ($now-$lastNews).TotalMinutes -ge 5){
        $lastNews=$now
        $news=New-Object System.Collections.Generic.List[object]
        $watchAlerts=0
        $errors=New-Object System.Collections.Generic.List[string]
        foreach($topic in @($settings.WatchTopics -split ',' | ForEach-Object {$_.Trim()} | Where-Object {$_} | Select-Object -First 10)){
            try{
                $query=[uri]::EscapeDataString($topic+' stock earnings when:1d')
                $url='https://news.google.com/rss/search?q='+$query+'&hl=en-US&gl=US&ceid=US:en'
                $text=$client.GetStringAsync($url).GetAwaiter().GetResult()
                $readerSettings=New-Object Xml.XmlReaderSettings;$readerSettings.DtdProcessing='Prohibit';$readerSettings.XmlResolver=$null
                $reader=[Xml.XmlReader]::Create((New-Object IO.StringReader $text),$readerSettings)
                $doc=New-Object Xml.XmlDocument;try{$doc.Load($reader)}finally{$reader.Dispose()}
                foreach($item in @($doc.SelectNodes('//item') | Select-Object -First 5)){
                    $title=[string]$item.title;$link=[string]$item.link
                    if(-not $link.StartsWith('https://')){continue}
                    $key=$topic+'|'+$link
                    $row=[pscustomobject]@{Topic=$topic;Title=$title;Url=$link;At=$now;Published=[string]$item.pubDate}
                    $news.Add($row)
                    if($newsSeeded[$topic] -and -not $seenNews.ContainsKey($key) -and $watchAlerts -lt 3){$Shared.Events.Enqueue(@{Kind='watch';Title=$topic+' update';Detail=$title;At=$now;Url=$link});$watchAlerts++}
                    $seenNews[$key]=$true
                }
                $newsSeeded[$topic]=$true
            }catch{$errors.Add($topic+': feed unavailable')}
        }
        $Shared.News=$news.ToArray();$Shared.WatchError=$errors -join '; ';$Shared.WatchAt=$now
    }
    Start-Sleep -Milliseconds 900
}
$client.Dispose();if($cpu){$cpu.Dispose()}
