param([switch]$Wizard,[switch]$TrustedClick)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName UIAutomationClient,UIAutomationTypes,System.Windows.Forms,PresentationFramework,PresentationCore,WindowsBase,System.Xaml
. (Join-Path $PSScriptRoot 'Chat-Window.ps1')
. (Join-Path $PSScriptRoot 'Chat-Actions.ps1')
. (Join-Path $PSScriptRoot 'Drop-Providers.ps1')
Add-Type -Path (Join-Path $PSScriptRoot 'Drop-UIA.cs') -ReferencedAssemblies UIAutomationClient,UIAutomationTypes,WindowsBase,System.Core
function Find-ChatButton($Root,[string]$Pattern){foreach($el in $Root.FindAll([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.Condition]::TrueCondition)){if(-not $el.Current.IsOffscreen -and $el.Current.IsEnabled -and $el.Current.Name -match $Pattern -and (Get-OrbyControlAction $el)){return $el}}}
$rootPath=Join-Path (Split-Path $PSScriptRoot -Parent) ('drop-picker-test-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($rootPath)
$exe=Join-Path $rootPath 'Fixture.exe';$receipt=Join-Path $rootPath 'receipt.txt'
$compiler=Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
& $compiler /nologo /target:winexe ('/reference:'+([Windows.Window].Assembly.Location)) ('/reference:'+([Windows.Media.Brushes].Assembly.Location)) ('/reference:'+([Windows.DependencyObject].Assembly.Location)) ('/reference:'+([System.Xaml.XamlReader].Assembly.Location)) ('/out:'+$exe) (Join-Path $PSScriptRoot 'Test-DropPicker.cs')
if($LASTEXITCODE -ne 0){throw 'Fixture compile failed'}
$first=Join-Path $rootPath 'first file.txt';$second=Join-Path $rootPath 'second.txt';[IO.File]::WriteAllText($first,'fixture one');[IO.File]::WriteAllText($second,'fixture two')
$app=Start-Process $exe -ArgumentList ('"'+$receipt+'" '+$(if($Wizard){'wizard'}else{'direct'})) -WindowStyle Normal -PassThru
try{
 $deadline=[datetime]::UtcNow.AddSeconds(10)
 do{Start-Sleep -Milliseconds 100;$app.Refresh()}while($app.MainWindowHandle -eq [IntPtr]::Zero -and [datetime]::UtcNow -lt $deadline)
 if($app.MainWindowHandle -eq [IntPtr]::Zero){throw 'Fixture did not open'}
 Start-Sleep -Milliseconds 700
 $script:chatHwnd=$app.MainWindowHandle;$root=[Windows.Automation.AutomationElement]::FromHandle($script:chatHwnd)
 # Only provider identity and browser launch are outside this native picker test.
 function Test-OrbyDropWindow($Root,$Adapter){return $Root.Current.ProcessId -eq $app.Id}
 function Get-OrbyDropForegroundWindow {
  $fixtureRoot=[Windows.Automation.AutomationElement]::FromHandle($script:chatHwnd)
  foreach($top in $fixtureRoot.FindAll([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.Condition]::TrueCondition)){
   if($top.Current.ProcessId -eq $app.Id -and $top.Current.ClassName -eq '#32770' -and $top.Current.ControlType -eq [Windows.Automation.ControlType]::Window){return [IntPtr]$top.Current.NativeWindowHandle}
  }
  return $script:chatHwnd
 }
 [void][OrbyChatWindow]::Activate($script:chatHwnd);Start-Sleep -Milliseconds 300
 $Operation=@{Cancelled=$false}
 Add-OrbyDropFilesWithPicker $root @{Id=$(if($TrustedClick){'chatgpt'}else{'fixture'})} @($first,$second)
 $deadline=[datetime]::UtcNow.AddSeconds(8)
 while(-not [IO.File]::Exists($receipt) -and [datetime]::UtcNow -lt $deadline){Start-Sleep -Milliseconds 100}
 if(-not [IO.File]::Exists($receipt)){throw 'Owned picker did not complete'}
 $actual=[IO.File]::ReadAllLines($receipt)
 if($actual.Count -ne 2 -or $actual[0] -ne $first -or $actual[1] -ne $second){throw 'Wrong filenames selected'}
 'PASS: actual owned Windows file picker selected both files, including spaces; no external service contacted.'
}finally{if(-not $app.HasExited){$app.Kill();$app.WaitForExit()}}
