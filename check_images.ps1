Add-Type -AssemblyName System.Drawing
$files = @('assets/images/detox_symbolo_oscuro.png', 'assets/images/detox_symbolo_claro.png', 'assets/images/detox_logo.png')
foreach ($f in $files) {
    if (Test-Path $f) {
        $i = [System.Drawing.Image]::FromFile($f)
        Write-Host ("{0}: {1}x{2}, PixelFormat: {3}" -f $f, $i.Width, $i.Height, $i.PixelFormat)
        $i.Dispose()
    } else {
        Write-Host ("{0}: NOT FOUND" -f $f)
    }
}