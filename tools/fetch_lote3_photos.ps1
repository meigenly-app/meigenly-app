# Meigenly lote v0.9.3: fotos dos 9 alvos pendentes (renames inclusos: o slug final volta a bater com o converter).
# Estrategia igual lote anterior: AniList GraphQL (Character search / Media scan / Media cover) + Fandom fallback,
# resize lado maior <=160px, JPEG q78. Dispose() ANTES de qualquer move/overwrite.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$charsRoot = "$PSScriptRoot\..\app\src\main\assets\characters"
$UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36'

function Invoke-GraphQL([string]$query, [hashtable]$variables) {
    $body = @{ query = $query; variables = $variables } | ConvertTo-Json -Depth 6 -Compress
    $attempts = 0
    while ($true) {
        $attempts++
        try {
            return Invoke-RestMethod -Uri 'https://graphql.anilist.co' -Method Post `
                -ContentType 'application/json' -Headers @{ Accept = 'application/json' } `
                -Body ([System.Text.Encoding]::UTF8.GetBytes($body))
        } catch {
            $status = $null
            if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
            if ($status -eq 429 -and $attempts -le 3) {
                Write-Host "  429; aguardando 30s ($attempts/3)..." -ForegroundColor Yellow
                Start-Sleep -Seconds 30
                continue
            }
            return $null
        }
    }
}

function Save-Resized([string]$url, [string]$destPath) {
    if ([string]::IsNullOrWhiteSpace($url)) { return $false }
    try {
        $resp = Invoke-WebRequest -Uri $url -UseBasicParsing -UserAgent $UA -TimeoutSec 60
        $tmp = "$env:TEMP\meigenly_tmp.img"
        [System.IO.File]::WriteAllBytes($tmp, [byte[]]$resp.Content)
        $src = [System.Drawing.Bitmap]::FromFile($tmp)
        $src.Dispose()
        # A partir do arquivo (nao bitmap aberto): escalado limpo
        $bmp = [System.Drawing.Bitmap]::FromFile($tmp)
        $longest = [Math]::Max($bmp.Width, $bmp.Height)
        $scale = if ($longest -gt 160) { 160.0 / $longest } else { 1.0 }
        $nw = [int][Math]::Max(1, [Math]::Round($bmp.Width * $scale))
        $nh = [int][Math]::Max(1, [Math]::Round($bmp.Height * $scale))
        $out = New-Object System.Drawing.Bitmap $nw, $nh
        $g = [System.Drawing.Graphics]::FromImage($out)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.DrawImage($bmp, 0, 0, $nw, $nh)
        $g.Dispose()
        $bmp.Dispose()
        if (Test-Path $destPath) { Remove-Item $destPath -Force }
        $out.Save($destPath, [System.Drawing.Imaging.ImageFormat]::Jpeg)
        $out.Dispose()
        return $true
    } catch {
        Write-Host "    download falhou: $url" -ForegroundColor Yellow
        return $false
    }
}

function Save-Cover([string]$url, [string]$destPath) {
    if ([string]::IsNullOrWhiteSpace($url)) { return $false }
    try {
        $resp = Invoke-WebRequest -Uri $url -UseBasicParsing -UserAgent $UA -TimeoutSec 60
        $tmp = "$env:TEMP\meigenly_tmp.img"
        [System.IO.File]::WriteAllBytes($tmp, [byte[]]$resp.Content)
        $bmp = [System.Drawing.Bitmap]::FromFile($tmp)
        # capa 'retrato' no padrao covers: 80x106 (proporcao 3:4 de 160px) center-crop
        $W = 80; $H = 106
        $cover = New-Object System.Drawing.Bitmap $W, $H
        $g = [System.Drawing.Graphics]::FromImage($cover)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        # crop proporcional
        $ratio = [Math]::Max($W / $bmp.Width, $H / $bmp.Height)
        $cw = $W / $ratio; $ch = $H / $ratio
        $sx = ($bmp.Width - $cw) / 2.0; $sy = [Math]::Max(0.0, ($bmp.Height - $ch) / 3.0)
        $g.DrawImage($bmp, (New-Object System.Drawing.Rectangle 0, 0, $W, $H), $sx, $sy, $cw, $ch, [System.Drawing.GraphicsUnit]::Pixel)
        $g.Dispose()
        $bmp.Dispose()
        if (Test-Path $destPath) { Remove-Item $destPath -Force }
        $cover.Save($destPath, [System.Drawing.Imaging.ImageFormat]::Jpeg)
        $cover.Dispose()
        return $true
    } catch {
        Write-Host "    download falhou (capa): $url" -ForegroundColor Yellow
        return $false
    }
}

