# A standard current-user Startup shortcut, created only after an explicit settings save.
function Set-OrbyStartup {
    param([bool]$Enabled,[string]$StartupDirectory=[Environment]::GetFolderPath('Startup'),[string]$AppDirectory=$PSScriptRoot)
    $link=Join-Path $StartupDirectory 'Orby.lnk'
    if(-not $Enabled){if(Test-Path -LiteralPath $link){Remove-Item -LiteralPath $link};return}
    if(Test-Path -LiteralPath (Join-Path $AppDirectory 'SECURITY-REVIEW-PENDING.txt')){throw 'Orby startup is on hold pending review of the Defender detection.'}
    $exe=Join-Path $AppDirectory 'Orby.exe'
    if(-not (Test-Path -LiteralPath $exe -PathType Leaf)){throw 'Keep Orby.exe beside the app files before enabling Windows startup.'}
    if(-not (Test-Path -LiteralPath $StartupDirectory -PathType Container)){throw 'Windows Startup folder is unavailable.'}
    $shell=New-Object -ComObject WScript.Shell
    try{
        $shortcut=$shell.CreateShortcut($link)
        $shortcut.TargetPath=$exe;$shortcut.WorkingDirectory=$AppDirectory
        $shortcut.Description='Orby desktop companion';$shortcut.IconLocation=(Join-Path $AppDirectory 'Orby.ico')+',0'
        $shortcut.Save()
    }finally{if($shortcut){[void][Runtime.InteropServices.Marshal]::ReleaseComObject($shortcut)};[void][Runtime.InteropServices.Marshal]::ReleaseComObject($shell)}
}
