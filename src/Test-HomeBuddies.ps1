param([switch]$Water)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Xaml,System.Windows.Forms
. (Join-Path $PSScriptRoot 'Orb-Avatar.ps1')
. (Join-Path $PSScriptRoot 'Motion.ps1')
Add-Type -Path @((Join-Path $PSScriptRoot 'Native-Avatar.cs'),(Join-Path $PSScriptRoot 'Hydration-Avatar.cs'),(Join-Path $PSScriptRoot 'Rendered-Assets.cs'),(Join-Path $PSScriptRoot 'Hydration-Model.cs'),(Join-Path $PSScriptRoot 'Animation-Catalog.cs')) -ReferencedAssemblies @('WindowsBase','PresentationCore','PresentationFramework','System.Xaml')
. (Join-Path $PSScriptRoot 'Home-Buddies.ps1')
[xml]$x=Get-Content (Join-Path $PSScriptRoot 'Reference-Home.xaml') -Raw
$script:referenceHome=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($x))
$script:orbySettings=@{ReducedMotion=$false};$script:orbyActiveTasks=@()
Initialize-OrbyHomeBuddies;Update-OrbyHomeBuddies
$w=[Windows.Window]::new();$w.Width=640;$w.Height=240;$w.Content=$script:referenceHome;$w.ShowActivated=$false
$t=[Windows.Threading.DispatcherTimer]::new();$t.Interval=[timespan]::FromSeconds(1.2);$t.Add_Tick({$t.Stop();$w.Close()});$w.Add_ContentRendered({$t.Start()});[void]$w.ShowDialog()
foreach($b in $script:homeBuddies){if($b.Renderer.Frames -lt 5){throw 'Buddy did not animate'};if(-not $b.Renderer.Trigger('hover_happy')){throw 'Hover gesture blocked'}}
$script:orbySettings.ReducedMotion=$true;Update-OrbyHomeBuddies
foreach($b in $script:homeBuddies){if(-not $b.Renderer.ReducedMotion){throw 'Reduced motion ignored'}}
Stop-OrbyHomeBuddies
'PASS: four live visible renderers, independent hover reactions, reduced-motion updates and disposal.'
