# Meigenly: recompressao de capas grandes (GDI+ resize p/ width<=540, JPEG q80)
# Uso: powershell -File tools\compress_covers.ps1 [-MaxWidthKb 200]
param([int]$MaxKb = 200)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$dir = "$PSScriptRoot\..\app\src\main\assets\covers"
$files = Get-ChildItem $dir -Filter *.jpg | Where-Object { $_.Length/1KB -gt $MaxKb }

foreach ($f in $files) {
    $src = [System.Drawing.Image]::FromFile($f.FullName)
    try {
        $ratio = [Math]::Min(1.0, 540.0 / $src.Width)
        $w = [int]($src.Width * $ratio)
        $h = [int]($src.Height * $ratio)
        $bmp = New-Object System.Drawing.Bitmap($w, $h)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.DrawImage($src, 0, 0, $w, $h)
        $g.Dispose()
        $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
            Where-Object { $_.MimeType -eq 'image/jpeg' }
        $params = New-Object System.Drawing.Imaging.EncoderParameters(1)
        $params.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter(
            [System.Drawing.Imaging.Encoder]::Quality, [long]80)
        $tmp = "$($f.FullName).tmp"
        $bmp.Save($tmp, $codec, $params)
        $bmp.Dispose()
        $src.Dispose()
        Move-Item $tmp $f.FullName -Force
        Write-Host ("  {0}: {1:N0} KB -> {2:N0} KB ({3}x{4})" -f $f.Name, ($f.Length/1KB), ((Get-Item $f.FullName).Length/1KB), $w, $h)
    } finally {
        if ($src) { $src.Dispose() }
    }
}
