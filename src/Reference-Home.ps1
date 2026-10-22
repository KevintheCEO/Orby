function New-OrbyHome {
 [xml]$xml=(Get-Content (Join-Path $PSScriptRoot 'Reference-Home.xaml') -Raw).Replace('<Storyboard>',('<Storyboard Timeline.DesiredFrameRate="'+$(if($script:displayHz -gt 0){$script:displayHz}else{60})+'">'))
 $script:referenceHome=[Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader $xml))
 $script:referenceControls=@{}
 foreach($name in @('RefProviderGlyph','RefProviderIcon','RefProviderName','RefProviderLimitNote','RefMusicVolume','RefMusicVolumeText','RefCardAmbient','RefOrbGlow','RefMusicAmbient','RefTaskOpen','RefMusicPlayIcon','RefUsageRefresh','RefActivityPeriod','RefContentRow','RefCodexCard','RefAgentPlan','RefSessionRow','RefSessionLabel','RefSessionPercent','RefSessionBar','RefWeekRow','RefWeekLabel','RefWeekPercent','RefWeekBar','RefQuotaNotice','RefUsageNotice','RefChatColumn','RefCodexColumn','RefAgentGap','RefTokenValue','RefTokenScope','RefNowChat','RefNowCodex','RefTrendLine','RefTrendCaption','RefAgents','RefAgentsPage','RefChatCard','RefAgentState','RefAgentTask','RefAgentCount','RefAgentActivity','RefAgentsEmpty','RefHome','RefMusic','RefTools','RefSettings','RefAnimations','RefHealth','RefHomePage','RefMusicPage','RefOrbHost','RefTitle','RefAction','RefDetail','RefConnection','RefPillText0','RefPillText1','RefPillText2','RefPillText3','RefMusicCover','RefMusicTitle','RefMusicArtist','RefMusicNotice','RefMusicSeek','RefMusicPosition','RefMusicDuration','RefMusicShuffle','RefMusicPrevious','RefMusicPlay','RefMusicNext','RefMusicRepeat')){$script:referenceControls[$name]=$script:referenceHome.FindName($name)}
 $script:referenceOrb=New-OrbitAvatar
 $script:referenceControls.RefOrbHost.Child=$script:referenceOrb.Root
 Update-OrbitAvatar $script:referenceOrb 'idle' 0
 $script:referenceControls.RefTaskOpen.Add_Click({Focus-ChatGpt})
 $script:referenceControls.RefMusic.Add_Click({Set-OrbyHomePage 'music'})
 $script:referenceControls.RefTools.Add_Click({Show-OrbyTools})
 $script:referenceControls.RefAnimations.Add_Click({Show-OrbyAnimations})
 $script:referenceControls.RefSettings.Add_Click({Show-OrbySettings})
 $script:referenceControls.RefHome.Add_Click({Set-OrbyHomePage 'home'})
 $script:referenceControls.RefAgents.Add_Click({Set-OrbyHomePage 'agents'})
 $script:referenceControls.RefAgents.Add_MouseRightButtonUp({Show-OrbyConnections})
 $script:referenceControls.RefUsageRefresh.Add_Click({$script:usagePollAt=[datetime]::MinValue;Update-OrbyAccountUsage;Update-OrbyAgents})
 Initialize-OrbyMusicTab
 Update-OrbyNavSelection 'home'
 return $script:referenceHome
}
function Set-OrbyHomePage {
 param([string]$Page='home')
 if(-not $script:referenceControls){return}
 Update-OrbyNavSelection $Page
 $isMusic=$Page -eq 'music'
 $script:referenceControls.RefHomePage.Visibility=if($Page -eq 'home'){'Visible'}else{'Collapsed'}
 $script:referenceControls.RefMusicPage.Visibility=if($isMusic){'Visible'}else{'Collapsed'}
 $script:referenceControls.RefAgentsPage.Visibility=if($Page -eq 'agents'){'Visible'}else{'Collapsed'}
 $agents=$Page -eq 'agents'
 if($script:referenceHome){$script:referenceHome.Height=if($agents){340}else{180}}
 if($script:referenceControls.RefContentRow){$script:referenceControls.RefContentRow.Height=[Windows.GridLength]::new($(if($agents){292}else{132}))}
 if($expandedArea){$expandedArea.Height=if($agents){340}else{180}}
 if($notch){Invoke-OrbyMotion $notch ([OrbyLiquidSurface]::ExpandedHeightProperty) $(if($agents){354}else{194}) 0.22}
 if($agents){Update-OrbyAgents;if(Test-Path function:Update-OrbyProviderView){Update-OrbyProviderView}}
 if($isMusic){Update-OrbyMusicTab}
 if(Test-Path function:Update-OrbyMultiProvider){Update-OrbyMultiProvider}
}
function Initialize-OrbyMusicTab {
 $c=$script:referenceControls
 Add-Type -Path (Join-Path $PSScriptRoot 'Output-Volume.cs')
 $c.RefMusicVolume.Add_PreviewMouseLeftButtonDown({$script:volumeDragging=$true})
 $c.RefMusicVolume.Add_PreviewMouseLeftButtonUp({$script:volumeDragging=$false;$script:volumeAt=[datetime]::UtcNow})
 $c.RefMusicVolume.Add_LostMouseCapture({$script:volumeDragging=$false;$script:volumeAt=[datetime]::UtcNow})
 $c.RefMusicVolume.Add_ValueChanged({if(-not $script:volumeSync){$m=$script:orbyShared.SelectedMusic;if(-not $m -or $script:musicVolumeSource -ne $m.App){return};$script:volumeRequestedRevision=([OrbyVolumeWorker]::ForSource($m.App)).Set($script:referenceControls.RefMusicVolume.Value);$script:referenceControls.RefMusicVolumeText.Text=('{0:0}%' -f $script:referenceControls.RefMusicVolume.Value)}})
 if(-not $c.RefMusicSeek){return}
 $c.RefMusicPlay.Add_Click({$m=$script:orbyShared.SelectedMusic;if($m){Send-OrbyMusicControl $(if($m.Playing){'pause'}else{'play'})}})
 $c.RefMusicNext.Add_Click({Send-OrbyMusicControl 'next'})
 $c.RefMusicPrevious.Add_Click({Send-OrbyMusicControl 'previous'})
 $c.RefMusicShuffle.Add_Click({$m=$script:orbyShared.SelectedMusic;if($m){Send-OrbyMusicControl 'shuffle' (-not [bool]$m.Shuffle)}})
 $c.RefMusicRepeat.Add_Click({$m=$script:orbyShared.SelectedMusic;if($m){$next=switch($m.Repeat){List{'Track'}Track{'None'}default{'List'}};Send-OrbyMusicControl 'repeat' $next}})
 $c.RefMusicSeek.Add_PreviewMouseLeftButtonDown({$script:referenceMusicDragging=$true;$script:referenceMusicTrack=$script:orbyShared.SelectedMusic.TrackKey})
 $c.RefMusicSeek.Add_PreviewMouseLeftButtonUp({if($script:referenceMusicDragging){$script:referenceMusicDragging=$false;Send-OrbyMusicControl 'seek' $script:referenceControls.RefMusicSeek.Value $script:referenceMusicTrack;Update-OrbyMusicTab}})
 $c.RefMusicSeek.Add_PreviewKeyDown({param($sender,$e)if($e.Key -in @('Left','Right','Home','End','PageUp','PageDown')){$script:referenceMusicDragging=$true;$script:referenceMusicTrack=$script:orbyShared.SelectedMusic.TrackKey}})
 $c.RefMusicSeek.Add_KeyUp({param($sender,$e)if($e.Key -in @('Left','Right','Home','End','PageUp','PageDown')){$script:referenceMusicDragging=$false;Send-OrbyMusicControl 'seek' $sender.Value $script:referenceMusicTrack;Update-OrbyMusicTab}})
 $c.RefMusicSeek.Add_LostMouseCapture({if($script:referenceMusicDragging){$script:referenceMusicDragging=$false;Send-OrbyMusicControl 'seek' $script:referenceControls.RefMusicSeek.Value $script:referenceMusicTrack;Update-OrbyMusicTab}})
}
function Update-OrbyMusicVolume {
 $c=$script:referenceControls;$now=[datetime]::UtcNow
 $m=$script:orbyShared.SelectedMusic
 if(-not $m -or -not $script:orbySettings.Music -or ($now-$m.At).TotalSeconds -gt 8){$c.RefMusicVolume.IsEnabled=$false;$c.RefMusicVolumeText.Text=[string][char]0x2014;return}
 if($script:musicVolumeSource -ne $m.App){$script:musicVolumeSource=$m.App;$script:volumeAppliedAt=[datetime]::MinValue;$script:volumeAt=[datetime]::MinValue;$script:volumeRequestedRevision=0;$script:volumeDragging=$false;$c.RefMusicVolume.IsEnabled=$false}
 $channel=[OrbyVolumeWorker]::ForSource($m.App)
 if(-not $script:volumeDragging -and (-not $script:volumeAt -or ($now-$script:volumeAt).TotalMilliseconds -ge 1000)){$script:volumeAt=$now;$channel.Refresh()}
 $snapshot=$channel.Snapshot
 if(-not $snapshot -or $script:volumeDragging -or $snapshot.At -eq $script:volumeAppliedAt -or $snapshot.Revision -lt $script:volumeRequestedRevision){return}
 $script:volumeAppliedAt=$snapshot.At;$script:volumeSync=$true
 try{
  if($snapshot.Error){$c.RefMusicVolume.IsEnabled=$false;$c.RefMusicVolume.ToolTip='Player volume unavailable: '+$snapshot.Error;$c.RefMusicVolumeText.Text=[string][char]0x2014}
  else{$c.RefMusicVolume.Value=$snapshot.Value;$c.RefMusicVolumeText.Text=('{0:0}%' -f $snapshot.Value);$c.RefMusicVolume.IsEnabled=$true;$c.RefMusicVolume.ToolTip='Selected music app volume only'}
 }finally{$script:volumeSync=$false}
}
function Update-OrbyMusicTab {
 $c=$script:referenceControls;if(-not $c.RefMusicPage -or $c.RefMusicPage.Visibility -ne 'Visible'){return}
 Update-OrbyMusicVolume
 $m=$script:orbyShared.SelectedMusic;$fresh=$m -and $script:orbySettings.Music -and (([datetime]::UtcNow-$m.At).TotalSeconds -lt 8)
 if(-not $fresh){$c.RefMusicTitle.Text='Waiting for music';$c.RefMusicArtist.Text='Play music in your favourite app';$c.RefMusicNotice.Text=if($script:orbyShared.MediaError){$script:orbyShared.MediaError}else{'Choose a player above, or use Automatic'};$c.RefMusicNotice.ToolTip=$c.RefMusicNotice.Text;$c.RefMusicCover.Source=$null;$script:referenceMusicArtKey='';$c.RefMusicPosition.Text='--:--';$c.RefMusicDuration.Text='--:--';foreach($n in @('RefMusicShuffle','RefMusicPrevious','RefMusicPlay','RefMusicNext','RefMusicRepeat','RefMusicSeek')){$c[$n].IsEnabled=$false};return}
 $c.RefMusicTitle.Text=$m.Title;$c.RefMusicArtist.Text=$m.Artist;$c.RefMusicNotice.Text=if($script:orbyShared.MusicResult){$script:orbyShared.MusicResult}elseif($m.Duration -le 0){'Timeline not shared by this player'}elseif(-not $m.CanSeek){'Seeking unavailable for this track'}else{if($m.Name){$m.Name}else{'Music playback'}}
 if($script:referenceMusicArtKey -ne $m.ArtworkKey){$script:referenceMusicArtKey=$m.ArtworkKey;try{$c.RefMusicCover.Source=Convert-OrbyAlbumBitmap $m.ArtworkBytes;$c.RefMusicAmbient.Color=Get-OrbyArtworkAccent $c.RefMusicCover.Source}catch{$c.RefMusicCover.Source=$null}}
 $c.RefMusicNotice.ToolTip=$c.RefMusicNotice.Text
 $c.RefMusicPrevious.IsEnabled=$m.CanPrevious;$c.RefMusicNext.IsEnabled=$m.CanNext;$c.RefMusicPlay.IsEnabled=if($m.Playing){$m.CanPause}else{$m.CanPlay};$c.RefMusicPlayIcon.Data=[Windows.Media.Geometry]::Parse($(if($m.Playing){'M4,2 H7 V16 H4 Z M11,2 H14 V16 H11 Z'}else{'M4,2 L15,9 L4,16 Z'}));$c.RefMusicShuffle.Tag=if($m.Shuffle){'Active'}else{$null};$c.RefMusicRepeat.Tag=if($m.Repeat -ne 'None'){'Active'}else{$null};$c.RefMusicRepeat.ToolTip='Repeat: '+$m.Repeat;$c.RefMusicShuffle.IsEnabled=$m.CanShuffle;$c.RefMusicRepeat.IsEnabled=$m.CanRepeat;$c.RefMusicSeek.IsEnabled=$m.CanSeek
 $position=Get-OrbySmoothMusicPosition $m;if(-not $script:referenceMusicDragging){$c.RefMusicSeek.Minimum=$m.Start;$c.RefMusicSeek.Maximum=[math]::Max($m.Start+1,$m.Start+$m.Duration);$c.RefMusicSeek.Value=$position};$c.RefMusicPosition.Text=if($m.Duration -gt 0){Format-OrbyMusicTime ($position-$m.Start)}else{'--:--'};$c.RefMusicDuration.Text=if($m.Duration -gt 0){Format-OrbyMusicTime $m.Duration}else{'--:--'}
}
function Show-OrbyTools {
 Show-OrbySettings
 $script:settingsWindow.FindName('SettingsDesktopControls').IsExpanded=$true
}
function Update-OrbyHome {
 $c=$script:referenceControls;if(-not $c){return}
 $c.RefTitle.Text=if($script:chatLogState -in @('working','attention','success','error','stopped')){Get-NotchTaskTitle 'ChatGPT task'}else{'No active task'}
 $c.RefAction.Text=if($script:chatLogMessage){[string][char]0x203A+' '+$script:chatLogMessage}else{'Waiting for a task'}
 $c.RefTitle.ToolTip=$c.RefTitle.Text;$c.RefAction.ToolTip=$c.RefAction.Text
 $ambient=switch($script:chatLogState){attention{'#85FFBA48'}error{'#70FF6577'}working{'#65A8C8FF'}success{'#65A0F4CF'}default{'#60FFFFFF'}}
 $c.RefOrbGlow.Color=[Windows.Media.ColorConverter]::ConvertFromString($ambient)
 $tint=$c.RefOrbGlow.Color;$c.RefCardAmbient.Color=[Windows.Media.Color]::FromRgb([byte](9+$tint.R*0.10),[byte](9+$tint.G*0.10),[byte](13+$tint.B*0.10))
 $connected=[bool]($script:chatConnectionPresent -or ($script:usageSnapshot -and $script:usageSnapshot.Connected -and ([datetime]::UtcNow-$script:usageSnapshot.At).TotalSeconds -lt 180))
 if($script:referenceRenderer){$script:referenceRenderer.StatusConnected=$connected};if($script:avatarRenderer){$script:avatarRenderer.StatusConnected=$connected}
 $c.RefAgents.Visibility=if($connected){'Visible'}else{'Collapsed'};$c.RefProviderIcon.Visibility='Visible';$c.RefProviderGlyph.Visibility='Collapsed';$c.RefProviderName.Text='ChatGPT';$c.RefProviderLimitNote.Text='Message limits unavailable'
 if($script:providerIconResources){Set-OrbyProviderIcon 'chatgpt'}
 $c.RefAgents.ToolTip='OpenAI · connected ChatGPT / Codex'
 $c.RefDetail.Text=if($script:chatLogState -eq 'working'){'Working locally'}elseif($script:chatLogState -eq 'attention'){'Needs your input'}else{'Ready when you are'}
 $health=$script:orbyShared.Health
 $c.RefHealth.Text=if($health){$(if($health.Network){'Online'}else{'Offline'})+'   '+$(if($null -ne $health.Battery){[string]$health.Battery+'% battery'}else{'AC power'})}else{'Local connections'}
 $fallback=@('ChatGPT idle',(@($script:orbyAlerts | Where-Object {-not $_.Read}).Count.ToString()+' alerts'),$(if($script:orbyFocusEnd -gt [datetime]::UtcNow){'Focus running'}else{'Focus off'}),'Files ready')
 $tasks=@($script:orbyActiveTasks)
 for($i=0;$i -lt 4;$i++){
  $c['RefPillText'+$i].Text=if($i -lt $tasks.Count -and $tasks[$i]){$tasks[$i].Title}else{$fallback[$i]}
  $c['RefPillText'+$i].ToolTip=if($i -lt $tasks.Count -and $tasks[$i]){$tasks[$i].Title+' - '+$tasks[$i].Action}else{$fallback[$i]}
 }
 $c.RefConnection.Text=if($script:petFeedAvailable){'ChatGPT connected | '+$tasks.Count+' active task(s)'}else{'Waiting for local ChatGPT activity'}
 if(Test-Path function:Update-OrbyHomeBuddies){Update-OrbyHomeBuddies}
 Update-OrbyMusicTab
 if($c.RefAgentsPage.Visibility -eq 'Visible'){Update-OrbyAgents}
 if(Test-Path function:Update-OrbyProviderView){Update-OrbyProviderView}
}

