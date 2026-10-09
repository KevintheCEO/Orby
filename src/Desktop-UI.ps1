function New-OrbyPanel {
    [xml]$xml=(Get-Content -LiteralPath (Join-Path $PSScriptRoot 'Desktop-Panel.xaml') -Raw).Replace('<Storyboard>',('<Storyboard Timeline.DesiredFrameRate="'+$(if($script:displayHz -gt 0){$script:displayHz}else{60})+'">'))
    $root=[Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader $xml))
    $script:desktopControls=@{Root=$root}
    foreach($name in @('DesktopTabs','MusicTitle','MusicDetail','MediaPrevious','MediaPlay','MediaNext','VolumeDown','VolumeUp','MuteAudio','HealthSummary','OpenDownloads','DownloadSummary','OpenFiles','FavoriteApps','TakeScreenshot','FocusToggle','OpenSettings','ConnectionNote','QuietToggle','MarkAlertsRead','TestAlert','ShowWindowsNotifications','AlertList','OpenAlertLink','NotificationConnection','ReminderTitle','ReminderMinutes','AddReminder','PlannerMessage','ReminderList','RemoveReminder','PlannerFocus','FocusSummary','WatchTopics','SaveWatchTopics','NewsList','OpenNews','WatchStatus','FileDropZone','ShelfMessage','ShelfList','ShelfAdd','ShelfReveal','ShelfFolder')){$script:desktopControls[$name]=$root.FindName($name)}
    $d=$script:desktopControls
    $d.DesktopTabs.Add_SelectionChanged({param($sender,$args)
        if($args.OriginalSource -ne $sender -or $PreviewDirectory){return}
        $selected=$sender.SelectedItem
        if($selected -and $selected.Content -is [Windows.UIElement]){
            $content=$selected.Content
            $content.RenderTransform=New-Object Windows.Media.TranslateTransform 0,7
            $content.Opacity=0.4
            Invoke-OrbyMotion $content ([Windows.UIElement]::OpacityProperty) 1 0.23
            Invoke-OrbyMotion $content.RenderTransform ([Windows.Media.TranslateTransform]::YProperty) 0 0.23
        }
    })
    $d.WatchTopics.Text=$script:orbySettings.WatchTopics
    $d.MediaPrevious.Add_Click({$script:orbyShared.Commands.Enqueue('previous')})
    $d.MediaPlay.Add_Click({$script:orbyShared.Commands.Enqueue('play')})
    $d.MediaNext.Add_Click({$script:orbyShared.Commands.Enqueue('next')})
    $d.VolumeDown.Add_Click({if($script:avatarRenderer){[void]$script:avatarRenderer.Trigger('volume_change');[void]$script:referenceRenderer.Trigger('volume_change')};$script:orbyShared.Commands.Enqueue('volumedown')})
    $d.VolumeUp.Add_Click({if($script:avatarRenderer){[void]$script:avatarRenderer.Trigger('volume_change');[void]$script:referenceRenderer.Trigger('volume_change')};$script:orbyShared.Commands.Enqueue('volumeup')})
    $d.MuteAudio.Add_Click({Invoke-OrbyQuickAction 'mute'})
    $d.OpenDownloads.Add_Click({Invoke-OrbyQuickAction 'downloads'})
    $d.OpenFiles.Add_Click({Invoke-OrbyQuickAction 'files'})
    $d.FavoriteApps.Add_Click({
        $menu=New-Object Windows.Controls.ContextMenu
        foreach($app in @($script:orbySettings.Favorites)){
            $item=New-Object Windows.Controls.MenuItem;$item.Header=$app.Name;$item.Tag=$app.Path
            $item.Add_Click({param($sender,$eventArgs) if(Test-Path -LiteralPath $sender.Tag){Start-Process -FilePath $sender.Tag -WindowStyle Normal}})
            [void]$menu.Items.Add($item)
        }
        if($menu.Items.Count -eq 0){Show-OrbySettings}else{$script:desktopControls.FavoriteApps.ContextMenu=$menu;$menu.IsOpen=$true}
    })
    $d.TakeScreenshot.Add_Click({try{Invoke-OrbyQuickAction 'screenshot'}catch{Add-OrbyAlert 'error' 'Screenshot failed' $_.Exception.Message}})
    $d.FocusToggle.Add_Click({Invoke-OrbyQuickAction 'focus';Update-OrbyPanel})
    $d.PlannerFocus.Add_Click({Invoke-OrbyQuickAction 'focus';Update-OrbyPanel})
    $d.OpenSettings.Add_Click({Show-OrbySettings})
    $d.QuietToggle.Add_Click({$script:orbySettings.Quiet=-not $script:orbySettings.Quiet;Save-OrbySettings;Update-OrbyPanel})
    $d.MarkAlertsRead.Add_Click({foreach($a in $script:orbyAlerts){$a.Read=$true};Save-OrbyJson @($script:orbyAlerts.ToArray()) $script:orbyAlertPath;Update-OrbyPanel})
    $d.TestAlert.Add_Click({Add-OrbyAlert 'test' 'Hello from Orby' 'Your local alert inbox is working';Update-OrbyPanel})
    $d.ShowWindowsNotifications.Add_Click({Invoke-OrbyQuickAction 'notifications'})
    $d.OpenAlertLink.Add_Click({$item=$script:desktopControls.AlertList.SelectedItem;if($item -and $item.Url -match '^https://'){Start-Process $item.Url}})
    $d.AddReminder.Add_Click({
        try{$minutes=0;if(-not [int]::TryParse($script:desktopControls.ReminderMinutes.Text,[ref]$minutes)){throw 'Enter minutes as a number'};Add-OrbyReminder $script:desktopControls.ReminderTitle.Text $minutes;$script:desktopControls.PlannerMessage.Text='Reminder saved';Update-OrbyPanel}catch{$script:desktopControls.PlannerMessage.Text=$_.Exception.Message}
    })
    $d.RemoveReminder.Add_Click({$selected=$script:desktopControls.ReminderList.SelectedItem;if($selected){$found=@($script:orbyReminders | Where-Object {$_.Id -eq $selected.Id})|Select-Object -First 1;if($found){[void]$script:orbyReminders.Remove($found);Save-OrbyReminders;Update-OrbyPanel}}})
    $d.SaveWatchTopics.Add_Click({$script:orbySettings.WatchTopics=$script:desktopControls.WatchTopics.Text.Trim();Save-OrbySettings;$script:desktopControls.WatchStatus.Text='Saved; checking on the next feed refresh'})
    $d.OpenNews.Add_Click({$selected=$script:desktopControls.NewsList.SelectedItem;if($selected -and $selected.Url -match '^https://'){Start-Process $selected.Url}})
    $root.AllowDrop=$true
    $d.FileDropZone.Add_PreviewDragOver({param($sender,$dropEvent)
        if($dropEvent.Data.GetDataPresent([Windows.DataFormats]::FileDrop)){
            $dropEvent.Effects=[Windows.DragDropEffects]::Copy;$dropEvent.Handled=$true
            $script:desktopControls.FileDropZone.BorderBrush=[Windows.Media.BrushConverter]::new().ConvertFromString('#34D399')
        }
    })
    $d.FileDropZone.Add_DragLeave({$script:desktopControls.FileDropZone.BorderBrush=[Windows.Media.BrushConverter]::new().ConvertFromString('#34383E')})
    $d.FileDropZone.Add_Drop({param($sender,$dropEvent)
        if($dropEvent.Data.GetDataPresent([Windows.DataFormats]::FileDrop)){
            foreach($path in $dropEvent.Data.GetData([Windows.DataFormats]::FileDrop)){Add-OrbyShelfFile $path}
            $script:desktopControls.DesktopTabs.SelectedIndex=4;Show-OrbyTools;$dropEvent.Handled=$true
            $script:desktopControls.FileDropZone.BorderBrush=[Windows.Media.BrushConverter]::new().ConvertFromString('#34383E')
        }
    })
    $d.ShelfAdd.Add_Click({$dialog=New-Object Windows.Forms.OpenFileDialog;$dialog.Multiselect=$true;if($dialog.ShowDialog() -eq 'OK'){foreach($path in $dialog.FileNames){Add-OrbyShelfFile $path}};$dialog.Dispose()})
    $d.ShelfFolder.Add_Click({[void][IO.Directory]::CreateDirectory($script:orbyInbox);Start-Process explorer.exe -ArgumentList ('"'+$script:orbyInbox+'"')})
    $d.ShelfReveal.Add_Click({$selected=$script:desktopControls.ShelfList.SelectedItem;if($selected -and (Test-Path -LiteralPath $selected.Path)){Start-Process explorer.exe -ArgumentList ('/select,"'+$selected.Path+'"')}})
    return $root
}