# Media por busca (retorna Media com characters)
function Get-Media([string]$search, [string]$type) {
    $q = @'
query ($search: String, $type: MediaType) {
  Media(search: $search, type: $type, sort: SEARCH_MATCH) {
    id
    format
    title { english romaji native }
    coverImage { extraLarge }
    characters(perPage: 50, sort: [ROLE]) {
      edges { node { name { full native alternative } image { large } } }
    }
  }
}
'@
    $res = Invoke-GraphQL $q @{ search = $search; type = $type }
    if ($null -ne $res -and $null -ne $res.data.Media) { return $res.data.Media }
    return $null
}

function Get-CharBySearch([string]$search) {
    $q = @'
query ($search: String) {
  Character(search: $search) {
    name { full alternative }
    image { large }
  }
}
'@
    $res = Invoke-GraphQL $q @{ search = $search }
    if ($null -ne $res -and $null -ne $res.data.Character) { return $res.data.Character }
    return $null
}

function Get-CharById([int]$id) {
    $q = 'query { Character(id: ' + $id + ') { name { full } image { large } } }'
    $res = Invoke-GraphQL $q @{}
    if ($null -ne $res -and $null -ne $res.data.Character) { return $res.data.Character }
    return $null
}

# Fandom: busca pagina e pega a 1a imagem lexando o wikitext
function Get-FandomImage([string]$wikiApi, [string]$page) {
    try {
        $enc = [System.Uri]::EscapeDataString($page)
        $u = "$wikiApi`?action=parse&page=$enc&prop=wikitext&format=json"
        $r = Invoke-WebRequest -Uri $u -UseBasicParsing -UserAgent $UA -Headers @{ 'Referer' = $wikiApi } -TimeoutSec 45
        $wt = (($r.Content | ConvertFrom-Json).parse.wikitext.'*')
        if (-not $wt) { return $null }
        $m = [regex]::Match($wt, '(?:image\s*=\s*|File:|\[\[)([A-Za-z0-9_ %\.\-\(\)]+\.(?:png|jpg|jpeg))', 'IgnoreCase')
        if (-not $m.Success) { return $null }
        $file = $m.Groups[1].Value.Trim()
        # Special:FilePath aceita width p/ thumb
        return "$($wikiApi.Split('/api.php')[0])/api.php?action=query&titles=$([System.Uri]::EscapeDataString('File:' + $file))&prop=imageinfo&iiprop=url&iiurlwidth=400&format=json"
    } catch { return $null }
}

function Get-FandomTargetImage([string]$wikiApi, [string]$page) {
    try {
        $enc = [System.Uri]::EscapeDataString($page)
        $u = "$wikiApi`?action=query&titles=$enc&prop=imageinfo&iiprop=url&iiurlwidth=400&format=json"
        $r = Invoke-WebRequest -Uri $u -UseBasicParsing -UserAgent $UA -Headers @{ 'Referer' = $wikiApi } -TimeoutSec 45
        $j = $r.Content | ConvertFrom-Json
        return $j.query.pages.PSObject.Properties.Value.imageinfo | Select-Object -First 1
    } catch { return $null }
}

$report = @()

