function Test-OrbyNewChatLabel {
 param([string]$Name,[string]$Help,[string]$Id)
 $label=($Name+' '+$Help).Trim()
 return ($label -match '(?i)^new chat(?:\s|$)' -or $Id -match '(?i)^(new[-_]?chat|new[-_]?chat[-_]?button)$')
}
function Find-OrbyNewChat {
 param($Root)
 foreach($tree in (Get-OrbyChatRoots $Root)){
  foreach($el in $tree.FindAll([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.Condition]::TrueCondition)){
   try{
    $c=$el.Current
    if($c.IsOffscreen -or -not $c.IsEnabled -or -not (Test-OrbyNewChatLabel $c.Name $c.HelpText $c.AutomationId)){continue}
    $candidate=$el
    for($i=0;$i -lt 3 -and $candidate;$i++){
     $invoke=$null
     if($candidate.TryGetCurrentPattern([Windows.Automation.InvokePattern]::Pattern,[ref]$invoke)){return $candidate}
     $candidate=[Windows.Automation.TreeWalker]::ControlViewWalker.GetParent($candidate)
    }
   }catch{}
  }
 }
 return $null
}
function Save-OrbyChatControls {
 param($Root,[string]$Path)
 $lines=New-Object Collections.Generic.List[string]
 $lines.Add('Orby ChatGPT control capture - '+[datetime]::UtcNow.ToString('o'))
 $lines.Add('Control labels only; message body text is excluded.')
 foreach($tree in (Get-OrbyChatRoots $Root)){
  try{
   $lines.Add('ROOT '+$tree.Current.ClassName+' '+$tree.Current.Name)
   foreach($el in $tree.FindAll([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.Condition]::TrueCondition)){
    $c=$el.Current
    if($c.ControlType.ProgrammaticName -notmatch 'Button|Hyperlink|Edit|MenuItem'){continue}
    $lines.Add(('type={0} name={1} id={2} help={3} enabled={4} offscreen={5}' -f $c.ControlType.ProgrammaticName,($c.Name -replace '[\r\n]',' '),$c.AutomationId,($c.HelpText -replace '[\r\n]',' '),$c.IsEnabled,$c.IsOffscreen))
    if($c.ControlType -eq [Windows.Automation.ControlType]::Button -or $c.ControlType -eq [Windows.Automation.ControlType]::MenuItem){
     $supported=New-Object Collections.Generic.List[string]
     foreach($type in @([Windows.Automation.InvokePattern],[Windows.Automation.ExpandCollapsePattern])){$pattern=$null;if($el.TryGetCurrentPattern($type::Pattern,[ref]$pattern)){$supported.Add($type.Name)}}
     $lines.Add('ACTION patterns='+($supported -join ','))
    }
    if($c.ControlType -eq [Windows.Automation.ControlType]::Edit){
     try{
      $vp=$el.GetCurrentPattern([Windows.Automation.ValuePattern]::Pattern)
      $tp=$null;$ht=$el.TryGetCurrentPattern([Windows.Automation.TextPattern]::Pattern,[ref]$tp)
      $textLength=-1;if($ht){$textLength=$tp.DocumentRange.GetText(-1).Trim().Length}
      $lines.Add(('EDIT metadata valueLength={0} valueEqualsLabel={1} textPattern={2} textLength={3}' -f $vp.Current.Value.Length,($vp.Current.Value -eq $c.Name),$ht,$textLength))
     }catch{}
    }
   }
  }catch{$lines.Add('Capture error: '+$_.Exception.Message)}
 }
 [IO.File]::WriteAllLines($Path,$lines.ToArray(),[Text.Encoding]::UTF8)
}

function Get-OrbyComposerRank {
 param([string]$Name,[string]$Id,[string]$Class)
 if($Id -eq 'prompt-textarea'){return 100}
 if($Name -match '(?i)search|address|url|filter|rename|title'){return 0}
 if($Name -match '(?i)^(message chatgpt|ask chatgpt|message|ask anything|send a message|prompt|work with chatgpt)(\s|$)'){return 80}
 if($Class -match '(?i)ProseMirror|prompt-textarea'){return 70}
 return 0
}

function Resolve-OrbyComposerText {
 param([string]$Name,[string]$Value,[string]$Text,[bool]$HasText,[bool]$AllowPlaceholder=$true)
 $placeholder=$Name -match '(?i)^(Ask ChatGPT|Ask anything|Message ChatGPT|Send a message)$'
 if($HasText -and $Text.Trim().Length -gt 0 -and -not ($placeholder -and $Text.Trim() -eq $Name.Trim())){return $Text.TrimEnd("`r","`n")}
 if($AllowPlaceholder -and $placeholder -and $Value.Trim() -eq $Name.Trim()){return ''}
 return $Value
}
function Get-OrbyComposerText {
 param($Element,[bool]$AllowPlaceholder=$true)
 $valuePattern=$Element.GetCurrentPattern([Windows.Automation.ValuePattern]::Pattern)
 $textPattern=$null;$hasText=$Element.TryGetCurrentPattern([Windows.Automation.TextPattern]::Pattern,[ref]$textPattern)
 $text='';if($hasText){$text=$textPattern.DocumentRange.GetText(-1)}
 return Resolve-OrbyComposerText $Element.Current.Name $valuePattern.Current.Value $text $hasText $AllowPlaceholder
}
