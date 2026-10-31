# Meigenly v0.9.5: novo icone (fundo preto, anel azul, kanji 名 e balão de fala).
# Estrategia:
#   - reduz a arte original para 512px e remove o fundo preto (black removal),
#     preservando o anel azul, o kanji branco e o balão com bordas suaves;
#   - recorta o bounding box do anel e reescala para 60% do canvas adaptativo
#     (dentro da safe zone de 66/108), centralizado;
#   - fundo solido #161616 no adaptive icon;
#   - monochrome = silhueta (alpha) do mesmo conteudo em branco.
# Uso: powershell -File tools\make_icons.ps1
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$srcPath = 'C:\Users\mathe\Downloads\Gemini_Generated_Image_fwnlo3fwnlo3fwnl.jpg'
$resDir = "$PSScriptRoot\..\app\src\main\res"
$src = [System.Drawing.Bitmap]::FromFile($srcPath)

function Save-Png($bmp, [string]$path) {
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
}

function New-Transparent([int]$w, [int]$h) {
    return New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
}

# ---------- 1) downscale para 512 e remover o fundo preto ----------
$N = 512
$small = New-Transparent $N $N
$g = [System.Drawing.Graphics]::FromImage($small)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.DrawImage($src, 0, 0, $N, $N)
$g.Dispose()

$fg = New-Transparent $N $N
for ($y = 0; $y -lt $N; $y++) {
    for ($x = 0; $x -lt $N; $x++) {
        $c = $small.GetPixel($x, $y)
        $max = [Math]::Max($c.R, [Math]::Max($c.G, $c.B))
        if ($max -le 24) { continue }        # fundo preto -> transparente
        $a = [int]([Math]::Min(255, (($max - 24) * 255) / 231))
        if ($a -le 0) { continue }
        $r = [int]([Math]::Min(255, ($c.R * 255) / $max))
        $gg = [int]([Math]::Min(255, ($c.G * 255) / $max))
        $b = [int]([Math]::Min(255, ($c.B * 255) / $max))
        $fg.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($a, $r, $gg, $b))
    }
}

# ---------- 2) bounding box do anel (pixels azuis) + margem ----------
$minX = $N; $minY = $N; $maxX = 0; $maxY = 0
for ($y = 0; $y -lt $N; $y++) {
    for ($x = 0; $x -lt $N; $x++) {
        $c = $fg.GetPixel($x, $y)
        if ($c.A -gt 40 -and ($c.B - $c.R) -gt 30) {
            if ($x -lt $minX) { $minX = $x }
            if ($x -gt $maxX) { $maxX = $x }
            if ($y -lt $minY) { $minY = $y }
            if ($y -gt $maxY) { $maxY = $y }
        }
    }
}
$pad = 6
$minX = [Math]::Max(0, $minX - $pad); $minY = [Math]::Max(0, $minY - $pad)
$maxX = [Math]::Min($N - 1, $maxX + $pad); $maxY = [Math]::Min($N - 1, $maxY + $pad)
$cw = $maxX - $minX + 1
$ch = $maxY - $minY + 1
Write-Host "conteudo recortado: ${cw}x${ch} em ($minX,$minY)"
$content = New-Transparent $cw $ch
$gc = [System.Drawing.Graphics]::FromImage($content)
$gc.DrawImage($fg, (New-Object System.Drawing.Rectangle 0, 0, $cw, $ch), (New-Object System.Drawing.Rectangle $minX, $minY, $cw, $ch), [System.Drawing.GraphicsUnit]::Pixel)
$gc.Dispose()

# ---------- 3) foreground + monochrome por densidade ----------
$densities = @(
    @{ dpi = 'xxxhdpi'; size = 432 },
    @{ dpi = 'xxhdpi';  size = 324 },
    @{ dpi = 'xhdpi';   size = 216 },
    @{ dpi = 'hdpi';    size = 162 },
    @{ dpi = 'mdpi';    size = 108 }
)

foreach ($m in $densities) {
    $S = $m.size
    $inner = [int]([Math]::Round(0.60 * $S))

    $canvas = New-Transparent $S $S
    $g = [System.Drawing.Graphics]::FromImage($canvas)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $off = ($S - $inner) / 2
    $g.DrawImage($content, (New-Object System.Drawing.RectangleF $off, $off, $inner, $inner), (New-Object System.Drawing.RectangleF 0, 0, $cw, $ch), [System.Drawing.GraphicsUnit]::Pixel)
    $g.Dispose()
    Save-Png $canvas "$resDir\drawable-$($m.dpi)\ic_launcher_foreground.png"

    # monochrome: mesma silhueta, branco solido (o sistema aplica o tint)
    $mono = New-Transparent $S $S
    for ($y = 0; $y -lt $S; $y++) {
        for ($x = 0; $x -lt $S; $x++) {
            $a = $canvas.GetPixel($x, $y).A
            if ($a -gt 0) { $mono.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($a, 255, 255, 255)) }
        }
    }
    Save-Png $mono "$resDir\drawable-$($m.dpi)\ic_launcher_monochrome.png"

    if ($S -eq 432) { $previewFg = $canvas.Clone(); $previewMono = $mono.Clone() }
    $canvas.Dispose(); $mono.Dispose()
}

# ---------- 4) preview (fundo preto + mascara circular) ----------
$P = 512
$preview = New-Object System.Drawing.Bitmap $P, $P, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$gp = [System.Drawing.Graphics]::FromImage($preview)
$gp.Clear([System.Drawing.Color]::FromArgb(22, 22, 22))
$gp.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$gp.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$mask = New-Object System.Drawing.Drawing2D.GraphicsPath
$mask.AddEllipse(0, 0, $P, $P)
$gp.SetClip($mask)
$gp.DrawImage($previewFg, 0, 0, $P, $P)
$gp.ResetClip()
$gp.Dispose()
Save-Png $preview "$env:TEMP\opencode\icon-preview-circle.png"
$preview.Dispose()

# preview quadrado (launcher sem mascara)
$square = New-Object System.Drawing.Bitmap $P, $P, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$gs = [System.Drawing.Graphics]::FromImage($square)
$gs.Clear([System.Drawing.Color]::FromArgb(22, 22, 22))
$gs.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$gs.DrawImage($previewFg, 0, 0, $P, $P)
$gs.Dispose()
Save-Png $square "$env:TEMP\opencode\icon-preview-square.png"
$square.Dispose()

$previewFg.Dispose(); $previewMono.Dispose()
$content.Dispose(); $fg.Dispose(); $small.Dispose(); $src.Dispose()
Write-Host "icones gerados em $resDir"