function Update-OrbyPanel {
    $d=$script:desktopControls;if(-not $d){return}
    Update-OrbyShelf
    $media=$script:orbyShared.Media
    if($script:orbySettings.Music -and $media){$d.MusicTitle.Text=$media.Title;$d.MusicDetail.Text=($media.Artist+' | '+$media.App).Trim(' ','|');$d.MediaPlay.Content=if($media.Playing){'Pause'}else{'Play'}}
    else{$d.MusicTitle.Text=if($script:orbySettings.Music){'No song connected'}else{'Music connection is off'};$d.MusicDetail.Text=$script:orbyShared.MediaError;$d.MediaPlay.Content='Play / pause'}
    $h=$script:orbyShared.Health
    if($h -and $script:orbySettings.Health){
        $battery=if($null -eq $h.Battery){'Desktop power'}else{'Battery '+$h.Battery+'%'}
        $network=if($h.Network){'Network connected'}else{'Network disconnected'}
        $cpu=if($null -eq $h.Cpu){'CPU unavailable'}else{'CPU '+$h.Cpu+'%'}
        $d.HealthSummary.Text="$network   |   $battery   |   $cpu"
    }else{$d.HealthSummary.Text='Computer health connection is off or unavailable'}
    $downloads=@(Get-OrbyDownloads);$d.DownloadSummary.Text=if($downloads.Count){$downloads -join ' / '}else{'Watching '+$script:orbySettings.DownloadFolder}
    $d.FocusToggle.Content=if($script:orbyFocusEnd -gt [datetime]::UtcNow){'Stop focus'}else{'Start focus'}
    $d.FocusSummary.Text=if($script:orbyFocusEnd -gt [datetime]::UtcNow){'Focus: '+[Math]::Ceiling(($script:orbyFocusEnd-[datetime]::UtcNow).TotalMinutes)+' minutes remaining'}else{'Focus timer is off'}
    $d.QuietToggle.Content=if($script:orbySettings.Quiet){'Quiet mode: on'}else{'Quiet mode: off'}
    $d.NotificationConnection.Text=$script:orbyShared.NotificationMode
    if($script:orbyShared.NotificationError){$d.NotificationConnection.Text=$script:orbyShared.NotificationError}
    $selectedAlert=$d.AlertList.SelectedItem.Id;$selectedReminder=$d.ReminderList.SelectedItem.Id;$selectedNews=$d.NewsList.SelectedItem.Url
    $alertSignature=($script:orbyAlerts | ForEach-Object {$_.Id+':'+$_.Read}) -join '|'
    if($alertSignature -ne $script:lastAlertSignature){$script:lastAlertSignature=$alertSignature
    $d.AlertList.ItemsSource=@($script:orbyAlerts | ForEach-Object {[pscustomobject]@{Id=$_.Id;Url=$_.Url;Display=($(if($_.Read){''}else{'* '})+$_.Title+' - '+$_.Detail)}})
    $d.AlertList.SelectedItem=@($d.AlertList.Items | Where-Object {$_.Id -eq $selectedAlert}) | Select-Object -First 1
    }
    $reminderSignature=($script:orbyReminders | Where-Object {-not $_.Done} | ForEach-Object {$_.Id+':'+$_.Due}) -join '|'
    if($reminderSignature -ne $script:lastReminderSignature){$script:lastReminderSignature=$reminderSignature
    $d.ReminderList.ItemsSource=@($script:orbyReminders | Where-Object {-not $_.Done} | ForEach-Object {[pscustomobject]@{Id=$_.Id;Display=$_.Title+' - '+([datetimeoffset]::Parse($_.Due).LocalDateTime.ToString('ddd HH:mm'))}})
    $d.ReminderList.SelectedItem=@($d.ReminderList.Items | Where-Object {$_.Id -eq $selectedReminder}) | Select-Object -First 1
    }
    $newsSignature=($script:orbyShared.News | ForEach-Object {$_.Url}) -join '|'
    if($newsSignature -ne $script:lastNewsSignature){$script:lastNewsSignature=$newsSignature
    $d.NewsList.ItemsSource=@($script:orbyShared.News | ForEach-Object {[pscustomobject]@{Url=$_.Url;Display=$_.Topic+': '+$_.Title}})
    $d.NewsList.SelectedItem=@($d.NewsList.Items | Where-Object {$_.Url -eq $selectedNews}) | Select-Object -First 1
    }
    if(-not $script:orbySettings.Watchlist){$d.WatchStatus.Text='Watchlist connection is off'}
    elseif(-not $script:orbySettings.AllowPublicNews){$d.WatchStatus.Text='Enable Google News searches in Settings to connect this watchlist'}
    elseif(-not $script:orbySettings.WatchTopics){$d.WatchStatus.Text='Add tickers or companies to follow'}
    elseif($script:orbyShared.WatchError){$d.WatchStatus.Text=$script:orbyShared.WatchError}
    elseif($script:orbyShared.WatchAt){$d.WatchStatus.Text='Last checked '+$script:orbyShared.WatchAt.ToLocalTime().ToString('HH:mm')+' | Headlines, not live prices'}
    $d.ConnectionNote.Text=if($script:orbySettings.Quiet){'Quiet mode: updates stay in your alerts'}else{'Orby reacts to new events; '+@($script:orbyAlerts | Where-Object {-not $_.Read}).Count+' unread alerts'}    
    if($script:displayHz -gt 0){
        $renderText=if($script:avatarRenderer){' | '+[math]::Round($script:avatarRenderer.ObservedFps)+' FPS'}else{''}
        $d.ConnectionNote.Text='Display '+$script:displayHz+' Hz'+$renderText+' | '+$d.ConnectionNote.Text
    }

}

