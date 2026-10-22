$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
. (Join-Path $PSScriptRoot 'Approval-Bridge.ps1')
$xml=[xml](Get-Content (Join-Path $PSScriptRoot 'Event-Card.xaml') -Raw)
$view=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($xml));$view.Visibility='Visible';$view.Height=276
$script:eventControls=@{};foreach($m in [regex]::Matches($xml.OuterXml,'x:Name="([^"]+)"')){$n=$m.Groups[1].Value;$script:eventControls[$n]=$view.FindName($n)}
$script:orbyEventMode='attention';$script:approvalChoice=-1
$script:approvalRequest=[OrbyApprovalRequest]@{Id='fixture-question';Kind='question';Available=$true;CanAnswer=$true;Title='Please quit Orby so the update can finish.';Detail='Choose an answer, then send it.';Choices=[string[]]@('Orby is closed',"I'll install later")}
$window=[Windows.Window]::new();$window.Width=620;$window.Height=340;$window.Content=$view;$window.Background=[Windows.Media.Brushes]::Black;$window.ShowActivated=$false
$window.Show();Update-OrbyApprovalView;$window.UpdateLayout()
function Check($ok,$text){if(-not $ok){throw $text};$script:checks++}
$c=$script:eventControls
Check ($c.EventChoices.Children.Count -eq 2 -and $c.EventChoices.Visibility -eq 'Visible') 'Question choices missing'
Check ($c.EventDeny.Visibility -eq 'Collapsed' -and $c.EventApprove.Content -eq 'Send answer') 'Question incorrectly presented as Allow/Deny'
Check (-not $c.EventApprove.IsEnabled) 'Send enabled before the user chose an answer'
$c.EventChoices.Children[1].RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Check ($script:approvalChoice -eq 1 -and $c.EventApprove.IsEnabled) 'Selecting a response did not enable Send'
Check (-not $script:approvalReplyTask) 'Selecting an Orby option submitted an answer automatically'
$old=$c.EventChoices.Children[0];$script:approvalChoice=-1
$script:approvalRequest=[OrbyApprovalRequest]@{Id='new-question';Kind='question';Available=$true;CanAnswer=$true;Title='Different question';Detail='Review this new request';Choices=[string[]]@('New answer')}
Update-OrbyApprovalView;$old.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Check ($script:approvalChoice -eq -1 -and -not $c.EventApprove.IsEnabled) 'Stale Orby button selected an answer to the new question'
$script:approvalRequest=[OrbyApprovalRequest]@{Id='permission';Kind='permission';Available=$true;CanAnswer=$true;Title='Allow ChatGPT to use the internet?'}
Update-OrbyApprovalView
Check ($c.EventChoices.Visibility -eq 'Collapsed' -and $c.EventDeny.Visibility -eq 'Visible' -and $c.EventApprove.Content -eq 'Allow once') 'Permission buttons no longer preserved'
$window.Close();"PASS: $script:checks Orby question panel interaction checks"