# 1) kingdom/kan-ki.jpg — "Kan Ki" (Kingdom, pinyin)
do {
    $dest = "$charsRoot\kingdom\kan-ki.jpg"
    $m = Get-Media 'Kingdom' 'MANGA'
    $hit = $null
    if ($m -and $m.title.english -match 'Kingdom') {
        $hit = $m.characters.edges | Where-Object { $_.node.name.full -match 'Kan Ki|Kanki' } | Select-Object -First 1
    }
    if ($null -eq $hit) { $c = Get-CharBySearch 'Kan Ki'; if ($c -and $c.name.full -match 'Kan Ki|Kanki') { $hit = @{ node = $c } } }
    if ($hit) {
        $imgUrl = $hit.node.image.large
        $ok = Save-Resized $imgUrl $dest
        $report += @{ alvo = 'kingdom/kan-ki'; ok = $ok; nome = $hit.node.name.full; url = $imgUrl }
    } else {
        $report += @{ alvo = 'kingdom/kan-ki'; ok = $false; nome = 'NAO ACHADO' }
    }
} while ($false)
Start-Sleep -Milliseconds 700

# 2) dragon-ball-gt/gogeta.jpg
do {
    $dest = "$charsRoot\dragon-ball-gt\gogeta.jpg"
    $c = Get-CharBySearch 'Gogeta'
    if ($c) {
        $ok = Save-Resized $c.image.large $dest
        $report += @{ alvo = 'dragon-ball-gt/gogeta'; ok = $ok; nome = $c.name.full; url = $c.image.large }
    } else { $report += @{ alvo = 'dragon-ball-gt/gogeta'; ok = $false; nome = 'NAO ACHADO' } }
} while ($false)
Start-Sleep -Milliseconds 700

# 3) dragon-ball-gt/narrador.jpg — capa da propria obra (autorizado pelo usuario)
do {
    $dest = "$charsRoot\dragon-ball-gt\narrador.jpg"
    $m = Get-Media 'Dragon Ball GT' 'ANIME'
    if ($m -and $m.title.romaji -match 'Dragon Ball GT') {
        $ok = Save-Resized $m.coverImage.extraLarge $dest
        $report += @{ alvo = 'dragon-ball-gt/narrador'; ok = $ok; nome = "CAPA: $($m.title.english)"; url = $m.coverImage.extraLarge }
    } else { $report += @{ alvo = 'dragon-ball-gt/narrador'; ok = $false; nome = 'MEDIA NAO ACHADA' } }
} while ($false)
Start-Sleep -Milliseconds 700

# 4) ergo-proxy/proxy.jpg — redesenha por scan do Media
do {
    $dest = "$charsRoot\ergo-proxy\proxy.jpg"
    $m = Get-Media 'Ergo Proxy' 'ANIME'
    $hit = $null; $prevUrl = $null
    if ($m -and ($m.title.english -match 'Ergo Proxy' -or $m.title.romaji -match 'Ergo')) {
        $prevUrl = $m.coverImage.extraLarge
        $hit = $m.characters.edges | Where-Object {
            $_.node.name.full -eq 'Proxy' -or ($_.node.name.full -match 'Proxy' -and $_.node.name.full -notmatch 'Re-?l|Vincent|Law')
        } | Select-Object -First 1
    }
    if ($hit) {
        $ok = Save-Resized $hit.node.image.large $dest
        $report += @{ alvo = 'ergo-proxy/proxy'; ok = $ok; nome = $hit.node.name.full; url = $hit.node.image.large }
    } else {
        # fallback autorizado: capa da obra
        $ok = Save-Resized $prevUrl $dest
        $report += @{ alvo = 'ergo-proxy/proxy'; ok = $ok; nome = 'FALLBACK CAPA da obra'; url = $prevUrl }
    }
} while ($false)
Start-Sleep -Milliseconds 700