function Update-OrbyAgents {
 $c=$script:referenceControls;if(-not $c.RefAgentsPage){return}
 $snapshot=$script:usageSnapshot
 $fresh=$snapshot -and ([datetime]::UtcNow-$snapshot.At).TotalSeconds -lt 180
 $chat=[bool]$script:chatConnectionPresent;$codex=[bool]($fresh -and $snapshot.Connected)
 $c.RefChatCard.Visibility=if($chat){'Visible'}else{'Collapsed'}
 $c.RefCodexCard.Visibility=if($codex){'Visible'}else{'Collapsed'}
 $c.RefAgentsEmpty.Visibility=if($chat -or $codex){'Collapsed'}else{'Visible'}
 $c.RefChatColumn.Width=[Windows.GridLength]::new($(if($chat){1}else{0}),[Windows.GridUnitType]::Star)
 $c.RefCodexColumn.Width=[Windows.GridLength]::new($(if($codex){1}else{0}),[Windows.GridUnitType]::Star)
 $c.RefAgentGap.Width=[Windows.GridLength]::new($(if($chat -and $codex){8}else{0}))
 $state=$script:chatLogState
 $label=switch($state){working{'Working'}attention{'Needs approval'}success{'Finished'}error{'Task error'}default{'Ready'}}
 $c.RefAgentState.Text=$label
 $c.RefAgentTask.Text=if($state -in @('working','attention')){Get-NotchTaskTitle 'ChatGPT task'}else{'Ready for your next chat'}
 $c.RefNowChat.Visibility=if($chat){'Visible'}else{'Collapsed'};$c.RefNowChat.Text='ChatGPT  '+$label
 $c.RefNowCodex.Visibility=if($codex){'Visible'}else{'Collapsed'};$c.RefNowCodex.Text='Codex  connected'
 $c.RefUsageNotice.Text=if($script:usagePollTask){'Refreshing in background'}elseif($script:usageRefreshFailed){'Refresh unavailable'}elseif($codex){'Remaining quota'}elseif($fresh){$snapshot.Status}else{'Chat status only'}
 $c.RefUsageNotice.ToolTip='Account limits shown here apply to Codex, not normal ChatGPT message limits.'
 $c.RefAgentPlan.Text=if($codex -and $snapshot.Plan){$snapshot.Plan}else{'Account'}
 $limits=$null;$usage=$null
 if($codex){
  if($script:usageDecodedLimitsJson -ne $snapshot.LimitsJson -or $script:usageDecodedUsageJson -ne $snapshot.UsageJson){
   $script:usageDecodedLimitsJson=$snapshot.LimitsJson;$script:usageDecodedUsageJson=$snapshot.UsageJson
   $script:usageDecodedLimits=$null;$script:usageDecodedUsage=$null
   if($snapshot.LimitsJson){try{$r=$snapshot.LimitsJson | ConvertFrom-Json;if($r.rateLimitsByLimitId.codex){$script:usageDecodedLimits=$r.rateLimitsByLimitId.codex}elseif($r.rateLimits.limitId -eq 'codex'){$script:usageDecodedLimits=$r.rateLimits}}catch{}}
   if($snapshot.UsageJson){try{$script:usageDecodedUsage=$snapshot.UsageJson | ConvertFrom-Json}catch{}}
  }
  $limits=$script:usageDecodedLimits;$usage=$script:usageDecodedUsage
 }
 Set-OrbyQuotaRow 'RefSession' $limits.primary;Set-OrbyQuotaRow 'RefWeek' $limits.secondary
 $c.RefQuotaNotice.Visibility=if($codex -and $c.RefSessionRow.Visibility -eq 'Collapsed' -and $c.RefWeekRow.Visibility -eq 'Collapsed'){'Visible'}else{'Collapsed'}
 $c.RefQuotaNotice.Text='Account did not return a current quota. Try again after using Codex.'
 $today=[datetime]::UtcNow.ToString('yyyy-MM-dd')
 $buckets=@($usage.dailyUsageBuckets | Where-Object {$null -ne $_ -and $null -ne $_.tokens -and [double]$_.tokens -ge 0} | Sort-Object startDate)
 $day=$buckets | Where-Object {$_.startDate -eq $today} | Select-Object -Last 1
 if(-not $day){$day=$buckets | Select-Object -Last 1}
 $c.RefActivityPeriod.Text=if($day -and $day.startDate -ne $today){'Latest day'}else{'Today'}
 $c.RefTokenValue.Text=if($day){$(if([double]$day.tokens -ge 1000000){([double]$day.tokens/1000000).ToString('0.0')+'M'}elseif([double]$day.tokens -ge 1000){([double]$day.tokens/1000).ToString('0.0')+'K'}else{([long]$day.tokens).ToString('N0')})}else{[string][char]0x2014}
 $c.RefTokenValue.ToolTip=if($day){([long]$day.tokens).ToString('N0')+' tokens on '+$day.startDate+' (UTC)'}else{'No activity returned'}
 $c.RefTokenScope.Text=if($day){'Codex tokens '+$day.startDate+' (UTC)'}else{'Token activity not provided'}
 $c.RefTrendLine.Points.Clear()
 $last=@($buckets | Select-Object -Last 7)
 if($last.Count -ge 2){$max=($last | Measure-Object tokens -Maximum).Maximum;$i=0;foreach($bucket in $last){$x=280*$i/($last.Count-1);$y=20-18*[double]$bucket.tokens/[math]::Max(1,[double]$max);$c.RefTrendLine.Points.Add([Windows.Point]::new($x,$y));$i++};$c.RefTrendCaption.Text=[string]$last.Count+' days'}else{$c.RefTrendCaption.Text='No daily history yet'}
}





