$script:dropFiles=@();$script:dropProvider=''
$script:dropLeaveTimer=New-Object Windows.Threading.DispatcherTimer
$script:dropLeaveTimer.Interval=[timespan]::FromMilliseconds(350)
$script:dropLeaveTimer.Add_Tick({$script:dropLeaveTimer.Stop();if(-not $script:dropFiles.Count -and -not $script:dropHandle -and -not $window.IsMouseOver){Close-OrbyDropComposer}})
$window.AllowDrop=$true
$window.AddHandler([Windows.DragDrop]::PreviewDragOverEvent,[Windows.DragEventHandler]{param($sender,$e)
 if($e.Data.GetDataPresent([Windows.DataFormats]::FileDrop) -and -not $script:dropHandle){
  $script:dropLeaveTimer.Stop();$e.Effects=[Windows.DragDropEffects]::Copy;$e.Handled=$true
  if(-not $script:dropBusy){$script:dropBusy=$true;Update-OrbyEventCard}
 }else{$e.Effects=[Windows.DragDropEffects]::None}
},$true)
$window.Add_DragLeave({if(-not $script:dropHandle -and -not $script:dropFiles.Count){$script:dropLeaveTimer.Stop();$script:dropLeaveTimer.Start()}})
function Set-OrbyDroppedFiles {
 param([string[]]$Paths)
 if($script:dropHandle){return $false}
 $files=@($Paths | Where-Object {[IO.File]::Exists($_)} | ForEach-Object {[IO.Path]::GetFullPath($_)} | Select-Object -Unique)
 if(-not $files.Count -or $files.Count -gt 20){Close-OrbyDropComposer;return $false}
 $script:dropFiles=$files;$script:dropProvider='';$script:dropBusy=$true;$script:dropRequiresReview=$false
 $script:dropControls.DropPrompt.Text='';$script:dropControls.DropEditor.Visibility='Collapsed'
 $script:dropControls.DropHeading.Text='Choose an AI';$script:dropControls.DropStatus.Text='Select where to send these files.'
 Update-OrbyEventCard;Show-OrbyDropComposer
 return $true
}
$window.AddHandler([Windows.DragDrop]::PreviewDropEvent,[Windows.DragEventHandler]{param($sender,$e)
 $e.Handled=$true
 if($e.Data.GetDataPresent([Windows.DataFormats]::FileDrop) -and (Set-OrbyDroppedFiles @($e.Data.GetData([Windows.DataFormats]::FileDrop)))){$window.Focusable=$true;[void]$window.Activate()}
},$true)
function Submit-OrbyDropPrompt {
 if($script:dropHandle -or $script:dropRequiresReview -or -not $script:dropFiles.Count){return}
 if($script:dropProvider -notin @('chatgpt','claude','gemini') -or $script:dropProvider -notin ($script:orbySettings.ProviderEnabled -split ',')){$script:dropControls.DropStatus.Text='Choose a connected AI first.';return}
 if(@($script:dropFiles | Where-Object {-not [IO.File]::Exists($_)}).Count){$script:dropControls.DropStatus.Text='A file moved or was deleted. Drop the files again.';return}
 $script:dropControls.DropPrompt.IsEnabled=$false;$script:dropControls.DropSend.IsEnabled=$false
 foreach($button in $script:dropControls.DropProviders.Children){$button.IsEnabled=$false}
 $script:dropControls.DropStatus.Text='Opening '+$script:providerCatalog[$script:dropProvider].Name+' and attaching files...'
 $script:dropOperation=[hashtable]::Synchronized(@{Cancelled=$false;SendInvoked=$false;Stage='Opening app';Started=[datetime]::UtcNow})
 try{
 $script:dropRunspace=[runspacefactory]::CreateRunspace();$script:dropRunspace.ApartmentState='STA';$script:dropRunspace.Open()
 $script:dropWorker=[powershell]::Create();$script:dropWorker.Runspace=$script:dropRunspace
 [void]$script:dropWorker.AddScript([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Chat-Drop-Worker.ps1'))).AddArgument($script:dropFiles).AddArgument($script:dropControls.DropPrompt.Text.Trim()).AddArgument($PSScriptRoot).AddArgument($script:dropProvider).AddArgument($script:dropOperation)
 $script:dropHandle=$script:dropWorker.BeginInvoke()
 }catch{
  [OrbyBackgroundShutdown]::Stop($script:dropWorker,$script:dropRunspace)
  $script:dropWorker=$null;$script:dropRunspace=$null;$script:dropHandle=$null
  Complete-OrbyDropHandoff ([pscustomobject]@{Sent=$false;RequiresReview=$false;Message='Could not start the handoff. Close and try again.'})
 }
}
function Complete-OrbyDropHandoff($Result){
 if($Result.Sent){Close-OrbyDropComposer;return}
 $script:dropRequiresReview=[bool]$Result.RequiresReview;Show-OrbyDropComposer
 if($script:dropRequiresReview){foreach($button in $script:dropControls.DropProviders.Children){$button.IsEnabled=$false}}
 $script:dropControls.DropStatus.Text=$Result.Message;$script:dropControls.DropStatus.ToolTip=$Result.Message
 $script:dropControls.DropPrompt.IsEnabled=(-not $Result.RequiresReview)
 $script:dropControls.DropSend.IsEnabled=(-not $Result.RequiresReview)
 # Never automatically retry: an upload or send may already exist in the selected app.
 if($Result.RequiresReview){$script:dropControls.DropStatus.Text+=' Check the opened app; close this panel before trying again.'}
}
$script:dropControls.DropPrompt.Add_PreviewKeyDown({param($sender,$e)
 if($e.Key -eq [Windows.Input.Key]::Escape){$e.Handled=$true;Close-OrbyDropComposer}
 elseif($e.Key -eq [Windows.Input.Key]::Enter -and -not ([Windows.Input.Keyboard]::Modifiers -band [Windows.Input.ModifierKeys]::Shift)){$e.Handled=$true;Submit-OrbyDropPrompt}
})
$script:dropPoll=New-Object Windows.Threading.DispatcherTimer
$script:dropPoll.Interval=[timespan]::FromMilliseconds(250)
$script:dropPoll.Add_Tick({
 if(-not $script:dropHandle){return}
 if($script:dropHandle.IsCompleted){
  try{$result=@($script:dropWorker.EndInvoke($script:dropHandle)) | Select-Object -Last 1;if(-not $result -or -not $result.PSObject.Properties['Sent']){throw 'No handoff result'}}catch{$result=[pscustomobject]@{Sent=$false;RequiresReview=[bool]$script:dropOperation.SendInvoked;Message='Handoff stopped. Check the selected app.'}}
  $script:dropWorker.Dispose();$script:dropRunspace.Dispose();$script:dropHandle=$null;$script:dropWorker=$null;$script:dropRunspace=$null
  Write-OrbitLog ('FILE HANDOFF provider='+$script:dropProvider+' sent='+$result.Sent+' elapsedMs='+$script:dropOperation.ElapsedMs+' timings='+(@($script:dropOperation.Timings | ForEach-Object {$_.Stage+'@'+$_.AtMs}) -join ','))
  Complete-OrbyDropHandoff $result
 }elseif(([datetime]::UtcNow-$script:dropOperation.Started).TotalSeconds -gt 90){
  $script:dropOperation.Cancelled=$true
  [OrbyBackgroundShutdown]::Stop($script:dropWorker,$script:dropRunspace)
  $script:dropHandle=$null;$script:dropWorker=$null;$script:dropRunspace=$null
  Complete-OrbyDropHandoff ([pscustomobject]@{Sent=$false;RequiresReview=$true;Message='The app took too long. Nothing will be retried automatically.'})
 }else{$script:dropControls.DropStatus.Text=$script:dropOperation.Stage+'...'}
})
$script:dropPoll.Start()
$window.Add_Closed({$script:dropPoll.Stop();$script:dropLeaveTimer.Stop();if($script:dropOperation){$script:dropOperation.Cancelled=$true};[OrbyBackgroundShutdown]::Stop($script:dropWorker,$script:dropRunspace)})
