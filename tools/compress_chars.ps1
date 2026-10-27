Add-Type -AssemblyName System.Drawing
$dir = "$PSScriptRoot\..\app\src\main\assets\characters"
$files = Get-ChildItem $dir -Recurse -Filter *.jpg
$before = ($files | Measure-Object Length -Sum).Sum/1MB
foreach ($f in $files) {
    $src = [System.Drawing.Image]::FromFile($f.FullName)
    try {
        $ratio = [Math]::Min(1.0, 160.0 / $src.Width)
        $w = [Math]::Max(1, [int]($src.Width * $ratio))
        $h = [Math]::Max(1, [int]($src.Height * $ratio))
        $bmp = New-Object System.Drawing.Bitmap($w, $h)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.DrawImage($src, 0, 0, $w, $h)
        $g.Dispose()
        $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
        $ep = New-Object System.Drawing.Imaging.EncoderParameters(1)
        $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]78)
        $tmp = "$($f.FullName).tmp"
        $bmp.Save($tmp, $codec, $ep)
        $bmp.Dispose()
        $src.Dispose()
        Move-Item $tmp $f.FullName -Force
    } finally {
        if ($src) { $src.Dispose() }
    }
}
$after = (Get-ChildItem $dir -Recurse -Filter *.jpg | Measure-Object Length -Sum).Sum/1MB
"chars: {0:N1} MB -> {1:N1} MB ({2} arquivos)" -f $before, $after, $files.Count