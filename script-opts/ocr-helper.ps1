param(
    [string]$Image = "",
    [string]$Lang = "",
    [string]$Mode = "once"
)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.Runtime.WindowsRuntime | Out-Null
Add-Type -AssemblyName System.Drawing | Out-Null

$null = [Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType = WindowsRuntime]
$null = [Windows.Graphics.Imaging.SoftwareBitmap, Windows.Graphics.Imaging, ContentType = WindowsRuntime]
$null = [Windows.Storage.Streams.InMemoryRandomAccessStream, Windows.Storage.Streams, ContentType = WindowsRuntime]
$null = [Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics.Imaging, ContentType = WindowsRuntime]

$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
    $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]

function Await($WinRtTask, $ResultType) {
    $asTask = $asTaskGeneric.MakeGenericMethod($ResultType)
    $netTask = $asTask.Invoke($null, @($WinRtTask))
    $netTask.Wait(-1) | Out-Null
    $netTask.Result
}

function PickEngine($Lang) {
    if ($Lang) {
        try {
            $langObj = New-Object Windows.Globalization.Language($Lang)
            $e = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage($langObj)
            if ($e) { return $e }
        } catch {}
    }
    return [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
}

function OcrFile($img, $lang) {
    $engine = PickEngine $lang
    if (-not $engine) { Write-Output "OCR_ERROR:no engine"; return }

    # decode, then invert colors (Windows OCR wants dark text on light)
    $bmp = [System.Drawing.Bitmap]::FromFile($img)
    $w = $bmp.Width; $h = $bmp.Height
    $cm = New-Object System.Drawing.Imaging.ColorMatrix
    $cm.Matrix00 = -1; $cm.Matrix11 = -1; $cm.Matrix22 = -1
    $cm.Matrix33 = 1; $cm.Matrix40 = 1; $cm.Matrix41 = 1; $cm.Matrix42 = 1
    $ia = New-Object System.Drawing.Imaging.ImageAttributes
    $ia.SetColorMatrix($cm)
    $inv = New-Object System.Drawing.Bitmap($w, $h)
    $g = [System.Drawing.Graphics]::FromImage($inv)
    $g.DrawImage($bmp, (New-Object System.Drawing.Rectangle(0, 0, $w, $h)), 0, 0, $w, $h, [System.Drawing.GraphicsUnit]::Pixel, $ia)
    $g.Dispose()
    $bmp.Dispose()

    $ms = New-Object System.IO.MemoryStream
    $inv.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $inv.Dispose()
    $pngBytes = $ms.ToArray(); $ms.Dispose()

    $ras = New-Object Windows.Storage.Streams.InMemoryRandomAccessStream
    $writer = New-Object Windows.Storage.Streams.DataWriter($ras.GetOutputStreamAt(0))
    $writer.WriteBytes($pngBytes)
    $storeOp = $writer.StoreAsync()
    $null = Await $storeOp ([System.UInt32])
    $writer.DetachStream()
    $decoder = Await ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($ras)) ([Windows.Graphics.Imaging.BitmapDecoder])
    $sbmp = Await ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
    $result = Await ($engine.RecognizeAsync($sbmp)) ([Windows.Media.Ocr.OcrResult])
    Write-Output ("OCR_TEXT:" + $result.Text)
}

if ($Mode -eq "loop") {
    [Console]::Out.Write("HELLO`n"); [Console]::Out.Flush()
    while ($true) {
        $line = [Console]::In.ReadLine()
        if (-not $line) { Start-Sleep -Milliseconds 30; continue }
        if ($line -eq "EXIT") { break }
        $parts = $line -split '\|', 2
        OcrFile $parts[0] $parts[1]
        [Console]::Out.Flush()
    }
} else {
    OcrFile $Image $Lang
}