# 5) centuria/sea.jpg — "Sea", fandom (Centuria Wiki) -> fallback capa da obra
do {
    $dest = "$charsRoot\centuria\sea.jpg"
    $got = $false; $imgUrl = $null
    $info = Get-FandomTargetImage 'https://centuria.fandom.com/api.php' 'Sea'
    if ($info) { $imgUrl = $info.thumburl; if (-not $imgUrl) { $imgUrl = $info.url } }
    if ($imgUrl) { $got = Save-Resized $imgUrl $dest }
    if (-not $got) {
        $m = Get-Media 'Centuria' 'MANGA'
        if ($m -and $m.title.romaji -match 'Centuria') {
            $imgUrl = $m.coverImage.extraLarge
            $got = Save-Resized $imgUrl $dest
        }
    }
    $which = if ($imgUrl) { $imgUrl } else { 'NADA' }
    $report += @{ alvo = 'centuria/sea'; ok = $got; nome = $which; url = $imgUrl }
} while ($false)
Start-Sleep -Milliseconds 700

# 6) daemons-of-the-shadow-realm/ryu-tadera.jpg — id 334313 "Ryuu Tadera"
do {
    $dest = "$charsRoot\daemons-of-the-shadow-realm\ryu-tadera.jpg"
    $c = Get-CharById 334313
    if ($c) {
        $ok = Save-Resized $c.image.large $dest
        $report += @{ alvo = 'daemons/ryu-tadera'; ok = $ok; nome = $c.name.full; url = $c.image.large }
    } else { $report += @{ alvo = 'daemons/ryu-tadera'; ok = $false; nome = 'NAO ACHADO(id 334313)' } }
} while ($false)
Start-Sleep -Milliseconds 700

# 7) daemons-of-the-shadow-realm/right.jpg — "Migi/Right" id 324638
do {
    $dest = "$charsRoot\daemons-of-the-shadow-realm\right.jpg"
    $c = Get-CharById 324638
    if ($c) {
        $ok = Save-Resized $c.image.large $dest
        $report += @{ alvo = 'daemons/right'; ok = $ok; nome = $c.name.full; url = $c.image.large }
    } else { $report += @{ alvo = 'daemons/right'; ok = $false; nome = 'NAO ACHADO(id 324638)' } }
} while ($false)
Start-Sleep -Milliseconds 700

# 8) gantz/gantz.jpg — esfera negra: capa do Media Gantz (cover iconico)
do {
    $dest = "$charsRoot\gantz\gantz.jpg"
    $m = Get-Media 'Gantz' 'ANIME'
    if ($m -and $m.title.romaji -match 'Gantz') {
        $ok = Save-Resized $m.coverImage.extraLarge $dest
        $report += @{ alvo = 'gantz/gantz'; ok = $ok; nome = "CAPA: $($m.title.english)"; url = $m.coverImage.extraLarge }
    } else { $report += @{ alvo = 'gantz/gantz'; ok = $false; nome = 'MEDIA NAO ACHADA' } }
} while ($false)
Start-Sleep -Milliseconds 700

# 9) tokyo-ghoul-re/haise-sasaki.jpg — fix foto duplicada do Kaneki
do {
    $dest = "$charsRoot\tokyo-ghoul-re\haise-sasaki.jpg"
    $c = $null
    foreach ($q in @('Haise Sasaki', 'Sasaki Haise')) {
        $c = Get-CharBySearch $q
        if ($c -and $c.name.full -match 'Haise') { break }
        Start-Sleep -Milliseconds 700
    }
    if ($c -and $c.name.full -match 'Haise') {
        $ok = Save-Resized $c.image.large $dest
        $report += @{ alvo = 'tokyo-ghoul-re/haise-sasaki'; ok = $ok; nome = $c.name.full; url = $c.image.large }
    } else { $report += @{ alvo = 'tokyo-ghoul-re/haise-sasaki'; ok = $false; nome = 'NAO ACHADO' } }
} while ($false)

# ---- Relatorio ----
Write-Host "`n===== RELATORIO ====="
foreach ($r in $report) {
    $status = if ($r.ok) { 'OK  ' } else { 'FAIL' }
    Write-Host ("  [{0}] {1,-32} {2}" -f $status, $r.alvo, $r.nome)
}
