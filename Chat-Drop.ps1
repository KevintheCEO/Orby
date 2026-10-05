$script:dropFiles=@()
$script:dropLeaveTimer=New-Object Windows.Threading.DispatcherTimer
$script:dropLeaveTimer.Interval=[timespan]::FromMilliseconds(350)
$script:dropLeaveTimer.Add_Tick({$script:dropLeaveTimer.Stop();if(-not $script:dropFiles.Count -and -not $script:dropHandle -and -not $window.IsMouseOver){$script:dropBusy=$false;Update-OrbyEventCard}})
$window.AllowDrop=$true
$window.AddHandler([Windows.DragDrop]::PreviewDragOverEvent,[Windows.DragEventHandler]{param($sender,$e)
 if($e.Data.GetDataPresent([Windows.DataFormats]::FileDrop)){
  $script:dropLeaveTimer.Stop();$e.Effects=[Windows.DragDropEffects]::Copy;$e.Handled=$true
  if(-not $script:dropBusy){Write-OrbitLog 'FILE DRAG composer entered';$script:dropBusy=$true;Update-OrbyEventCard;$script:eventControls.EventTitle.Text='Drop files here';$script:eventControls.EventDetail.Text='Then type a prompt for ChatGPT'}
 }else{$e.Effects=[Windows.DragDropEffects]::None}
},$true)
$window.Add_DragLeave({if(-not $script:dropHandle -and -not $script:dropFiles.Count){$script:dropLeaveTimer.Stop();$script:dropLeaveTimer.Start()}})
function Set-OrbyDroppedFiles {
 param([string[]]$Paths)
 $files=@($Paths | Where-Object {[IO.File]::Exists($_)})
 if(-not $files.Count){return $false}
 if($files.Count -gt 20){$script:eventControls.EventDetail.Text='Drop at most 20 files at once.';return $false}
 $script:dropFiles=$files;$script:dropBusy=$true;Update-OrbyEventCard;Show-OrbyDropComposer
 $script:eventControls.EventTitle.Text=($files | ForEach-Object {[IO.Path]::GetFileName($_)}) -join ', '
 $script:eventControls.EventTitle.ToolTip=$script:eventControls.EventTitle.Text
 $script:dropControls.DropStatus.Text='Files ready - type your prompt'
 $script:eventControls.EventDetail.Visibility='Collapsed'
 $script:dropControls.DropPrompt.Visibility='Visible';$script:dropControls.DropPrompt.IsEnabled=$true
 $script:dropControls.DropSend.Content=[char]0x2191;$script:dropControls.DropSend.IsEnabled=$true
 return $true
}
$window.AddHandler([Windows.DragDrop]::PreviewDropEvent,[Windows.DragEventHandler]{param($sender,$e)
 $e.Handled=$true;Write-OrbitLog 'FILE DROP received';if($script:dropHandle){return}
 if(Set-OrbyDroppedFiles @($e.Data.GetData([Windows.DataFormats]::FileDrop))){
  $window.Focusable=$true;[void]$window.Activate();[void]$script:dropControls.DropPrompt.Focus()
 }
},$true)
function Submit-OrbyDropPrompt {
 if($script:dropHandle){return}
 $prompt=$script:dropControls.DropPrompt.Text.Trim()
 if(-not $prompt -or -not $script:dropFiles.Count){$script:dropControls.DropPrompt.ToolTip='Type your prompt first';return}
 if(@($script:dropFiles | Where-Object {-not [IO.File]::Exists($_)}).Count){$script:dropControls.DropStatus.Text='A file moved or was deleted. Drop the files again.';return}
 $script:dropControls.DropPrompt.IsEnabled=$false;$script:dropControls.DropSend.IsEnabled=$false;$script:eventControls.EventDismiss.IsEnabled=$false
 $script:dropControls.DropStatus.Text='Opening a new chat and attaching files...'
 $script:dropRunspace=[runspacefactory]::CreateRunspace();$script:dropRunspace.ApartmentState='STA';$script:dropRunspace.Open()
 $script:dropWorker=[powershell]::Create();$script:dropWorker.Runspace=$script:dropRunspace
 [void]$script:dropWorker.AddScript([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Chat-Drop-Worker.ps1'))).AddArgument($script:dropFiles).AddArgument($prompt).AddArgument($PSScriptRoot)
 $script:dropHandle=$script:dropWorker.BeginInvoke()
}
$script:dropControls.DropPrompt.Add_PreviewKeyDown({param($sender,$e)
 if($e.Key -eq [Windows.Input.Key]::Enter -and -not ([Windows.Input.Keyboard]::Modifiers -band [Windows.Input.ModifierKeys]::Shift)){$e.Handled=$true;Submit-OrbyDropPrompt}
})
$script:dropPoll=New-Object Windows.Threading.DispatcherTimer
$script:dropPoll.Interval=[timespan]::FromMilliseconds(500)
$script:dropPoll.Add_Tick({
 if($script:dropHandle -and $script:dropHandle.IsCompleted){
  try{$result=$script:dropWorker.EndInvoke($script:dropHandle);$result=$result | Select-Object -Last 1}catch{$result=[pscustomobject]@{Sent=$false;Message='Handoff failed. Your prompt and files remain here.'}}
  $script:dropControls.DropStatus.Text=$result.Message;$script:dropControls.DropStatus.ToolTip=$result.Message
  Write-OrbitLog ('FILE HANDOFF sent='+$result.Sent+' '+$result.Message)
  $script:dropWorker.Dispose();$script:dropRunspace.Dispose();$script:dropHandle=$null
  $script:eventControls.EventDismiss.IsEnabled=$true
  if($result.Sent){$script:dropFiles=@();$script:dropControls.DropPrompt.Text='';$script:dropControls.DropPrompt.Visibility='Collapsed'}
  else{$script:dropControls.DropPrompt.IsEnabled=$true;$script:dropControls.DropSend.IsEnabled=(-not $result.RequiresReview);$script:dropControls.DropSend.Content=[char]0x2191}
 }
})
$script:dropPoll.Start()
$window.Add_Closed({$script:dropPoll.Stop();if($script:dropWorker){$script:dropWorker.Dispose()};if($script:dropRunspace){$script:dropRunspace.Dispose()}})
