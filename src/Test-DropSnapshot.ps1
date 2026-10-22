$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,UIAutomationClient,UIAutomationTypes,System.Windows.Forms
Add-Type -Path (Join-Path $PSScriptRoot 'Drop-Transfer.cs') -ReferencedAssemblies UIAutomationClient,UIAutomationTypes,WindowsBase,System.Core,System.Windows.Forms
. (Join-Path $PSScriptRoot 'Drop-Providers.ps1');. (Join-Path $PSScriptRoot 'Drop-Fast.ps1')
$window=[Windows.Window]::new();$window.Width=600;$window.Height=550;$outer=[Windows.Controls.StackPanel]::new();$window.Content=$outer
$history=[Windows.Controls.TextBlock]::new();[void]$outer.Children.Add($history)
$group=[Windows.Controls.GroupBox]::new();[void]$outer.Children.Add($group);$panel=[Windows.Controls.StackPanel]::new();$group.Content=$panel
$upload=[Windows.Controls.Button]::new();$upload.Content='Add files and more';[void]$panel.Children.Add($upload)
$label=[Windows.Controls.TextBlock]::new();[void]$panel.Children.Add($label)
$composer=[Windows.Controls.TextBox]::new();[void]$panel.Children.Add($composer);[Windows.Automation.AutomationProperties]::SetName($composer,'Ask ChatGPT')
$progress=[Windows.Controls.ProgressBar]::new();$progress.Height=8;$progress.Visibility='Collapsed';[void]$panel.Children.Add($progress)
$outside=[Windows.Controls.ProgressBar]::new();$outside.Height=8;[void]$outer.Children.Add($outside)
$checks=0
function Check($ok,$why){if(-not $ok){throw $why};$script:checks++}
try{
 $window.Show();$window.UpdateLayout();$handle=[Windows.Interop.WindowInteropHelper]::new($window).Handle;$root=[Windows.Automation.AutomationElement]::FromHandle($handle)
 $editor=([OrbyDropTransfer]::Nodes($root) | Where-Object {$_.Name -eq 'Ask ChatGPT'} | Select-Object -First 1).Element
 $file='C:/synthetic/gap_full_fill_2026.py'
 foreach($text in @('gap_full_fill_2026.py','gap_full_fill_2026...','gap_full...2026.py','Remove gap_full_fill_2026.py')){$label.Text=$text;$window.UpdateLayout();$s=Get-OrbyDropAttachmentState $root $editor @($file);Check ($s.Ready -and $s.Count -eq 1) ('Attachment not recognized: '+$text)}
 $progress.Visibility='Visible';$window.UpdateLayout();$s=Get-OrbyDropAttachmentState $root $editor @($file);Check ($s.Busy -and -not $s.Ready) 'Active upload was marked ready'
 $progress.Visibility='Collapsed';$label.Text='';$history.Text='gap_full_fill_2026.py';$window.UpdateLayout();$s=Get-OrbyDropAttachmentState $root $editor @($file);Check ($s.Count -eq 0 -and -not $s.Ready) 'History was mistaken for a new attachment'
 $label.Text='same_pref...';$window.UpdateLayout();$s=Get-OrbyDropAttachmentState $root $editor @('C:/synthetic/same_prefix_a.py','C:/synthetic/same_prefix_b.py');Check ($s.Count -eq 0 -and -not $s.Ready) 'Ambiguous shortened names were accepted'
 $label.Text='Résumé 水.py';$window.UpdateLayout();$s=Get-OrbyDropAttachmentState $root $editor @('C:/synthetic/Résumé 水.py');Check $s.Ready 'Unicode filename not recognized'
 $label.Text='Upload failed';$window.UpdateLayout();$s=Get-OrbyDropAttachmentState $root $editor @($file);Check ([bool]$s.Error -and -not $s.Ready) 'Upload failure ignored'
 $label.Text='gap_full_fill_2026.py';$history.Text='Upload failed';$window.UpdateLayout();$s=Get-OrbyDropAttachmentState $root $editor @($file);Check ($s.Ready -and -not $s.Busy -and -not $s.Error) 'Unrelated history/progress delayed the upload'
 $label.Text='1792679569487_gap_full_fill_2026.py';$window.UpdateLayout();$adapter=@{Id='claude'};$s=Get-OrbyDropAttachmentState $root $editor @($file);Check $s.Ready 'Claude timestamp prefix not recognized'
 $adapter=@{Id='chatgpt'};$s=Get-OrbyDropAttachmentState $root $editor @($file);Check (-not $s.Ready) 'Claude rename policy leaked to another provider'
 Check (-not (Test-OrbyDropPreviewLabel '1792679569487_wrong.py' $file 'claude')) 'Unrelated timestamped file accepted'
 $label.Text='gap_full_f...2026';$window.UpdateLayout();$adapter=@{Id='gemini'}
 $realScope=Get-OrbyDropComposerScope $editor
 $snapshotTestCard=([OrbyDropTransfer]::Nodes($realScope) | Where-Object {$_.Name -eq $label.Text} | Select-Object -First 1).Element
 function Get-OrbyDropNodes($target){
  if([Windows.Automation.Automation]::Compare($target,$snapshotTestCard)){return @([pscustomobject]@{Name='gap_full_f...2026';Type=[Windows.Automation.ControlType]::Text;Offscreen=$true})}
  $all=@([OrbyDropTransfer]::Nodes($target))
  foreach($node in $all){if([Windows.Automation.Automation]::Compare($node.Element,$snapshotTestCard)){$node.Name='';$node.Class='file-preview-container'};$node}
 }
 $s=Get-OrbyDropAttachmentState $root $editor @($file);Check $s.Ready 'Hidden filename under visible Gemini card not recognized'
 'PASS: '+$checks+' attachment-state checks: shortened Python names, Unicode, upload progress, ambiguity, and history isolation.'
}finally{$window.Close()}
