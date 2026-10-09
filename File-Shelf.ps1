Add-Type -Path (Join-Path $PSScriptRoot 'File-Inbox.cs')
$script:orbyInbox=Join-Path $logDir 'inbox'
$script:orbyCopies=New-Object System.Collections.Generic.List[object]
$script:orbyShelfSignature='';$script:shelfPollAt=[datetime]::MinValue
function Add-OrbyShelfFile {
 param([string]$Path)
 try{$task=[OrbyFileInbox]::CopyAsync($Path,$script:orbyInbox);$script:orbyCopies.Add($task);$script:desktopControls.ShelfMessage.Text='Copying locally...'}
 catch{$script:desktopControls.ShelfMessage.Text=$_.Exception.Message}
}
function Update-OrbyShelf {
 for($i=$script:orbyCopies.Count-1;$i -ge 0;$i--){
  $task=$script:orbyCopies[$i];if(-not $task.IsCompleted){continue}
  if($task.IsFaulted){$script:desktopControls.ShelfMessage.Text=$task.Exception.GetBaseException().Message}
  else{$script:desktopControls.ShelfMessage.Text='Saved '+$task.Result.Name+' to your local shelf';Add-OrbyAlert 'file' 'File added' $task.Result.Name}
  $script:orbyCopies.RemoveAt($i)
 }
 if(-not $script:desktopControls){return}
 if($script:shelfInventoryTask -and $script:shelfInventoryTask.IsCompleted){
  if(-not $script:shelfInventoryTask.IsFaulted -and $script:shelfInventoryTask.Result.Valid){
   $files=$script:shelfInventoryTask.Result.Files
   $signature=($files | ForEach-Object {$_.FullName+'|'+$_.Length+'|'+$_.LastWriteTimeUtc.Ticks}) -join ';'
   if($signature -ne $script:orbyShelfSignature){$script:orbyShelfSignature=$signature
    $selected=$script:desktopControls.ShelfList.SelectedItem.Path
    $script:desktopControls.ShelfList.ItemsSource=@($files | ForEach-Object {[pscustomobject]@{Path=$_.FullName;Display=$_.Name+'  |  '+[math]::Round($_.Length/1KB,1)+' KB'}})
    $script:desktopControls.ShelfList.SelectedItem=@($script:desktopControls.ShelfList.Items | Where-Object {$_.Path -eq $selected}) | Select-Object -First 1
   }
  }
  $script:shelfInventoryTask=$null
 }
 if(-not $script:shelfInventoryTask -and ([datetime]::UtcNow-$script:shelfPollAt).TotalSeconds -ge 3){$script:shelfPollAt=[datetime]::UtcNow;$script:shelfInventoryTask=[OrbyFileInventory]::Poll($script:orbyInbox,100)}
}

