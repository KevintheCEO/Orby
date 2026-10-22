# Expanded task inspection never focuses an app or changes a running task.
function Get-OrbyCardTaskState([string]$State){
 switch($State){working {'Working'} attention {'Needs your input'} default {'Status unavailable'}}
}
function Update-OrbySelectedTaskText($Card){
 $tasks=@($Card.Tasks);$c=$Card.Controls
 if(-not $tasks.Count){$Card.SelectedTaskId='';$c.TaskPosition.Text='';$c.TaskPosition.Visibility='Collapsed';return}
 $index=-1
 for($i=0;$i -lt $tasks.Count;$i++){if([string]$tasks[$i].Id -ceq [string]$Card.SelectedTaskId){$index=$i;break}}
 if($index -lt 0){$index=0;$Card.SelectedTaskId=[string]$tasks[0].Id}
 $task=$tasks[$index]
 $c.Title.Text=if($task.Title){[string]$task.Title}else{'Untitled task'}
 $c.Detail.Text=if($task.Action){[string]$task.Action}else{'No activity details available'}
 $c.Title.ToolTip=$c.Title.Text;$c.Detail.ToolTip=$c.Detail.Text
 $c.TaskPosition.Text='Task '+($index+1)+' of '+$tasks.Count+' · '+(Get-OrbyCardTaskState $task.State)
 $c.TaskPosition.ToolTip='Click an active Orby to view its task, or click the task count to see every task.'
 $c.TaskPosition.Visibility='Visible'
}
function Select-OrbyCardTask([string]$Provider,[string]$TaskId){
 $card=$script:providerCards[$Provider]
 if(-not $card -or -not @($card.Tasks | Where-Object {[string]$_.Id -ceq $TaskId -and $_.State -in @('working','attention')}).Count){return}
 $card.SelectedTaskId=$TaskId;Update-OrbySelectedTaskText $card
 if($card.Controls.TaskListButton.ContextMenu.IsOpen){Update-OrbyTaskMenu $card -Force}
}
function Select-OrbyCardPrimaryTask([string]$Provider){
 $card=$script:providerCards[$Provider]
 if($card -and $card.Tasks.Count){Select-OrbyCardTask $Provider ([string]$card.Tasks[0].Id)}
}
function Update-OrbyTaskMenu($Card,[switch]$Force){
 $menu=$Card.Controls.TaskListButton.ContextMenu
 if(-not $menu -or (-not $Force -and -not $menu.IsOpen)){return}
 $signature=(@($Card.Tasks | ForEach-Object {[string]$_.Id+'|'+$_.Title+'|'+$_.Action+'|'+$_.State}) -join "`n")+'|'+$Card.SelectedTaskId
 if(-not $Force -and $Card.TaskMenuSignature -ceq $signature){return}
 $Card.TaskMenuSignature=$signature;$menu.Items.Clear();$index=0
 foreach($task in $Card.Tasks){
  $index++
  $item=[Windows.Controls.MenuItem]::new();$item.CommandParameter=@{Provider=$Card.Id;TaskId=[string]$task.Id};$item.Foreground=[Windows.Media.Brushes]::White;$item.IsCheckable=$true;$item.IsChecked=([string]$task.Id -ceq [string]$Card.SelectedTaskId);$item.StaysOpenOnClick=$false
  $item.Template=$menu.Resources['TaskItemTemplate']
  $body=[Windows.Controls.StackPanel]::new();$body.Width=306;$body.Margin='0,4,4,6'
  $state=[Windows.Controls.TextBlock]::new();$state.Text='Task '+$index+' · '+(Get-OrbyCardTaskState $task.State);$state.FontSize=11;$state.Foreground=[Windows.Media.BrushConverter]::new().ConvertFromString('#91C5FF')
  $title=[Windows.Controls.TextBlock]::new();$title.Text=if($task.Title){[string]$task.Title}else{'Untitled task'};$title.FontSize=13;$title.FontWeight='SemiBold';$title.TextWrapping='Wrap';$title.Margin='0,3,0,2'
  $detail=[Windows.Controls.TextBlock]::new();$detail.Text=if($task.Action){[string]$task.Action}else{'No activity details available'};$detail.FontSize=12;$detail.Foreground=[Windows.Media.BrushConverter]::new().ConvertFromString('#BEC5D2');$detail.TextWrapping='Wrap'
  [void]$body.Children.Add($state);[void]$body.Children.Add($title);[void]$body.Children.Add($detail);$item.Header=$body
  $item.SetValue([Windows.Automation.AutomationProperties]::NameProperty,($state.Text+': '+$title.Text+'. '+$detail.Text))
  $item.Add_Click({param($sender,$e)$request=$sender.CommandParameter;Select-OrbyCardTask $request.Provider $request.TaskId;$e.Handled=$true})
  [void]$menu.Items.Add($item)
 }
 if(-not $Card.Tasks.Count){$empty=[Windows.Controls.MenuItem]::new();$empty.Header='No active tasks';$empty.IsEnabled=$false;[void]$menu.Items.Add($empty)}
}
function Test-OrbyTaskMenuOpen {
 foreach($card in $script:providerCards.Values){if($card.Controls.TaskListButton -and $card.Controls.TaskListButton.ContextMenu.IsOpen){return $true}}
 return $false
}
function Close-OrbyTaskMenus {
 foreach($card in $script:providerCards.Values){if($card.Controls.TaskListButton){$card.Controls.TaskListButton.ContextMenu.IsOpen=$false}}
}
$window.Add_Closed({Close-OrbyTaskMenus})
