function Get-OrbyControlAction {
 param($Element)
 $pattern=$null
 if($Element.TryGetCurrentPattern([Windows.Automation.InvokePattern]::Pattern,[ref]$pattern)){return [pscustomobject]@{Kind='Invoke';Pattern=$pattern}}
 if($Element.TryGetCurrentPattern([Windows.Automation.ExpandCollapsePattern]::Pattern,[ref]$pattern)){return [pscustomobject]@{Kind='Expand';Pattern=$pattern}}
 return $null
}
function Invoke-OrbyControl {
 param($Element)
 if(-not $Element){throw 'Required ChatGPT control is not accessible'}
 $action=Get-OrbyControlAction $Element
 if(-not $action){throw 'ChatGPT control exposes no supported action'}
 switch($action.Kind){
  Invoke {$action.Pattern.Invoke()}
  Expand {if($action.Pattern.Current.ExpandCollapseState -ne [Windows.Automation.ExpandCollapseState]::Expanded){$action.Pattern.Expand()}}
 }
}
