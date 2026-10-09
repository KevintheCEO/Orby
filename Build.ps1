$ErrorActionPreference='Stop'
$source=Join-Path $PSScriptRoot 'src'
$out=Join-Path $PSScriptRoot 'dist-public'
$app=Join-Path $out 'Orby'
New-Item -ItemType Directory -Force -Path $app | Out-Null
Get-ChildItem $source -File | Where-Object {$_.Extension -in @('.ps1','.cs','.xaml','.cmd','.ico','.wav') -and $_.Name -notmatch '^Test-|^Build|^OrbySetup|^OrbyLauncher|^Enable-Orby-Startup'} | ForEach-Object {Copy-Item -LiteralPath $_.FullName -Destination $app}
foreach($folder in @('Rendered-assets','third-party','docs')){
 $folderRoot=if($folder -eq 'Rendered-assets'){$source}else{$PSScriptRoot}
 $dest=Join-Path $app $folder;New-Item -ItemType Directory -Force -Path $dest | Out-Null
 Get-ChildItem (Join-Path $folderRoot $folder) | ForEach-Object {Copy-Item -LiteralPath $_.FullName -Destination $dest -Recurse -Force}
}
foreach($name in @('README.md','LICENSE','SECURITY.md','VALIDATION.md')){if(Test-Path (Join-Path $PSScriptRoot $name)){Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination $app}}
$csc=Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
& $csc /nologo /target:winexe ('/win32icon:'+(Join-Path $source 'Orby.ico')) ('/out:'+(Join-Path $app 'Orby.exe')) /reference:System.Windows.Forms.dll (Join-Path $source 'OrbyLauncher.cs')
if($LASTEXITCODE -ne 0){throw 'Launcher build failed'}
Compress-Archive -Path (Join-Path $app '*') -DestinationPath (Join-Path $out 'Orby-Windows.zip') -Force
& $csc /nologo /target:winexe ('/win32icon:'+(Join-Path $source 'Orby.ico')) ('/out:'+(Join-Path $out 'Orby-Setup.exe')) ('/resource:'+(Join-Path $out 'Orby-Windows.zip')+',Orby.Payload') /reference:System.Windows.Forms.dll /reference:System.Drawing.dll /reference:System.IO.Compression.dll /reference:System.IO.Compression.FileSystem.dll (Join-Path $source 'OrbySetup.cs')
if($LASTEXITCODE -ne 0){throw 'Installer build failed'}
Write-Output 'Built dist/Orby-Setup.exe and dist/Orby-Windows.zip'
