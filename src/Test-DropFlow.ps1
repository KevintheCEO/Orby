param([string]$PreviewDirectory='')
$ErrorActionPreference='Stop'
$dropPreview=$PreviewDirectory
. (Join-Path $PSScriptRoot 'Test-AllLargeMenus.ps1') -KeepWindow
$PreviewDirectory=$dropPreview
. (Join-Path $PSScriptRoot 'UI-Recovery.ps1')
Add-Type -AssemblyName System.Windows.Forms,UIAutomationClient,UIAutomationTypes
function Write-OrbitLog($Text){}
$script:eventCard=[Windows.Controls.Border]::new();$script:eventControls=@{EventDismiss=[Windows.Controls.Button]::new()}
function Update-OrbyEventCard {
 $script:orbyEventMode=if($script:dropBusy){'drop'}else{''}
 if($script:dropBusy){Show-OrbyDropComposer}
 Update-OrbyCompactMenus
}
. (Join-Path $PSScriptRoot 'Drop-Composer.ps1')
. (Join-Path $PSScriptRoot 'Chat-Drop.ps1')
. (Join-Path $PSScriptRoot 'Drop-Providers.ps1')
. (Join-Path $PSScriptRoot 'Chat-Control-Matching.ps1')
$script:dropChecks=0
function CheckDrop($Value,[string]$Why){if(-not $Value){throw $Why};$script:dropChecks++}
$script:orbySettings.ProviderEnabled='chatgpt,claude,gemini'
$fixture=Join-Path $env:TEMP ('orby-drop-test-'+[guid]::NewGuid().ToString('N')+'.txt')
[IO.File]::WriteAllText($fixture,'Orby automated drop fixture. Do not send to a live service.')
try{
 CheckDrop (Set-OrbyDroppedFiles @($fixture)) 'Valid file rejected'
 CheckDrop ($script:dropControls.DropProviders.Children.Count -eq 3) 'Three providers not shown'
 CheckDrop ($script:dropControls.DropEditor.Visibility -eq 'Collapsed' -and -not $script:dropProvider) 'Message shown before choosing AI'
 foreach($id in @('chatgpt','claude','gemini')){
  $button=$script:dropControls.DropProviders.Children | Where-Object {$_.Tag -eq $id}
  CheckDrop ($button.Content.Children[0].Data -ne $null) 'Provider logo missing'
  $button.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
  CheckDrop ($script:dropProvider -eq $id -and $script:dropControls.DropEditor.Visibility -eq 'Visible') 'Provider choice failed'
  CheckDrop ($script:dropControls.DropPrompt.Text -eq '' -and $script:dropControls.DropSend.IsEnabled) 'File-only send disabled'
  Update-OrbyCompactMenus;Layout
  CheckDrop ($expandedArea.Height -eq 322 -and $script:dropPanel.Margin.Top -ge 0) 'Drop layout still clipped'
  foreach($control in @($script:dropControls.DropClose,$script:dropControls.DropPrompt,$script:dropControls.DropSend)){
   $point=$control.TranslatePoint([Windows.Point]::new($control.ActualWidth-1,$control.ActualHeight-1),$notch)
   CheckDrop ($notch.Clip.FillContains($point)) 'Drop control outside notch'
  }
 }
 if($PreviewDirectory){
  [void][IO.Directory]::CreateDirectory($PreviewDirectory)
  $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new(668,384,96,96,[Windows.Media.PixelFormats]::Pbgra32);$bitmap.Render($window.Content)
  $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap));$stream=[IO.File]::Create((Join-Path $PreviewDirectory 'drop-composer-actual.png'));try{$encoder.Save($stream)}finally{$stream.Dispose()}
 }
 $script:dropControls.DropPrompt.Text='Keep this draft'
 $script:dropControls.DropClear.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
 CheckDrop (-not $script:dropProvider -and $script:dropFiles.Count -eq 1 -and $script:dropControls.DropPrompt.Text -eq 'Keep this draft') 'Back lost files or draft'
 Select-OrbyDropProvider 'chatgpt'
 $operation=[hashtable]::Synchronized(@{Cancelled=$false;SendInvoked=$false;Stage='Fixture';Started=[datetime]::UtcNow})
 $script:dropOperation=$operation
 $script:dropRunspace=[runspacefactory]::CreateRunspace();$script:dropRunspace.Open();$script:dropWorker=[powershell]::Create();$script:dropWorker.Runspace=$script:dropRunspace;[void]$script:dropWorker.AddScript('Start-Sleep -Seconds 15');$script:dropHandle=$script:dropWorker.BeginInvoke()
 $watch=[Diagnostics.Stopwatch]::StartNew();Close-OrbyDropComposer;$watch.Stop()
 CheckDrop ($watch.ElapsedMilliseconds -lt 500 -and $operation.Cancelled) 'Close blocked waiting for worker'
 CheckDrop (-not $script:dropBusy -and -not $script:dropHandle -and $script:dropPanel.Visibility -eq 'Collapsed' -and $script:compactMenuPage -eq 'home') 'Close did not restore home'
 [void](Set-OrbyDroppedFiles @($fixture));Select-OrbyDropProvider 'claude'
 Complete-OrbyDropHandoff ([pscustomobject]@{Sent=$false;RequiresReview=$true;Message='Send outcome unknown'})
 CheckDrop (-not $script:dropControls.DropSend.IsEnabled -and $script:dropFiles.Count -eq 1) 'Ambiguous send allowed duplicate retry'
 $script:dropControls.DropClear.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
 CheckDrop (-not $script:dropBusy) 'Back from an ambiguous send did not safely leave the composer'
 [void](Set-OrbyDroppedFiles @($fixture));Select-OrbyDropProvider 'gemini'
 Complete-OrbyDropHandoff ([pscustomobject]@{Sent=$true;Message='Sent fixture'})
 CheckDrop (-not $script:dropBusy -and $script:dropFiles.Count -eq 0 -and $script:dropControls.DropPrompt.Text -eq '' -and $script:compactMenuPage -eq 'home') 'Successful send left composer stuck'
 $script:orbySettings.ProviderEnabled='gemini';[void](Set-OrbyDroppedFiles @($fixture))
 CheckDrop ($script:dropControls.DropProviders.Children[2].IsEnabled -and -not $script:dropControls.DropProviders.Children[0].IsEnabled) 'Disconnected AI can be selected'
 Select-OrbyDropProvider 'chatgpt';CheckDrop (-not $script:dropProvider) 'Disconnected selection accepted'
 Close-OrbyDropComposer
 CheckDrop (-not (Set-OrbyDroppedFiles @($fixture+'.missing'))) 'Missing file accepted'
 foreach($id in @('chatgpt','claude','gemini')){
  $adapter=Get-OrbyDropAdapter $id
  CheckDrop (Test-OrbyDropUrl $adapter.Url $adapter.Host) 'Official provider URL rejected'
  CheckDrop (-not (Test-OrbyDropUrl ('https://'+$adapter.Host+'.example.org/') $adapter.Host)) 'Lookalike origin accepted'
  CheckDrop (-not (Test-OrbyDropUrl ('http://'+$adapter.Host+'/') $adapter.Host)) 'HTTP origin accepted'
  CheckDrop (-not (Test-OrbyDropUrl ('https://'+$adapter.Host+'/settings/usage') $adapter.Host)) 'Settings page accepted as chat'
 }
 foreach($case in @(@('New','claude',$true),@('New','chatgpt',$false),@('New folder','claude',$false),@('Start a new chat','gemini',$true),@('New chat','chatgpt',$true))){CheckDrop ((Test-OrbyNewChatLabel $case[0] '' '' $case[1]) -eq $case[2]) 'Provider new-chat name regression'}
 CheckDrop ((Get-OrbyComposerRank 'Write your prompt to Claude' '' '') -gt 0) 'Current Claude composer is not recognized'
 CheckDrop ((Resolve-OrbyComposerText 'Enter a prompt for Gemini' "Ask Gemini`n" "Ask Gemini`n" $true) -eq '') 'Gemini empty hint was mistaken for a draft'
 CheckDrop ((Resolve-OrbyComposerText 'Enter a prompt for Gemini' 'Ask Gemini' 'Ask Gemini' $true $false) -eq 'Ask Gemini') 'Literal user prompt was erased by placeholder detection'
 CheckDrop ((Resolve-OrbyComposerText 'Enter a prompt for Gemini' 'Actual user draft' 'Actual user draft' $true) -eq 'Actual user draft') 'Real Gemini draft was ignored'
 foreach($case in @(@('orby-gemin...2556E-test','orby-gemini-ORBY_HANDOFF_46F2556E-test.txt',$true),@('orby-gemin...WRONG-test','orby-gemini-ORBY_HANDOFF_46F2556E-test.txt',$false),@('report','report.pdf',$true),@('report.pdf','report.pdf',$true),@('TXT','report.txt',$false),@('...','report.txt',$false))){CheckDrop ((Test-OrbyDropPreviewLabel $case[0] $case[1]) -eq $case[2]) 'Truncated attachment label matching failed'}
 foreach($label in @('Message ChatGPT','Reply to Claude','Ask Gemini')){CheckDrop ((Get-OrbyComposerRank $label '' '') -gt 0) 'Provider message box not recognized'}
 CheckDrop ((Get-OrbyComposerRank 'Search chats' '' '') -eq 0) 'Search box accepted as composer'
 $Operation=@{Cancelled=$true};try{Assert-OrbyDropActive;throw 'Cancellation ignored'}catch{CheckDrop ($_.Exception.Message -eq 'Handoff cancelled') 'Cancellation ignored'}
 $ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'Event-Cards.ps1'),[ref]$null,[ref]$null)
 $functionNode=$ast.Find({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Update-OrbyEventCard'},$true)
 $script:eventUpdateCore=$functionNode.Body.GetScriptBlock()
 function Set-OrbyEventUnderlay($Value){}
 function Update-OrbyEventCard {& $script:eventUpdateCore;Update-OrbyCompactMenus}
 $script:orbySettings.ProviderEnabled='gemini';$script:orbyEventMode='drop';$script:dropBusy=$false
 Update-OrbyEventCard
 CheckDrop (-not $script:orbyEventMode -and $script:compactMenus.Visibility -eq 'Visible') 'Gemini-only Close left an invisible overlay blocking Home'
 $invalid=& (Join-Path $PSScriptRoot 'Chat-Drop-Worker.ps1') -Files @($fixture+'.missing') -Prompt '' -BaseDirectory $PSScriptRoot -Provider 'claude'
 CheckDrop (-not $invalid.Sent -and -not $invalid.RequiresReview) 'Missing-file worker did not fail before launch'
 "PASS: $script:dropChecks drop-flow checks; no live requests sent."
}finally{Close-OrbyDropComposer;$script:dropPoll.Stop();$script:dropLeaveTimer.Stop();$window.Close();Remove-Item -LiteralPath $fixture -Force}
