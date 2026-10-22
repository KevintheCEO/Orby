$ErrorActionPreference='Stop'
if(Test-Path -LiteralPath (Join-Path $PSScriptRoot 'SECURITY-REVIEW-PENDING.txt')){throw 'This package is on hold for review.'}
$compiler=Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
$engine=Join-Path $env:WINDIR 'Microsoft.Net/assembly/GAC_MSIL/System.Management.Automation/v4.0_3.0.0.0__31bf3856ad364e35/System.Management.Automation.dll'
& $compiler /nologo /target:winexe /platform:x64 /reference:System.Windows.Forms.dll ('/reference:'+$engine) ('/win32icon:'+(Join-Path $PSScriptRoot 'Orby.ico')) ('/out:'+(Join-Path $PSScriptRoot 'Orby.exe')) (Join-Path $PSScriptRoot 'OrbyLauncher.cs')
if($LASTEXITCODE -ne 0){throw 'Native host compilation failed'}
& $compiler /nologo /target:winexe /reference:System.Web.Extensions.dll /reference:System.Core.dll ('/out:'+(Join-Path $PSScriptRoot 'Orby-Claude-Hook.exe')) (Join-Path $PSScriptRoot 'Claude-Code.cs')
if($LASTEXITCODE -ne 0){throw 'Claude hook compilation failed'}
'Built Orby host and Claude observer from adjacent source. Scan the complete folder before running.'

& $compiler /nologo /target:library /platform:x64 /reference:System.Core.dll /reference:System.Windows.Forms.dll ('/reference:'+([System.Reflection.Assembly]::LoadWithPartialName('UIAutomationClient').Location)) ('/reference:'+([System.Reflection.Assembly]::LoadWithPartialName('UIAutomationTypes').Location)) ('/reference:'+([System.Reflection.Assembly]::LoadWithPartialName('WindowsBase').Location)) ('/out:'+(Join-Path $PSScriptRoot 'Orby-Drop.dll')) (Join-Path $PSScriptRoot 'Drop-Transfer.cs')
if($LASTEXITCODE -ne 0){throw 'File handoff helper compilation failed'}
