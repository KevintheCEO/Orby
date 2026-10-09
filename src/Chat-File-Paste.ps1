function New-OrbyFileClipboard {
 param([string[]]$Files,[string]$Token)
 $items=New-Object Collections.Specialized.StringCollection
 foreach($file in $Files){
  if(-not [IO.File]::Exists($file)){throw 'A dropped file no longer exists'}
  [void]$items.Add([IO.Path]::GetFullPath($file))
 }
 $data=New-Object Windows.Forms.DataObject
 $data.SetFileDropList($items)
 $data.SetData('Orby.FileTransfer.Token',$Token)
 return $data
}
function Save-OrbyClipboard {
 $saved=New-Object Windows.Forms.DataObject
 $current=[Windows.Forms.Clipboard]::GetDataObject()
 if($current){
  foreach($format in $current.GetFormats($false)){
   # Materialize before replacing the clipboard; do not retain a delayed COM object.
   $value=$current.GetData($format,$false)
   if($null -ne $value){$saved.SetData($format,$false,$value)}
  }
 }
 return $saved
}
function Restore-OrbyClipboard {
 param($Saved,[string]$Token)
 $current=[Windows.Forms.Clipboard]::GetDataObject()
 if($current -and $current.GetDataPresent('Orby.FileTransfer.Token') -and $current.GetData('Orby.FileTransfer.Token') -eq $Token){
  [Windows.Forms.Clipboard]::SetDataObject($Saved,$true)
 }
}
function Paste-OrbyFiles {
 param($Composer,[string[]]$Files,[IntPtr]$ChatHwnd)
 $Composer.SetFocus()
 Start-Sleep -Milliseconds 150
 $focused=[Windows.Automation.AutomationElement]::FocusedElement
 if([OrbyChatWindow]::GetForegroundWindow() -ne $ChatHwnd -or -not $focused -or
    (Get-OrbyComposerRank $focused.Current.Name $focused.Current.AutomationId $focused.Current.ClassName) -le 0){
  throw 'ChatGPT message box did not receive keyboard focus. Nothing was pasted'
 }
 $saved=Save-OrbyClipboard
 $token=[guid]::NewGuid().ToString()
 $data=New-OrbyFileClipboard $Files $token
 [Windows.Forms.Clipboard]::SetDataObject($data,$true)
 # Store restoration state before sending a key, including a failed SendWait.
 $script:orbyClipboardSaved=$saved;$script:orbyClipboardToken=$token
 [Windows.Forms.SendKeys]::SendWait('^v')
}