function Update-OrbyNavSelection {
 param([string]$Page)
 $selected=switch($Page){music{'RefMusic'}agents{if($script:orbySettings.PrimaryProvider -eq 'chatgpt'){'RefAgents'}else{''}}default{'RefHome'}}
 foreach($id in $script:providerNav.Keys){$script:providerNav[$id].Tag=if($Page -eq 'agents' -and $id -eq $script:orbySettings.PrimaryProvider){'Selected'}else{$null}}
 foreach($name in @('RefHome','RefMusic','RefAgents')){
  if($script:referenceControls[$name]){$script:referenceControls[$name].Tag=if($name -eq $selected){'Selected'}else{$null}}
 }
}


function Get-OrbyArtworkAccent {
 param($Bitmap)
 if(-not $Bitmap){return [Windows.Media.Color]::FromArgb(85,100,150,130)}
 try{
  $small=[Windows.Media.Imaging.TransformedBitmap]::new($Bitmap,[Windows.Media.ScaleTransform]::new(16.0/$Bitmap.PixelWidth,16.0/$Bitmap.PixelHeight))
  $bgra=[Windows.Media.Imaging.FormatConvertedBitmap]::new($small,[Windows.Media.PixelFormats]::Bgra32,$null,0)
  $stride=$bgra.PixelWidth*4;$bytes=New-Object byte[] ($stride*$bgra.PixelHeight);$bgra.CopyPixels($bytes,$stride,0)
  $red=0.0;$green=0.0;$blue=0.0;$weight=0.0
  for($i=0;$i -lt $bytes.Length;$i+=4){$r=[double]$bytes[$i+2];$g=[double]$bytes[$i+1];$b=[double]$bytes[$i];$max=[math]::Max($r,[math]::Max($g,$b));$min=[math]::Min($r,[math]::Min($g,$b));$w=0.15+($max-$min)/255.0;if($max -lt 30){$w*=0.1};$red+=$r*$w;$green+=$g*$w;$blue+=$b*$w;$weight+=$w}
  return [Windows.Media.Color]::FromArgb(110,[byte]($red/$weight),[byte]($green/$weight),[byte]($blue/$weight))
 }catch{return [Windows.Media.Color]::FromArgb(85,100,150,130)}
}

