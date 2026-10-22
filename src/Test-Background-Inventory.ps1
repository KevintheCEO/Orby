$ErrorActionPreference='Stop'
Add-Type -Path (Join-Path $PSScriptRoot 'File-Inventory.cs')
Add-Type -Path (Join-Path $PSScriptRoot 'Log-Discovery.cs')
$fixture=Join-Path ([IO.Path]::GetTempPath()) ('orby-inventory-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($fixture)
try {
 $first=Join-Path $fixture 'first.txt';$second=Join-Path $fixture 'second.log'
 [IO.File]::WriteAllText($first,'abc');[IO.File]::WriteAllText($second,'log')
 $task=[OrbyFileInventory]::Poll($fixture,1);$task.Wait();$view=$task.Result
 if(-not $view.Valid -or $view.Files.Length -ne 1 -or $view.Paths.Count -ne 2){throw 'Truncating rows must retain all existence keys'}
 [IO.File]::Delete($first)
 $task=[OrbyFileInventory]::Poll($fixture,10);$task.Wait()
 if($task.Result.Paths.Contains($first) -or $task.Result.Files[0].Length -ne 3){throw 'Background file inventory did not refresh'}
 $task=[OrbyLogDiscovery]::Poll([string[]]@($fixture),[datetime]::UtcNow.AddMinutes(-1));$task.Wait()
 if($task.Result.Length -ne 1 -or $task.Result[0].Path -ne $second){throw 'Background log discovery missed current log'}
 'Background inventory tests passed: bounds, deletion, cached metadata, current logs.'
}finally{[IO.Directory]::Delete($fixture,$true)}
