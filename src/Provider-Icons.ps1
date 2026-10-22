function Initialize-OrbyProviderIcons {
 if($script:providerIconResources){return}
 [xml]$x=Get-Content (Join-Path $script:providerDirectory 'Provider-Icons.xaml') -Raw
 $script:providerIconResources=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($x))
 $script:openAiLogo=$script:referenceControls.RefProviderIcon.Data
}
function Set-OrbyProviderIcon {
 param([string]$Id)
 if(-not $script:providerIconResources -or -not $script:referenceControls.RefProviderIcon){return}
 $c=$script:referenceControls;$path=$c.RefProviderIcon
 $path.Visibility='Visible';$c.RefProviderGlyph.Visibility='Collapsed'
 switch($Id){
  claude {$path.Data=$script:providerIconResources['ClaudeLogo'];$path.Fill=$script:providerIconResources['ClaudeBrush']}
  gemini {$path.Data=$script:providerIconResources['GeminiLogo'];$path.Fill=$script:providerIconResources['GeminiBrush']}
  default {
   $path.Data=$script:openAiLogo
   $binding=[Windows.Data.Binding]::new('Foreground');$binding.RelativeSource=[Windows.Data.RelativeSource]::new([Windows.Data.RelativeSourceMode]::FindAncestor,[Windows.Controls.Button],1)
   [void]$path.SetBinding([Windows.Shapes.Path]::FillProperty,$binding)
  }
 }
}
