$script:providerCatalog=@{
 chatgpt=@{Name='ChatGPT';Web='https://chatgpt.com/';Download='https://chatgpt.com/download/';Process='ChatGPT'}
 claude=@{Name='Claude';Web='https://claude.ai/';Download='https://claude.com/download';Process='Claude'}
 gemini=@{Name='Gemini';Web='https://gemini.google.com/';Download='https://gemini.google/desktop/';Process='Gemini'}
}
$script:connectionControls=@{}
$script:providerDirectory=$PSScriptRoot
. (Join-Path $PSScriptRoot 'Provider-Icons.ps1')
Initialize-OrbyProviderIcons
. (Join-Path $PSScriptRoot 'Claude-Sync.ps1')
Add-Type -Path (Join-Path $PSScriptRoot 'Provider-Reader.cs') -ReferencedAssemblies UIAutomationClient,UIAutomationTypes,WindowsBase,System.Core
$script:providerRunspace=[runspacefactory]::CreateRunspace();$script:providerRunspace.ApartmentState='MTA';$script:providerRunspace.Open()
$script:providerWorker=[powershell]::Create();$script:providerWorker.Runspace=$script:providerRunspace
[void]$script:providerWorker.AddScript((Get-Content (Join-Path $PSScriptRoot 'Provider-Worker.ps1') -Raw)).AddArgument($script:orbyShared).AddArgument($PSScriptRoot)
$script:providerJob=$script:providerWorker.BeginInvoke()
function Get-OrbyProviderSnapshot {
 param([string]$Id)
 $snapshots=@($script:orbyShared.ProviderSnapshots | Where-Object {$_.Provider -eq $Id -and -not $_.UsagePage -and ([datetime]::UtcNow-$_.At).TotalSeconds -lt 8})
 if($Id -eq 'claude' -and $script:orbyShared.ClaudeCodeAt -and ([datetime]::UtcNow-$script:orbyShared.ClaudeCodeAt).TotalSeconds -lt 8){
  $code=$script:orbyShared.ClaudeCodeStatus
  if($code -and $code.Open){
   $desktop=$snapshots | Where-Object {$_.Hwnd} | Select-Object -First 1
   $snapshots+= [OrbyProviderSnapshot]@{Provider='claude';Source='code';AppOpen=$true;Connected=$code.Readable;StatusReadable=$code.Readable;State=$code.State;Detail=$code.Detail;At=$script:orbyShared.ClaudeCodeAt;Hwnd=$(if($desktop){$desktop.Hwnd}else{0})}
  }
 }
 # An idle window must not hide another window/session that is still working.
 $rank=@{attention=5;working=4;error=3;idle=2;unknown=1;offline=0}
 $snapshots | Sort-Object @{Expression={$rank[$_.State]};Descending=$true},@{Expression={$_.StatusReadable};Descending=$true} | Select-Object -First 1
}
function Open-OrbyProvider {
 param([string]$Id=$script:orbySettings.PrimaryProvider)
 $info=$script:providerCatalog[$Id];if(-not $info){return}
 $snap=Get-OrbyProviderSnapshot $Id
 if($snap -and $snap.Hwnd){[OrbyProviderReader]::Focus($snap.Hwnd);return}
 $p=Get-Process -Name $info.Process -ErrorAction SilentlyContinue | Where-Object {$_.MainWindowHandle} | Select-Object -First 1
 if($p){[OrbyProviderReader]::Focus($p.MainWindowHandle.ToInt64());return}
 $app=Get-StartApps -ErrorAction SilentlyContinue | Where-Object {$_.Name -eq $info.Name} | Select-Object -First 1
 if($app){Start-Process explorer.exe -ArgumentList ('shell:AppsFolder\'+$app.AppID);return}
 Start-Process $info.Web
}
function Connect-OrbyProvider {
 param([string]$Id)
 if(-not $script:providerCatalog.ContainsKey($Id)){return}
 $script:orbySettings.PrimaryProvider=$Id
 $script:orbySettings.ProviderEnabled=(@(($script:orbySettings.ProviderEnabled -split ',')+$Id) | Select-Object -Unique) -join ','
 Save-OrbySettings
 if($script:providerIconResources){Update-OrbyHome;Update-OrbyProviderState}
 Open-OrbyProvider $Id
}
function Show-OrbyConnections {
 if($script:connectionsWindow){$script:connectionsWindow.Activate() | Out-Null;return}
 [xml]$x=Get-Content (Join-Path $script:providerDirectory 'Connections.xaml') -Raw
 $script:connectionsWindow=[Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader $x))
 $script:connectionControls=@{}
 foreach($pair in @(@('chatgpt','Chat'),@('claude','Claude'),@('gemini','Gemini'))){
  $id=$pair[0];$prefix=$pair[1];$script:connectionControls[$id]=$script:connectionsWindow.FindName($prefix+'Status')
  $logo=$script:connectionsWindow.FindName($prefix+'Logo')
  if($script:providerIconResources){
   if($id -eq 'chatgpt'){$logo.Data=$script:openAiLogo;$logo.Fill=[Windows.Media.Brushes]::White}else{
    $logo.Data=$script:providerIconResources[$prefix+'Logo'];$logo.Fill=$script:providerIconResources[$prefix+'Brush']
   }
  }
  $connectButton=$script:connectionsWindow.FindName('Connect'+$prefix);$connectButton.CommandParameter=$id;$connectButton.Add_Click({param($sender,$eventArgs) Invoke-OrbySafeAction { Connect-OrbyProvider ([string]$sender.CommandParameter) } 'Connect-OrbyProvider'})
  $download=$script:providerCatalog[$id].Download
  $downloadButton=$script:connectionsWindow.FindName('Download'+$prefix);$downloadButton.CommandParameter=$download;$downloadButton.Add_Click({param($sender,$eventArgs) Start-Process ([string]$sender.CommandParameter)})
 }
 $script:connectionsWindow.FindName('ClaudeCodeSync').Add_Click({Toggle-OrbyClaudeCodeSync})
 $script:connectionsWindow.Add_Closed({$script:connectionsWindow=$null;$script:connectionControls=@{}})
 Update-OrbyConnections;$script:connectionsWindow.Show()
}
function Update-OrbyConnections {
 if($script:connectionsWindow){
  $script:connectionsWindow.FindName('ClaudeCodeSync').Content=if(Get-OrbyClaudeCodeSync){'Turn Code sync off'}else{'Enable Code sync'}
  $script:connectionsWindow.FindName('ClaudeCodeNote').Text=if($script:claudeCodeSetupNote){$script:claudeCodeSetupNote}else{'Code uses activity hooks. Chat follows its visible controls.'}
 }
 foreach($id in @('chatgpt','claude','gemini')){
  $snap=Get-OrbyProviderSnapshot $id
  $openAiConnected=$script:chatConnectionPresent -or ($script:usageSnapshot -and $script:usageSnapshot.Connected -and ([datetime]::UtcNow-$script:usageSnapshot.At).TotalSeconds -lt 180)
  if($script:connectionControls[$id]){$script:connectionControls[$id].Text=if($id -eq 'chatgpt' -and $openAiConnected){'Connected'}elseif($snap){$snap.Detail}else{'Open the app or browser and sign in'} }
 }
}
function Update-OrbyProviderState {
 $id=$script:orbySettings.PrimaryProvider;if(-not $script:providerCatalog.ContainsKey($id)){$id='chatgpt';$script:orbySettings.PrimaryProvider=$id}
 Update-OrbyConnections
 if($id -eq 'chatgpt'){$script:primaryProviderSnapshot=$null;$script:primaryProviderState=$null;Set-OrbyProviderIcon 'chatgpt';return}
 $script:primaryProviderSnapshot=Get-OrbyProviderSnapshot $id
 $state=if($script:primaryProviderSnapshot -and $script:primaryProviderSnapshot.StatusReadable){$script:primaryProviderSnapshot.State}else{'idle'}
 $script:primaryProviderState=$state
 foreach($renderer in @($script:avatarRenderer,$script:referenceRenderer)){if($renderer){$renderer.SetState($state,'Generating a response');$renderer.StatusConnected=[bool]$script:primaryProviderSnapshot.Connected}}
 Update-OrbyProviderView
}
function Update-OrbyProviderView {
 $id=$script:orbySettings.PrimaryProvider;if(-not $id -or $id -eq 'chatgpt' -or -not $script:referenceControls){return}
 $c=$script:referenceControls;$name=$script:providerCatalog[$id].Name;$snap=Get-OrbyProviderSnapshot $id
 $detail=if($snap){$snap.Detail}else{'Open '+$name+' to connect'}
 $c.RefTitle.Text=$name;$c.RefAction.Text=$detail;$c.RefDetail.Text='Local app status · beta'
 $c.RefConnection.Text=$name+' · '+$detail;$c.RefPillText0.Text=$name+' '+$(if($snap -and $snap.StatusReadable){$snap.State}else{'unavailable'})
 $c.RefAgents.Visibility=if($snap -and $snap.Connected){'Visible'}else{'Collapsed'};$c.RefAgents.ToolTip=$name+' · AI status (right-click to switch)'
 Set-OrbyProviderIcon $id
 $c.RefChatCard.Visibility=if($snap -and $snap.Connected){'Visible'}else{'Collapsed'};$c.RefCodexCard.Visibility='Collapsed'
 $c.RefChatColumn.Width=[Windows.GridLength]::new(1,[Windows.GridUnitType]::Star);$c.RefCodexColumn.Width=[Windows.GridLength]::new(0);$c.RefAgentGap.Width=[Windows.GridLength]::new(0)
 $c.RefAgentsEmpty.Visibility=if($snap -and $snap.Connected){'Collapsed'}else{'Visible'};$c.RefAgentsEmpty.Text=$detail
 $c.RefProviderName.Text=$name;$c.RefProviderLimitNote.Text='Account usage is not exposed by this app.'
 $c.RefAgentState.Text=if($snap -and $snap.StatusReadable){$snap.State}elseif($snap -and $snap.AppOpen){'App open'}else{'Waiting for activity'};$c.RefAgentTask.Text=$detail
 $c.RefNowChat.Visibility='Visible';$c.RefNowChat.Text=$name+' · '+$detail;$c.RefNowCodex.Visibility='Collapsed'
 $c.RefTokenValue.Text='—';$c.RefTokenScope.Text='Token activity not provided';$c.RefTrendLine.Points.Clear();$c.RefTrendCaption.Text='No account feed';$c.RefUsageNotice.Text='Local status';$c.RefQuotaNotice.Visibility='Collapsed'
 $ambient=if($script:primaryProviderState -eq 'working'){'#65A8C8FF'}elseif($script:primaryProviderState -eq 'attention'){'#85FFBA48'}else{'#60FFFFFF'}
 $c.RefOrbGlow.Color=[Windows.Media.ColorConverter]::ConvertFromString($ambient)
}
. (Join-Path $PSScriptRoot 'Multi-Provider.ps1')
Initialize-OrbyMultiProvider
$window.Add_ContentRendered({if(-not (Test-Path -LiteralPath $script:orbySettingsPath) -and -not $PerformanceCheck){Show-OrbyConnections}})
$window.Add_Closed({try{if($script:connectionsWindow){$script:connectionsWindow.Close()}}catch{};[OrbyBackgroundShutdown]::Stop($script:providerWorker,$script:providerRunspace)})