function Show-OrbySettings {
    if($script:settingsWindow -and $script:settingsWindow.IsVisible){$script:settingsWindow.Activate();return}
    [xml]$xml=(Get-Content -LiteralPath (Join-Path $PSScriptRoot 'Settings.xaml') -Raw).Replace('<Storyboard>',('<Storyboard Timeline.DesiredFrameRate="'+$(if($script:displayHz -gt 0){$script:displayHz}else{60})+'">'))
    $script:settingsWindow=[Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader $xml))
    if($script:desktopPanel){
      if($script:desktopPanel.Parent -is [Windows.Controls.ContentControl]){$script:desktopPanel.Parent.Content=$null}
      $script:settingsWindow.FindName('SettingsControlsHost').Content=$script:desktopPanel
    }
    $script:settingsControls=@{}
    foreach($name in @('AIConnections','EnableHideFullscreen','EnableEyeEffects','EnableReducedMotion','EnableSounds','EnableStartWithWindows','EnableMusic','EnableNotifications','EnableHealth','EnableDownloads','EnableTasks','EnableWatchlist','EnableAllowPublicNews','EnableQuiet','EnablePreview','NotificationApps','MediaApp','MediaHelp','DownloadFolder','BrowseDownloadFolder','SettingsWatchTopics','FocusMinutes','BreakMinutes','FavoriteList','AddFavorite','RemoveFavorite','LaunchFavorite','SettingsMessage','SaveSettings','CloseSettings','EnableNotificationAccess','NotificationHelp')){$script:settingsControls[$name]=$script:settingsWindow.FindName($name)}
    $c=$script:settingsControls
    $c['EnableStartWithWindows'].IsEnabled=$false;$c['EnableStartWithWindows'].ToolTip='Automatic startup is disabled in this security build.'
    foreach($key in @('HideFullscreen','EyeEffects','ReducedMotion','Sounds','StartWithWindows','Music','Notifications','Health','Downloads','Tasks','Watchlist','AllowPublicNews','Quiet','Preview')){$c['Enable'+$key].IsChecked=[bool]$script:orbySettings[$key]}
    foreach($key in @('NotificationApps','MediaApp','DownloadFolder','FocusMinutes','BreakMinutes')){$c[$key].Text=[string]$script:orbySettings[$key]}
    $c.AIConnections.Add_Click({Show-OrbyConnections})
    $c.SettingsWatchTopics.Text=$script:orbySettings.WatchTopics
    $c.MediaHelp.Text='Detected sessions: '+($script:orbyShared.MediaApps -join ', ')
    $c.FavoriteList.ItemsSource=@($script:orbySettings.Favorites)
    $c.BrowseDownloadFolder.Add_Click({$dialog=New-Object Windows.Forms.FolderBrowserDialog;$dialog.SelectedPath=$script:settingsControls.DownloadFolder.Text;if($dialog.ShowDialog() -eq 'OK'){$script:settingsControls.DownloadFolder.Text=$dialog.SelectedPath};$dialog.Dispose()})
    $c.AddFavorite.Add_Click({
        $dialog=New-Object Windows.Forms.OpenFileDialog;$dialog.Filter='Applications (*.exe)|*.exe';$dialog.Title='Choose an app for Orby'
        if($dialog.ShowDialog() -eq 'OK'){$script:orbySettings.Favorites=@($script:orbySettings.Favorites)+[pscustomobject]@{Name=[IO.Path]::GetFileNameWithoutExtension($dialog.FileName);Path=$dialog.FileName};$script:settingsControls.FavoriteList.ItemsSource=@($script:orbySettings.Favorites)};$dialog.Dispose()
    })
    $c.RemoveFavorite.Add_Click({$selected=$script:settingsControls.FavoriteList.SelectedItem;if($selected){$script:orbySettings.Favorites=@($script:orbySettings.Favorites | Where-Object {$_.Path -ne $selected.Path});$script:settingsControls.FavoriteList.ItemsSource=@($script:orbySettings.Favorites)}})
    $c.LaunchFavorite.Add_Click({$selected=$script:settingsControls.FavoriteList.SelectedItem;if($selected -and (Test-Path -LiteralPath $selected.Path)){Start-Process -FilePath $selected.Path -WindowStyle Normal}})
    $c.EnableNotificationAccess.Add_Click({
        try{
            Add-Type -AssemblyName System.Runtime.WindowsRuntime
            $listener=[Windows.UI.Notifications.Management.UserNotificationListener,Windows.UI.Notifications,ContentType=WindowsRuntime]::Current
            $op=$listener.RequestAccessAsync()
            $method=[System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {$_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'} | Select-Object -First 1
            $task=$method.MakeGenericMethod([Windows.UI.Notifications.Management.UserNotificationListenerAccessStatus,Windows.UI.Notifications,ContentType=WindowsRuntime]).Invoke($null,@($op))
            $script:settingsControls.NotificationHelp.Text='Finish the Windows permission prompt, then restart Orby to reconnect.'
        }catch{$script:settingsControls.NotificationHelp.Text='Windows could not grant full notification access to this portable build. Orby can watch accessible visible banners.'}
    })
    $c.SaveSettings.Add_Click({
        try{
            $focus=0;$break=0
            if(-not [int]::TryParse($script:settingsControls.FocusMinutes.Text,[ref]$focus) -or $focus -lt 1 -or $focus -gt 240){throw 'Focus minutes must be between 1 and 240'}
            if(-not [int]::TryParse($script:settingsControls.BreakMinutes.Text,[ref]$break) -or $break -lt 0 -or $break -gt 240){throw 'Break minutes must be between 0 and 240'}
            if(-not (Test-Path -LiteralPath $script:settingsControls.DownloadFolder.Text -PathType Container)){throw 'Choose an existing download folder'}
            foreach($key in @('HideFullscreen','EyeEffects','ReducedMotion','Sounds','StartWithWindows','Music','Notifications','Health','Downloads','Tasks','Watchlist','AllowPublicNews','Quiet','Preview')){$script:orbySettings[$key]=[bool]$script:settingsControls['Enable'+$key].IsChecked}
            foreach($key in @('NotificationApps','MediaApp','DownloadFolder')){$script:orbySettings[$key]=$script:settingsControls[$key].Text.Trim()}
            $script:orbySettings.WatchTopics=$script:settingsControls.SettingsWatchTopics.Text.Trim();$script:orbySettings.FocusMinutes=$focus;$script:orbySettings.BreakMinutes=$break
            $script:orbyNextBreak=[datetime]::UtcNow.AddMinutes([Math]::Max(1,$break))
            Save-OrbySettings;$script:desktopControls.WatchTopics.Text=$script:orbySettings.WatchTopics
            $script:settingsControls.SettingsMessage.Text='Saved. Your choices are active.'
        }catch{$script:settingsControls.SettingsMessage.Text=$_.Exception.Message}
    })
    $c.CloseSettings.Add_Click({$script:settingsWindow.Close()})
    [void]$script:settingsWindow.ShowDialog()
}

function Start-OrbyTray {
    $script:orbyTray=New-Object Windows.Forms.NotifyIcon
    $iconPath=Join-Path $PSScriptRoot 'Orby.ico'
    if(Test-Path $iconPath){$script:orbyTray.Icon=New-Object Drawing.Icon $iconPath}else{$script:orbyTray.Icon=[Drawing.SystemIcons]::Information}
    $script:orbyTray.Text='Orby - your desktop companion';$script:orbyTray.Visible=$true
    $menu=New-Object Windows.Forms.ContextMenuStrip
    $settings=$menu.Items.Add('Settings');$settings.Add_Click({Show-OrbySettings})
    $focus=$menu.Items.Add('Start / stop focus');$focus.Add_Click({Invoke-OrbyQuickAction 'focus'})
    $quiet=$menu.Items.Add('Toggle quiet mode');$quiet.Add_Click({$script:orbySettings.Quiet=-not $script:orbySettings.Quiet;Save-OrbySettings})
    $recenter=$menu.Items.Add('Recenter Orby');$recenter.Add_Click({Position-Orbit})
    $exit=$menu.Items.Add('Quit Orby');$exit.Add_Click({$window.Close()})
    $script:orbyTray.ContextMenuStrip=$menu
    $script:orbyTray.Add_DoubleClick({Show-OrbySettings})
    $window.Add_Closed({$script:orbyShared.Stop=$true;$script:orbyTray.Visible=$false;$script:orbyTray.Dispose();if($script:settingsWindow){$script:settingsWindow.Close()};try{$script:orbyWorker.Stop();$script:orbyWorker.Dispose();$script:orbyRunspace.Dispose()}catch{}})
}


