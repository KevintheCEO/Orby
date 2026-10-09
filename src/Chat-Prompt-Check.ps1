function ConvertTo-OrbyComparablePrompt {
 param([string]$Text)
 return $Text.Replace("`r`n","`n").Replace("`r","`n").TrimEnd("`n")
}
function Test-OrbyPromptSnapshot {
 param([string]$Prompt,[string]$Value,[string]$Text,[bool]$HasText)
 $expected=ConvertTo-OrbyComparablePrompt $Prompt
 if(-not $expected.Length){return $false}
 # Providers may update Value and Text at different times after SetValue.
 return ([string]::Equals((ConvertTo-OrbyComparablePrompt $Value),$expected,[StringComparison]::Ordinal) -or
  ($HasText -and [string]::Equals((ConvertTo-OrbyComparablePrompt $Text),$expected,[StringComparison]::Ordinal)))
}
function Wait-OrbyPromptInserted {
 param($Root,[string]$Prompt)
 $deadline=[datetime]::UtcNow.AddSeconds(5)
 $valueLength=-1;$textLength=-1
 do{
  try{
   $element=Find-ChatComposer $Root
   $value=$element.GetCurrentPattern([Windows.Automation.ValuePattern]::Pattern).Current.Value
   $pattern=$null;$hasText=$element.TryGetCurrentPattern([Windows.Automation.TextPattern]::Pattern,[ref]$pattern)
   $text='';if($hasText){$text=$pattern.DocumentRange.GetText(-1)}
   $valueLength=$value.Length;$textLength=$text.Length
   if(Test-OrbyPromptSnapshot $Prompt $value $text $hasText){return $element}
  }catch{}
  Start-Sleep -Milliseconds 150
 }while([datetime]::UtcNow -lt $deadline)
 throw ('Prompt insertion was not confirmed (expected length '+$Prompt.Length+', Value length '+$valueLength+', Text length '+$textLength+'). Nothing was sent')
}
