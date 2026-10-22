$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,UIAutomationClient,UIAutomationTypes
Add-Type -Path @((Join-Path $PSScriptRoot 'Approval-Worker.cs'),(Join-Path $PSScriptRoot 'Test-Approval-Harness.cs')) -ReferencedAssemblies @('UIAutomationClient','UIAutomationTypes','WindowsBase','PresentationCore','PresentationFramework','System.Xaml')
[OrbyApprovalHarness]::Run()

