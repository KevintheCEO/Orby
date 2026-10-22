. (Join-Path $PSScriptRoot 'UI-Recovery.ps1')
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework
Add-Type -Path (Join-Path $PSScriptRoot 'Provider-Reader.cs') -ReferencedAssemblies UIAutomationClient,UIAutomationTypes,WindowsBase,System.Core
. (Join-Path $PSScriptRoot 'Provider-Icons.ps1')
. (Join-Path $PSScriptRoot 'Claude-Sync.ps1')
function Assert($ok,$message){if(-not $ok){throw $message}}
Assert ([OrbyProviderReader]::ProviderFor('chrome','https://claude.ai/new') -eq 'claude') 'Claude canonical domain'
Assert ([OrbyProviderReader]::ProviderFor('msedge','https://gemini.google.com/app') -eq 'gemini') 'Gemini canonical domain'
Assert ([OrbyProviderReader]::ProviderFor('chrome','https://claude.ai.attacker.invalid') -eq '') 'Lookalike domain trusted'
Assert ([OrbyProviderReader]::ProviderFor('chrome','http://claude.ai/') -eq '') 'Insecure URL trusted'
Assert ([OrbyProviderReader]::Classify($true,[string[]]@('Stop generating')) -eq 'working') 'Generating control missed'
Assert ([OrbyProviderReader]::Classify($false,[string[]]@('Stop generating')) -eq 'unknown') 'No composer falsely connected'
Assert ([OrbyProviderReader]::Classify($true,[string[]]@('Allow once','Deny','Reminder')) -eq 'idle') 'Reminder mistaken for approval'
Assert ([OrbyProviderReader]::Classify($true,[string[]]@('Send')) -eq 'idle') 'Idle composer missed'
Assert ([OrbyProviderReader]::Classify($true,[string[]]@('Send','Sign in with Google')) -eq 'unknown') 'Sign-in screen marked connected'
# Load the view functions without starting the polling worker.
$source=Get-Content (Join-Path $PSScriptRoot 'Providers.ps1') -Raw
$functions=$source.Substring($source.IndexOf('function Get-OrbyProviderSnapshot'),$source.IndexOf('. (Join-Path $PSScriptRoot ''Multi-Provider.ps1'')')-$source.IndexOf('function Get-OrbyProviderSnapshot'))
. ([scriptblock]::Create($functions))
$script:providerCatalog=@{claude=@{Name='Claude'};gemini=@{Name='Gemini'}}
$script:orbySettings=@{PrimaryProvider='claude'};$script:orbyShared=@{ProviderSnapshots=@([OrbyProviderSnapshot]@{Provider='claude';Connected=$true;StatusReadable=$true;State='working';Detail='Generating a response';At=[datetime]::UtcNow})}
[xml]$x=Get-Content (Join-Path $PSScriptRoot 'Reference-Home.xaml') -Raw;$ui=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($x));$script:referenceControls=@{}
foreach($m in [regex]::Matches($x.OuterXml,'x:Name="([^"]+)"')){$n=$m.Groups[1].Value;$script:referenceControls[$n]=$ui.FindName($n)}
$script:providerDirectory=$PSScriptRoot;Initialize-OrbyProviderIcons
$script:primaryProviderState='working';Update-OrbyProviderView
Assert ($script:referenceControls.RefProviderName.Text -eq 'Claude') 'Wrong provider label'
Assert ($script:referenceControls.RefProviderIcon.Data -eq $script:providerIconResources['ClaudeLogo']) 'Claude logo missing'
Assert ($script:referenceControls.RefProviderGlyph.Visibility -eq 'Collapsed') 'Generic symbol still visible'
Assert ($script:referenceControls.RefCodexCard.Visibility -eq 'Collapsed') 'ChatGPT usage leaked into Claude'
Assert ($script:referenceControls.RefTokenValue.Text -eq '—') 'Fabricated Claude token count'
$script:orbyShared.ProviderSnapshots[0].At=[datetime]::UtcNow.AddSeconds(-12);Update-OrbyProviderView
Assert ($script:referenceControls.RefChatCard.Visibility -eq 'Collapsed') 'Stale connected card retained'
Assert (-not (Get-OrbyProviderSnapshot 'claude')) 'Stale LIVE snapshot retained'
$script:orbySettings.PrimaryProvider='gemini';$script:orbyShared.ProviderSnapshots=@([OrbyProviderSnapshot]@{Provider='gemini';Connected=$true;StatusReadable=$true;State='idle';Detail='Connected';At=[datetime]::UtcNow})
Update-OrbyProviderView
Assert ($script:referenceControls.RefProviderIcon.Data -eq $script:providerIconResources['GeminiLogo'] -and $script:referenceControls.RefProviderName.Text -eq 'Gemini') 'Gemini switch did not update name/logo'
Set-OrbyProviderIcon 'chatgpt'
Assert ($script:referenceControls.RefProviderIcon.Data -eq $script:openAiLogo) 'Switch back retained another provider logo'
[xml]$connection=Get-Content (Join-Path $PSScriptRoot 'Connections.xaml') -Raw;$dialog=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($connection));$dialog.Measure([Windows.Size]::new(510,560));$dialog.Arrange([Windows.Rect]::new(0,0,510,560));$dialog.UpdateLayout()
Assert ($null -ne $dialog.FindName('ConnectGemini')) 'Gemini setup unavailable'
function Save-OrbySettings {$script:providerSaved=$true}
$script:providerDirectory=$PSScriptRoot
function Open-OrbyProvider {param($Id) $script:providerOpened=$Id}
$script:providerCatalog.chatgpt=@{Name='ChatGPT';Download='https://chatgpt.com/download/'}
$script:orbySettings.ProviderEnabled='chatgpt'
$script:providerIconResources=$null
Show-OrbyConnections
$script:connectionsWindow.FindName('ConnectGemini').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
Assert ($script:orbySettings.PrimaryProvider -eq 'gemini' -and $script:providerOpened -eq 'gemini' -and $script:providerSaved) 'Connect button does not route and save the chosen provider'
function Get-OrbyClaudeCodeSync {return [bool]$script:testCodeEnabled}
function Set-OrbyClaudeCodeSync {param([bool]$Enabled) $script:testCodeEnabled=$Enabled}
$script:connectionsWindow.FindName('ClaudeCodeSync').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
Assert ($script:testCodeEnabled -and 'claude' -in ($script:orbySettings.ProviderEnabled -split ',') -and 'chatgpt' -in ($script:orbySettings.ProviderEnabled -split ',')) 'Code pairing button disconnected another AI'
Assert ($script:connectionsWindow.FindName('ClaudeCodeSync').Content -eq 'Turn Code sync off') 'Code button did not update after pairing'
$script:connectionsWindow.FindName('ClaudeCodeSync').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
Assert (-not $script:testCodeEnabled -and $script:connectionsWindow.FindName('ClaudeCodeSync').Content -eq 'Enable Code sync') 'Code unpairing button not interactive'
$script:connectionsWindow.Close()
Write-Output 'PASS: identity, status, no false approval, stale expiry, provider UI and connection picker'
