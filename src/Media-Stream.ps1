# WinRT async results can arrive as unprojected System.__ComObject in PS 5.1.
# Invoke the declared interfaces so the runtime queries the correct COM interface.
function Open-OrbyThumbnailStream {
 param($Stream)
 [void][Windows.Storage.Streams.IRandomAccessStream,Windows.Storage.Streams,ContentType=WindowsRuntime]
 $input=[Windows.Storage.Streams.IRandomAccessStream].GetMethod('GetInputStreamAt').Invoke($Stream,@([uint64]0))
 $method=[IO.WindowsRuntimeStreamExtensions].GetMethods() | Where-Object {$_.Name -eq 'AsStreamForRead' -and $_.GetParameters().Count -eq 1} | Select-Object -First 1
 return $method.Invoke($null,@($input))
}
