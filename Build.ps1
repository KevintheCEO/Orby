param([string]$OutputDirectory=(Join-Path $PSScriptRoot 'dist'))
$ErrorActionPreference='Stop'
$source=Join-Path $PSScriptRoot 'src'
& (Join-Path $source 'Build-NativeHost.ps1')
if($LASTEXITCODE -ne 0){throw 'Native build failed'}
Add-Type -AssemblyName System.IO.Compression,System.IO.Compression.FileSystem
$outputRoot=[IO.Path]::GetFullPath($OutputDirectory)
[void][IO.Directory]::CreateDirectory($outputRoot)
$payload=Join-Path $outputRoot 'Orby-Windows.zip'
$manifest=Join-Path $outputRoot 'FILES.sha256'
$stream=[IO.File]::Open($payload,[IO.FileMode]::Create,[IO.FileAccess]::Write)
$archive=[IO.Compression.ZipArchive]::new($stream,[IO.Compression.ZipArchiveMode]::Create)
$hashes=[Collections.Generic.List[string]]::new()
try{
 foreach($file in Get-ChildItem -LiteralPath $source -Recurse -File | Sort-Object FullName){
  $relative=$file.FullName.Substring($source.Length+1).Replace('\','/')
  if($relative -match '^(Personal/|Home-Weather\.cs$|Home-assets/|Hydration-Model\.cs$|Rendered-assets/(bottle[^/]*|body-water|source-atlas)\.png$)'){throw ('Private/removed file in public source: '+$relative)}
  if($relative -match '^(Test-|Capture-|Preview-|Build-|Enable-Orby-Startup|OrbyLauncher\.cs|README|START-)'){continue}
  [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive,$file.FullName,$relative,[IO.Compression.CompressionLevel]::Optimal)
  $hashes.Add((Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()+'  '+$relative)
 }
}finally{$archive.Dispose();$stream.Dispose()}
[IO.File]::WriteAllLines($manifest,$hashes,[Text.UTF8Encoding]::new($false))
$compiler=Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
& $compiler /nologo /target:winexe /platform:x64 /reference:System.Windows.Forms.dll /reference:System.Drawing.dll /reference:System.Core.dll /reference:System.IO.Compression.dll /reference:System.IO.Compression.FileSystem.dll ('/win32icon:'+(Join-Path $source 'Orby.ico')) ('/resource:'+$payload+',Orby.Payload') ('/resource:'+$manifest+',Orby.Hashes') ('/out:'+(Join-Path $outputRoot 'Orby-Setup.exe')) (Join-Path $PSScriptRoot 'packaging/OrbySetup.cs')
if($LASTEXITCODE -ne 0){throw 'Setup compilation failed'}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'packaging/READ-ME-FIRST.txt') -Destination (Join-Path $outputRoot 'READ-ME-FIRST.txt') -Force
'Built public Orby 10.40 setup, portable ZIP and embedded file manifest.'
