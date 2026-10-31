# Meigenly v0.9.3: foreground do adaptive icon a partir do JPEG novo (navy disc full-bleed).
# Estrategia: recorte eliptico em 0.82 do canvas (mask circle ~0.667) + escala quadrada do JPG.
# Monochrome: glyph por threshold de luminancia (alpha=(lum-120)/60*255 clamp) em 432px, depois downscale.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$srcPath = "C:\Users\mathe\Downloads\Gemini_Generated_Image_bypixhbypixhbypi.jpg"
$resDir  = "$PSScriptRoot\..\app\src\main\res"
$src = [System.Drawing.Bitmap]::FromFile($srcPath)

function Save-Png($bmp, [string]$path) {
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
}

# ---------- Foreground (navy disc + glyph, from JPEG) ----------
$S = 432
$disc = [int]([Math]::Round(0.82 * $S))
$canvas = New-Object System.Drawing.Bitmap $S, $S
$g = [System.Drawing.Graphics]::FromImage($canvas)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$offset = ($S - $disc) / 2
$clip = New-Object System.Drawing.Drawing2D.GraphicsPath
$clip.AddEllipse($offset, $offset, $disc, $disc)
$g.SetClip($clip)
$g.DrawImage($src, (New-Object System.Drawing.Rectangle $offset, $offset, $disc, $disc), 0, 0, $src.Width, $src.Height, [System.Drawing.GraphicsUnit]::Pixel)
$g.ResetClip()
$g.Dispose()
Save-Png $canvas "$resDir\drawable-xxxhdpi\ic_launcher_foreground.png"

foreach ($m in @(
    @{ dpi='xxhdpi'; size=324 },
    @{ dpi='xhdpi';   size=216 },
    @{ dpi='hdpi';    size=162 },
    @{ dpi='mdpi';    size=108 }
)) {
    $small = New-Object System.Drawing.Bitmap $m.size, $m.size
    $gs = [System.Drawing.Graphics]::FromImage($small)
    $gs.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $gs.DrawImage($canvas, 0, 0, $m.size, $m.size)
    $gs.Dispose()
    Save-Png $small "$resDir\drawable-$($m.dpi)\ic_launcher_foreground.png"
    $small.Dispose()
}
$canvas.Dispose()

# ---------- Monochrome (glyph white on transparent) ----------
$M = 432
$discM = [int]([Math]::Round(0.82 * $M))
$drawn = New-Object System.Drawing.Bitmap $discM, $discM
$gd = [System.Drawing.Graphics]::FromImage($drawn)
$gd.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$gd.DrawImage($src, (New-Object System.Drawing.Rectangle 0, 0, $discM, $discM), 0, 0, $src.Width, $src.Height, [System.Drawing.GraphicsUnit]::Pixel)
$gd.Dispose()
$offset = ($S - $discM) / 2
$mono = New-Object System.Drawing.Bitmap $S, $S
for ($y = 0; $y -lt $S; $y++) {
    for ($x = 0; $x -lt $S; $x++) {
        $dx = $x - $offset
        $dy = $y - $offset
        if ($dx -lt 0 -or $dy -lt 0 -or $dx -ge $discM -or $dy -ge $discM) {
            $mono.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(0, 255, 255, 255))
            continue
        }
        $p = $drawn.GetPixel($dx, $dy)
        $lum = ($p.R * 299 + $p.G * 587 + $p.B * 114) / 1000
        $a = [int]((($lum - 120.0) / 60.0) * 255.0)
        if ($a -lt 0) { $a = 0 }
        if ($a -gt 255) { $a = 255 }
        $mono.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($a, 255, 255, 255))
    }
}
Save-Png $mono "$resDir\drawable-xxxhdpi\ic_launcher_monochrome.png"
foreach ($m in @(
    @{ dpi='xxhdpi'; size=324 },
    @{ dpi='xhdpi';   size=216 },
    @{ dpi='hdpi';    size=162 },
    @{ dpi='mdpi';    size=108 }
)) {
    $small = New-Object System.Drawing.Bitmap $m.size, $m.size
    $gs = [System.Drawing.Graphics]::FromImage($small)
    $gs.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $gs.DrawImage($mono, 0, 0, $m.size, $m.size)
    $gs.Dispose()
    Save-Png $small "$resDir\drawable-$($m.dpi)\ic_launcher_monochrome.png"
    $small.Dispose()
}
$mono.Dispose()
$drawn.Dispose()
$src.Dispose()
"icons OK"