# Hydration reminders stay in the compact notch. All intake is explicitly logged.
function Sync-OrbyWaterSettings {
 $w=$script:waterDay;$s=$script:orbySettings
 $w.Enabled=[bool]$s.WaterEnabled
 $w.GoalMl=[math]::Max(2500,[math]::Min(3000,[int]$s.WaterGoalMl))
 $w.DrinkMl=[math]::Max(50,[math]::Min(100,[int]$s.WaterDrinkMl))
 $hours=[math]::Max(1,[math]::Min(16,[int]$s.WaterSessionHours))
 $script:waterPlan=[OrbyWater.SipPlan]::new($w.GoalMl,$w.DrinkMl,$hours)
 $w.IntervalMinutes=[int][math]::Ceiling($script:waterPlan.IntervalSeconds/60)
 $w.WakeHour=[math]::Max(0,[math]::Min(23,[int]$s.WaterWakeHour))
 $w.SleepHour=[math]::Max(0,[math]::Min(23,[int]$s.WaterSleepHour))
}
function Save-OrbyWater {
 try{
  $value=[ordered]@{Date=$script:waterDay.Date;TotalMl=$script:waterDay.TotalMl;NextReminder=$script:waterDay.NextReminder.ToString('o');ActiveSeconds=$script:waterSessionClock.Elapsed.TotalSeconds;NextActiveSecond=$script:waterNextSessionSecond;History=@($script:waterHistory.Values | Sort-Object Date)}
  $temp=$script:waterPath+'.tmp';[IO.File]::WriteAllText($temp,($value | ConvertTo-Json))
  Move-Item -LiteralPath $temp -Destination $script:waterPath -Force
 }catch{Write-OrbitLog ('Water progress could not be saved: '+$_.Exception.Message)}
}
function Test-OrbyWaterBlocked {
 return ($script:chatLogState -in @('attention','error') -or $script:petState -in @('attention','error') -or $script:orbyEventMode -in @('attention','drop') -or $script:dropBusy -or $script:greetingActive)
}
function Start-OrbyWaterReminder {
 param([switch]$Preview)
 if($script:waterPriority){return $false}
 $script:waterPriority=$true;$script:avatarRenderer.WaterPriority=$true
 if($script:orbyEventMode -eq 'success'){
  $script:eventDismissed=$script:eventSignature;Update-OrbyEventCard;Set-OrbitExpanded $false
 }
 if($script:expanded){Set-OrbitExpanded $false}
 if($Preview){Set-OrbitExpanded $false}
 if(-not $script:avatarRenderer.Trigger('water_reminder')){return $false}
 $script:waterSessionUntil=[datetime]::MaxValue;$script:waterConfirmed=$false;$script:waterSkipped=$false
 try{if($script:orbySettings.Sounds){[OrbyTones]::Play('water')}}catch{Write-OrbitLog ('Water ding unavailable: '+$_.Exception.Message)}
 $script:waterPreview=[bool]$Preview
 if(-not $Preview){$script:waterNextSessionSecond=$script:waterPlan.Next($script:waterSessionClock.Elapsed.TotalSeconds);Save-OrbyWater}
 $script:avatarRenderer.WaterProgress=$script:waterDay.Percent/100.0
 Update-OrbyCompactTask
 return $true
}
function Confirm-OrbyWater {
 param([switch]$Manual)
 if(-not $Manual -and ([datetime]::Now -ge $script:waterSessionUntil -or $script:waterConfirmed)){return}
 $script:waterDay.Confirm([datetime]::Now);$script:waterConfirmed=$true;$script:waterSkipped=$false
 $script:waterSessionUntil=[datetime]::Now.AddSeconds(5)
 $script:waterNextSessionSecond=$script:waterPlan.Next($script:waterSessionClock.Elapsed.TotalSeconds)
 [void]$script:avatarRenderer.Trigger('water_reveal')
 $script:avatarRenderer.WaterProgress=$script:waterDay.Percent/100.0
 Save-OrbyWater;Update-OrbyCompactTask
 if($script:settingsControls -and $script:settingsControls.WaterSummary){$script:settingsControls.WaterSummary.Text=Get-OrbyWaterSummary}
}
function Skip-OrbyWater {
 if([datetime]::Now -ge $script:waterSessionUntil -or $script:waterConfirmed){return}
 $script:waterConfirmed=$true;$script:waterSkipped=$true;$script:waterSessionUntil=[datetime]::Now.AddSeconds(3)
 $script:waterNextSessionSecond=$script:waterPlan.Next($script:waterSessionClock.Elapsed.TotalSeconds)
 $script:waterDay.Reminded([datetime]::Now);Save-OrbyWater
 [void]$script:avatarRenderer.Trigger('water_skip');Update-OrbyCompactTask
}
function Update-OrbyWaterPrompt {
 if(-not $script:waterPrompt){return}
 $show=([bool](Get-OrbyWaterTitle)) -and -not $script:waterConfirmed
 $script:waterPrompt.Visibility=if($show){'Visible'}else{'Collapsed'}
 $window.FindName('CompactTaskTitle').Visibility=if($show){'Collapsed'}else{'Visible'}
 $script:waterPrompt.Margin=[Windows.Thickness]::new(0,0,$(if($script:albumCoverButton.Visibility -eq 'Visible'){48}else{8}),0)
 $script:waterDrinkButton.Content='Drink'
}
function Get-OrbyWaterSummary {
 $w=$script:waterDay;$now=[datetime]::Now
 $seconds=[math]::Max(0,[math]::Ceiling($script:waterNextSessionSecond-$script:waterSessionClock.Elapsed.TotalSeconds));$countdown=('{0:00}:{1:00}' -f [int][math]::Floor($seconds/60),[int]($seconds%60))
 $status=if($script:waterPriority -and -not $script:waterConfirmed){'Waiting for Drink or Skip'}elseif(-not $w.Enabled){'Reminders are off'}elseif($w.TotalMl -ge $w.GoalMl){'Estimated goal reached'}elseif($script:waterNextSessionSecond -gt $script:waterPlan.EndSeconds -or $script:waterSessionClock.Elapsed.TotalSeconds -gt $script:waterPlan.EndSeconds){'Computer session finished'}else{'Next sip in '+$countdown}
 return ('Estimated today: {0:N0} / {1:N0} mL ({2}%). {3}. Each Drink estimates {4} mL; plan: {5} active hours, every {6:0.#} active minutes. Used today: {7:0.00} h. Other drinks count too; this is your chosen goal.' -f $w.TotalMl,$w.GoalMl,$w.Percent,$status,$w.DrinkMl,$script:waterPlan.Hours,($script:waterPlan.IntervalSeconds/60),($script:waterSessionClock.Elapsed.TotalHours))
}
function Get-OrbyWaterTitle {
 if(-not $script:waterDay -or [datetime]::Now -ge $script:waterSessionUntil){return ''}
 if($script:waterSkipped){return 'Skipped - try again next reminder'}
 if($script:waterConfirmed){return ('Sip logged - {0}% estimated' -f $script:waterDay.Percent)}
 return 'Take a sip of water'
}
function Initialize-OrbyWater {
 $script:waterSessionClock=[OrbyWater.ActiveDayClock]::new();$script:waterHistory=@{}
 $script:waterTestMode=Test-Path -LiteralPath (Join-Path $PSScriptRoot 'Water-Test-Mode.flag')
 $script:waterDay=New-Object OrbyWater.Day;$script:waterDay.Testing=$script:waterTestMode;$script:waterPath=Join-Path $logDir 'water-progress.json'
 $script:waterSessionUntil=[datetime]::MinValue;$script:waterConfirmed=$false;$script:waterPreview=$false
 Sync-OrbyWaterSettings
 $script:waterNextSessionSecond=$script:waterPlan.IntervalSeconds
 try{
  if(Test-Path -LiteralPath $script:waterPath){
   $saved=Get-Content -LiteralPath $script:waterPath -Raw | ConvertFrom-Json
   foreach($record in @($saved.History)){if($record -and $record.Date){$script:waterHistory[[string]$record.Date]=$record}}
   $script:waterSessionClock.Restore([string]$saved.Date,[double]$saved.ActiveSeconds,[datetime]::Now)
   if([string]$saved.Date -eq [datetime]::Now.ToString('yyyy-MM-dd') -and $saved.NextActiveSecond){$script:waterNextSessionSecond=[double]$saved.NextActiveSecond}else{$script:waterNextSessionSecond=$script:waterPlan.Next($script:waterSessionClock.Elapsed.TotalSeconds)}
   $script:waterDay.Date=[string]$saved.Date;$script:waterDay.TotalMl=[math]::Max(0,[math]::Min(20000,[int]$saved.TotalMl))
   $script:waterDay.NextReminder=[datetime]::Parse([string]$saved.NextReminder,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::RoundtripKind)
  }
 }catch{Write-OrbitLog 'Water state unavailable; starting a new local water log.'}
 [void]$script:waterDay.RollDate([datetime]::Now);if($script:waterTestMode){$script:waterDay.Reminded([datetime]::Now)}
 $label=$window.FindName('CompactTaskTitle')
 $waterPromptHost=$window.FindName('CompactHeader')
 if($waterPromptHost){
  $script:waterPrompt=[Windows.Markup.XamlReader]::Parse('<StackPanel xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" VerticalAlignment="Center" Visibility="Collapsed"><StackPanel.Resources><Style TargetType="Button"><Setter Property="Foreground" Value="#EAF8FC"/><Setter Property="Background" Value="#193944"/><Setter Property="FontSize" Value="10"/><Setter Property="Padding" Value="9,3"/><Setter Property="Cursor" Value="Hand"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border Background="{TemplateBinding Background}" CornerRadius="8" Padding="{TemplateBinding Padding}"><ContentPresenter HorizontalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="#285E70"/></Trigger><Trigger Property="IsPressed" Value="True"><Setter Property="Opacity" Value="0.65"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style></StackPanel.Resources><TextBlock Text="Take a sip of water" Foreground="#A9E6FA" FontSize="11" Margin="0,0,0,3"/><StackPanel Orientation="Horizontal"><Button x:Name="Drink" Content="Drink"/><Button x:Name="Skip" Content="Skip" Background="#303137" Margin="6,0,0,0"/></StackPanel></StackPanel>')
  [Windows.Controls.Grid]::SetColumn($script:waterPrompt,1);[void]$waterPromptHost.Children.Add($script:waterPrompt)
  $script:waterDrinkButton=$script:waterPrompt.FindName('Drink');$script:waterSkipButton=$script:waterPrompt.FindName('Skip')
  $script:waterDrinkButton.Add_Click({Confirm-OrbyWater});$script:waterSkipButton.Add_Click({Skip-OrbyWater})
 }
 $label.Add_MouseLeftButtonDown({param($sender,$eventArgs)
  if(Get-OrbyWaterTitle){Confirm-OrbyWater;$eventArgs.Handled=$true}
 })
 $label.Add_MouseRightButtonDown({param($sender,$eventArgs)
  if(Get-OrbyWaterTitle){$script:waterDay.Snooze([datetime]::Now);$script:waterSessionUntil=[datetime]::MinValue;$script:avatarRenderer.StopWater();Save-OrbyWater;Update-OrbyCompactTask;$eventArgs.Handled=$true}
 })
 $script:waterTimer=New-Object Windows.Threading.DispatcherTimer
 $script:waterTimer.Interval=[timespan]::FromSeconds(1)
 $script:waterTimer.Add_Tick({
  try{
   Sync-OrbyWaterSettings
   $now=[datetime]::Now;$previousDate=$script:waterSessionClock.Date
   if($previousDate -ne $now.ToString('yyyy-MM-dd')){$script:waterHistory[$previousDate]=[pscustomobject]@{Date=$previousDate;ActiveSeconds=$script:waterSessionClock.Elapsed.TotalSeconds;TotalMl=$script:waterDay.TotalMl};if($script:waterPriority){$script:waterPriority=$false;$script:avatarRenderer.WaterPriority=$false;$script:avatarRenderer.StopWater();$script:waterSessionUntil=[datetime]::MinValue};$script:waterNextSessionSecond=$script:waterPlan.IntervalSeconds}
   $script:waterSessionClock.Tick($now,[OrbyWater.InputActivity]::Active())
   if($script:waterDay.RollDate($now)){Save-OrbyWater}
   if(-not $script:waterSavedAt -or ($now-$script:waterSavedAt).TotalSeconds -ge 5){$script:waterHistory[$script:waterSessionClock.Date]=[pscustomobject]@{Date=$script:waterSessionClock.Date;ActiveSeconds=$script:waterSessionClock.Elapsed.TotalSeconds;TotalMl=$script:waterDay.TotalMl};Save-OrbyWater;$script:waterSavedAt=$now}
   if($script:waterPriority -and [datetime]::Now -ge $script:waterSessionUntil){$script:waterPriority=$false;$script:avatarRenderer.WaterPriority=$false;$script:waterPreview=$false;$script:avatarRenderer.StopWater();$script:orbyEventMode=''}
   if(-not $script:fullscreenHidden -and $script:waterPlan.Due($script:waterSessionClock.Elapsed.TotalSeconds,$script:waterNextSessionSecond,$script:waterDay.TotalMl,$script:waterDay.Enabled) -and -not $script:waterPriority) {[void](Start-OrbyWaterReminder)}
   $script:avatarRenderer.WaterProgress=$script:waterDay.Percent/100.0
   Update-OrbyCompactTask
   if($script:settingsWindow -and $script:settingsWindow.IsVisible){$script:settingsControls.WaterSummary.Text=Get-OrbyWaterSummary}
  }catch{Write-OrbitLog ('Water timer: '+$_.Exception.Message)}
 })
 $script:waterTimer.Start();$window.Add_Closed({$script:waterTimer.Stop();$script:waterHistory[$script:waterSessionClock.Date]=[pscustomobject]@{Date=$script:waterSessionClock.Date;ActiveSeconds=$script:waterSessionClock.Elapsed.TotalSeconds;TotalMl=$script:waterDay.TotalMl};Save-OrbyWater})
}




