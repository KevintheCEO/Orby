param([Parameter(Mandatory=$true)][string]$DesktopRoot)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationCore,WindowsBase
$desktop=(Resolve-Path -LiteralPath $DesktopRoot).Path
$output=Join-Path (Split-Path $PSScriptRoot -Parent) 'web/mascot'
[void](New-Item -ItemType Directory -Path $output -Force)
Add-Type -Path (Join-Path $desktop 'Rendered-Assets.cs') -ReferencedAssemblies @('WindowsBase','PresentationCore','System.Xaml')
[OrbyRenderedAssets]::Configure($desktop)
# The white body is copied byte for byte. The colored bodies are encoded from
# the desktop renderer's own cached ImageBrush; no replacement artwork is drawn.
Copy-Item -LiteralPath (Join-Path $desktop 'Rendered-assets/body.png') -Destination (Join-Path $output 'body.png') -Force
$palette=[ordered]@{red='#E74766';purple='#A765ED';teal='#45BCB8';gold='#EDAE46'}
foreach($entry in $palette.GetEnumerator()){
 $brush=[OrbyRenderedAssets]::Body([Windows.Media.ColorConverter]::ConvertFromString($entry.Value))
 $encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder
 $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($brush.ImageSource))
 $stream=[IO.File]::Create((Join-Path $output ('body-'+$entry.Key+'.png')))
 try{$encoder.Save($stream)}finally{$stream.Dispose()}
}
$receipt=[ordered]@{Artwork='Rendered-assets/body.png';WhiteBodyCopiedExactly=$true;BodySHA256=(Get-FileHash -LiteralPath (Join-Path $output 'body.png') -Algorithm SHA256).Hash;Palette=$palette;TintRenderer='Rendered-Assets.cs: OrbyRenderedAssets.Body';Eyes='Native-Avatar.cs: geometries[0] and geometries[1]';Motion='Animation-Catalog.cs: 81 public clips';PrivateWaterAssetsIncluded=$false}
$receipt|ConvertTo-Json -Depth 4|Set-Content -LiteralPath (Join-Path $output 'provenance.json') -Encoding UTF8
'Exported the original desktop body and four desktop-rendered palette variants.'
