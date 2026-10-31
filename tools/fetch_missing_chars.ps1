# Meigenly: busca fotos dos personagens sem imagem (lotes 3/4).
# Estrategia: elenco AniList da obra (paginado, com alternativas) -> match exato -> tokens ->
# variacoes (Levenshtein) -> nome unico -> Character(search) validado -> Fandom (casos pontuais).
# Imagens: lado maior <= 320px, JPEG q80 (o compress_chars.ps1 reduz depois se necessario).
#
# Uso:
#   powershell -File tools\fetch_missing_chars.ps1
#   powershell -File tools\fetch_missing_chars.ps1 -OnlyWork another
#   powershell -File tools\fetch_missing_chars.ps1 -DryRun
param(
    [string]$OnlyWork = '',
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$root = "$PSScriptRoot\.."
$assets = "$root\app\src\main\assets"
$charsRoot = "$assets\characters"
$seedPath = "$assets\seed\app_data.json"
$logPath = "$env:TEMP\meigenly_missing_chars.log"
$UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36'

$results = New-Object System.Collections.Generic.List[string]
function Add-Log([string]$line) {
    $results.Add($line)
    Write-Host $line
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Invoke-GraphQL([string]$query, [hashtable]$variables) {
    $body = @{ query = $query; variables = $variables } | ConvertTo-Json -Depth 8 -Compress
    $attempts = 0
    while ($true) {
        $attempts++
        try {
            $r = Invoke-RestMethod -Uri 'https://graphql.anilist.co' -Method Post `
                -ContentType 'application/json' -Headers @{ Accept = 'application/json' } `
                -Body ([System.Text.Encoding]::UTF8.GetBytes($body))
            if ($null -ne $r.errors) {
                Write-Host ("    API erro: " + (($r.errors | ForEach-Object { $_.message }) -join '; ')) -ForegroundColor Yellow
                return $null
            }
            return $r
        } catch {
            $status = $null
            if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
            if ($status -eq 429 -and $attempts -le 4) {
                Write-Host "    429 rate limit; aguardando 30s ($attempts/4)..." -ForegroundColor Yellow
                Start-Sleep -Seconds 30
                continue
            }
            if ($attempts -le 3) { Start-Sleep -Seconds 2; continue }
            Write-Host ("    GraphQL falhou: " + $_.Exception.Message) -ForegroundColor Yellow
            return $null
        }
    }
}

function Strip-Accent([string]$s) {
    $t = $s.Normalize([System.Text.NormalizationForm]::FormD)
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $t.ToCharArray()) {
        if ([System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch) -ne [System.Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$sb.Append($ch)
        }
    }
    return $sb.ToString().Normalize([System.Text.NormalizationForm]::FormC)
}

function NormName([string]$s) {
    if ([string]::IsNullOrWhiteSpace($s)) { return '' }
    $f = (Strip-Accent $s).ToLowerInvariant()
    $f = ($f -replace '[^a-z0-9]', '')
    $f = $f -replace 'ou', 'o'
    $f = $f -replace '(\w)\1', '$1'
    return $f
}

$Particles = @('no', 'de', 'da', 'do', 'of', 'the', 'von', 'van', 'o', 'a', 'der', 'la', 'le')
function NormTokens([string]$s) {
    if ([string]::IsNullOrWhiteSpace($s)) { return @() }
    $f = (Strip-Accent $s).ToLowerInvariant()
    $toks = @($f -split '[^a-z0-9]+' | Where-Object { $_ -ne '' -and $Particles -notcontains $_ } | ForEach-Object { $_ -replace 'ou', 'o' })
    return @($toks | Sort-Object)
}

function Get-Lev([string]$a, [string]$b) {
    if ($a -eq $b) { return 0 }
    $n = $a.Length; $m = $b.Length
    if ($n -eq 0) { return $m }
    if ($m -eq 0) { return $n }
    $prev = New-Object 'int[]' ($m + 1)
    $cur = New-Object 'int[]' ($m + 1)
    for ($j = 0; $j -le $m; $j++) { $prev[$j] = $j }
    for ($i = 1; $i -le $n; $i++) {
        $cur[0] = $i
        for ($j = 1; $j -le $m; $j++) {
            $cost = 1
            if ($a[$i - 1] -eq $b[$j - 1]) { $cost = 0 }
            $d1 = $cur[$j - 1] + 1
            $d2 = $prev[$j] + 1
            $d3 = $prev[$j - 1] + $cost
            $cur[$j] = [Math]::Min($d1, [Math]::Min($d2, $d3))
        }
        $tmp = $prev; $prev = $cur; $cur = $tmp
    }
    return $prev[$m]
}

function Test-TokenHit([string[]]$charToks, [string[]]$castToks) {
    if ($castToks.Count -lt 2) { return $false }
    if ($castToks.Count -gt $charToks.Count) { return $false }
    foreach ($ct in $castToks) {
        $found = $false
        foreach ($ht in $charToks) {
            if ($ct -eq $ht) { $found = $true; break }
            if ($ct.Length -ge 6 -and $ht.Length -ge 6 -and ($ct.Substring(0, 6) -eq $ht.Substring(0, 6))) { $found = $true; break }
            if ($ct.Length -ge 5 -and $ht.Length -ge 5 -and (Get-Lev $ct $ht) -le 1) { $found = $true; break }
        }
        if (-not $found) { return $false }
    }
    return $true
}

function Test-NameVariants([string]$a, [string]$b) {
    if ($a -eq $b) { return $true }
    if ($a.Length -lt 5 -or $b.Length -lt 5) { return $false }
    $max = if ([Math]::Max($a.Length, $b.Length) -ge 11) { 2 } else { 1 }
    return ((Get-Lev $a $b) -le $max)
}

function Save-Resized([string]$url, [string]$destPath) {
    if ([string]::IsNullOrWhiteSpace($url)) { return $false }
    $tmp = "$env:TEMP\meigenly_char_tmp.img"
    try {
        $headers = @{ 'User-Agent' = $UA }
        if ($url -match '^https?://([^/]+)/') {
            $h = $Matches[1]
            if ($h -match 'fandom\.com$|wikia\.nocookie\.net$') { $headers['Referer'] = "https://$($h -replace '^static\.', '')/" }
        }
        # Wikia mede a extensao pelo UA e entrega WebP; GDI+ nao le WebP -> pede PNG
        if ($url -match 'wikia\.nocookie\.net|\.fandom\.com/') {
            $sep = if ($url.Contains('?')) { '&' } else { '?' }
            if ($url -notmatch '[?&]format=') { $url = "$url${sep}format=png" }
        }
        $resp = Invoke-WebRequest -Uri $url -UseBasicParsing -Headers $headers -TimeoutSec 60
        [System.IO.File]::WriteAllBytes($tmp, [byte[]]$resp.Content)
        if ((Get-Item $tmp).Length -lt 1500) { return $false }
        $bmp = [System.Drawing.Bitmap]::FromFile($tmp)
        $longest = [Math]::Max($bmp.Width, $bmp.Height)
        $scale = if ($longest -gt 320) { 320.0 / $longest } else { 1.0 }
        $nw = [int][Math]::Max(1, [Math]::Round($bmp.Width * $scale))
        $nh = [int][Math]::Max(1, [Math]::Round($bmp.Height * $scale))
        $out = New-Object System.Drawing.Bitmap $nw, $nh
        $g = [System.Drawing.Graphics]::FromImage($out)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.DrawImage($bmp, 0, 0, $nw, $nh)
        $g.Dispose()
        $bmp.Dispose()
        $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
        $ep = New-Object System.Drawing.Imaging.EncoderParameters(1)
        $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]80)
        if (Test-Path $destPath) { Remove-Item $destPath -Force }
        $out.Save($destPath, $codec, $ep)
        $out.Dispose()
        return $true
    } catch {
        Write-Host "    download falhou: $url ($($_.Exception.Message))" -ForegroundColor Yellow
        return $false
    } finally {
        if (Test-Path $tmp) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
    }
}

function Get-FandomImage([string]$wikiHost, [string]$page) {
    $url = "https://$wikiHost/api.php?action=query&titles=$([uri]::EscapeDataString($page))&prop=pageimages&piprop=thumbnail|original&pithumbsize=500&format=json"
    try {
        $r = Invoke-RestMethod -Uri $url -Headers @{ 'User-Agent' = $UA } -TimeoutSec 30
        $pages = $r.query.pages
        foreach ($p in $pages.PSObject.Properties) {
            if ($null -ne $p.Value.thumbnail) { return $p.Value.thumbnail.source }
            if ($null -ne $p.Value.original) { return $p.Value.original.source }
        }
    } catch { }
    return $null
}

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

# obras cuja busca SEARCH_MATCH erra (mesmo id corrigido nas capas)
$mediaOverride = @{
    'love-bullet'      = 171729
    'ruridragon'       = 150440
    'natsume-yuujinchou' = 4081
}

# alias de busca quando o nome no seed difere do AniList
$aliasSearch = @{
    'kiyo-takamine'       = 'Kiyomaro Takamine'
    'nagumo'              = 'Yoichi Nagumo'
    'jack-o-estripador'   = 'Jack the Ripper'
    'mao-esquerda'        = 'Left Hand'
    'rei-demonio'         = 'Demon King'
    'nyanko-sensei'       = 'Madara'
}

# personagens que o AniList lista com outro nome (mapeamento manual dentro da obra)
$manualCast = @{
    'lili-men/nitori' = @{ media = 154350; name = 'Nito' }
    # coletanea Ghibli: media 199 = Spirited Away (elenco).
    # Ashitaka/San/Howl/Kiki vem de OUTROS filmes -> resolvidos for a do script.
    'studio-ghibli/zeniba' = @{ media = 199; name = 'Zeniba' }
    'studio-ghibli/haku'   = @{ media = 199; name = 'Haku' }
}

# imagens pontuais via Fandom (personagens fora do elenco AniList)
$fandomFallback = @{
    'digimon-adventure/angemon'   = @{ host = 'digimon.fandom.com'; page = 'Angemon' }
    'pokemon/jessie-james-meowth' = @{ host = 'pokemon.fandom.com'; page = 'Team Rocket trio' }
    'ruridragon/mae-da-ruri'      = @{ host = 'ruridragon.fandom.com'; page = 'Umi Aoki' }
    'ruridragon/yuka-maeda'       = @{ host = 'ruridragon.fandom.com'; page = 'Yuka Hagiwara' }
    'ultimate-exorcist-kiyoshi/tsurugi' = @{ host = 'ultimate-exorcist-kiyoshi.fandom.com'; page = 'Tsurugi Hijiri' }
}

$downloadSrc = Get-Content "$PSScriptRoot\download_images.ps1" -Raw -Encoding UTF8
$m = [regex]::Match($downloadSrc, '(?s)\$workQueries = @\((.*?)\r?\n\)')
if (-not $m.Success) { throw 'Nao achei $workQueries em download_images.ps1' }
$workQueries = Invoke-Expression ("@(" + $m.Groups[1].Value + ")")
$workBySlug = @{}
foreach ($w in $workQueries) { $workBySlug[$w.slug] = $w }

$seed = Get-Content $seedPath -Raw -Encoding UTF8 | ConvertFrom-Json

$mediaQuery = @'
query ($search: String, $type: MediaType) {
  Media(search: $search, type: $type, sort: SEARCH_MATCH) {
    id
    type
    startDate { year }
    title { romaji english }
  }
}
'@

$castQuery = @'
query ($id: Int, $page: Int) {
  Media(id: $id) {
    characters(page: $page, perPage: 25, sort: [ROLE, RELEVANCE]) {
      pageInfo { hasNextPage }
      edges { role node { name { full native alternative } image { large } } }
    }
  }
}
'@

$charQuery = @'
query ($search: String) {
  Character(search: $search) {
    name { full native alternative }
    image { large }
    media(perPage: 25, sort: POPULARITY_DESC) { nodes { id } }
  }
}
'@

function Get-Media([string]$search, [string]$type) {
    $r = Invoke-GraphQL $mediaQuery @{ search = $search; type = $type }
    if ($null -ne $r -and $null -ne $r.data.Media) { return $r.data.Media }
    return $null
}

function Get-Cast([int]$mediaId) {
    $cast = @()
    for ($page = 1; $page -le 5; $page++) {
        $r = Invoke-GraphQL $castQuery @{ id = $mediaId; page = $page }
        if ($null -eq $r -or $null -eq $r.data.Media) { break }
        $chars = $r.data.Media.characters
        foreach ($e in $chars.edges) {
            $cast += [pscustomobject]@{
                name = $e.node.name.full
                alts = @($e.node.name.alternative)
                url  = $e.node.image.large
                toks = @(NormTokens $e.node.name.full)
            }
        }
        if (-not $chars.pageInfo.hasNextPage) { break }
        Start-Sleep -Milliseconds 600
    }
    return $cast
}

function Find-CastMatch($cast, [string]$name, [string]$nameOriginal) {
    $key = NormName $name
    $keyOrig = NormName $nameOriginal

    # 1) exato (nome ou alternativa)
    foreach ($cand in $cast) {
        $keys = @(NormName $cand.name) + @($cand.alts | ForEach-Object { NormName $_ })
        if ($keys -contains $key -or ($keyOrig -ne '' -and $keys -contains $keyOrig)) {
            return @{ url = $cand.url; route = 'cast'; matched = $cand.name }
        }
    }
    if ($key.Length -lt 4) { return $null }

    # 2) mesmos tokens (ordem/acento/grafia tolerados)
    $toks = @(NormTokens $name)
    foreach ($cand in $cast) {
        if (Test-TokenHit $toks $cand.toks) { return @{ url = $cand.url; route = 'cast-tokens'; matched = $cand.name } }
    }

    # 3) variacao de grafia do nome completo (Sohma/Souma, Yasha-oh/Yasha-ou)
    foreach ($cand in $cast) {
        if (Test-NameVariants $key (NormName $cand.name)) {
            return @{ url = $cand.url; route = 'cast-variant'; matched = $cand.name }
        }
    }

    # 4) nome unico no elenco (Nagumo -> Yoichi Nagumo / Yuno <- Yuno Grinberryall)
    $cands1 = @($cast | Where-Object { $_.toks.Count -eq 1 -and $_.toks[0].Length -ge 4 -and $toks -contains $_.toks[0] })
    if ($cands1.Count -eq 1) { return @{ url = $cands1[0].url; route = 'cast-single'; matched = $cands1[0].name } }
    if ($toks.Count -eq 1 -and $toks[0].Length -ge 4) {
        $cands2 = @($cast | Where-Object { $_.toks -contains $toks[0] })
        if ($cands2.Count -eq 1) { return @{ url = $cands2[0].url; route = 'cast-partial'; matched = $cands2[0].name } }
    }
    return $null
}

# ---------------------------------------------------------------------------
# Execucao
# ---------------------------------------------------------------------------
$saved = 0; $missed = 0; $skipped = 0
foreach ($work in $seed.works) {
    if ($OnlyWork -ne '' -and $work.slug -ne $OnlyWork) { continue }
    $missing = @()
    foreach ($c in $work.characters) {
        $out = Join-Path (Join-Path $charsRoot $work.slug) "$($c.slug).jpg"
        if (-not (Test-Path $out)) { $missing += $c }
    }
    if ($missing.Count -eq 0) { continue }

    $wq = $workBySlug[$work.slug]
    Write-Host "`n=== $($work.slug)  ($($missing.Count) sem foto) ===" -ForegroundColor Cyan
    $mediaId = $null
    $media = $null
    if ($mediaOverride.ContainsKey($work.slug)) {
        $mediaId = [int]$mediaOverride[$work.slug]
        Write-Host "  midia fixa: $mediaId" -ForegroundColor DarkGray
    } elseif ($null -ne $wq) {
        $media = Get-Media $wq.search $wq.type
        if ($null -eq $media) {
            $other = if ($wq.type -eq 'ANIME') { 'MANGA' } else { 'ANIME' }
            $media = Get-Media $wq.search $other
        }
        if ($null -ne $media) {
            $mediaId = [int]$media.id
            Write-Host ("  midia: {0} [{1} {2}] {3}" -f $media.id, $media.type, $media.startDate.year, $media.title.romaji) -ForegroundColor DarkGray
        }
        Start-Sleep -Milliseconds 500
    }
    if ($null -eq $mediaId) { Write-Host '  sem midia AniList; apenas busca por personagem' -ForegroundColor Yellow }

    $cast = @()
    if ($null -ne $mediaId) { $cast = Get-Cast $mediaId }

    foreach ($c in $missing) {
        $out = Join-Path (Join-Path $charsRoot $work.slug) "$($c.slug).jpg"
        New-Item -ItemType Directory -Force -Path (Split-Path $out) | Out-Null
        $hit = Find-CastMatch $cast $c.name $c.nameOriginal
        $manualKey = "$($work.slug)/$($c.slug)"
        if ($null -eq $hit -and $manualCast.ContainsKey($manualKey) -and $null -ne $mediaId) {
            $mc = $manualCast[$manualKey]
            if ([int]$mc.media -eq $mediaId) {
                $mn = NormName $mc.name
                $found = @($cast | Where-Object { (NormName $_.name) -eq $mn })
                if ($found.Count -ge 1) { $hit = @{ url = $found[0].url; route = 'manual'; matched = $found[0].name } }
            }
        }
        $url = $null; $route = ''; $matched = ''
        if ($null -ne $hit) { $url = $hit.url; $route = $hit.route; $matched = $hit.matched }

        if ($null -eq $url -and $null -ne $mediaId) {
            # fallback: variacao do nome contra o elenco inteiro ja tentado; tenta busca por personagem
            $term = $c.name
            if ($aliasSearch.ContainsKey($c.slug)) { $term = $aliasSearch[$c.slug] }
            $r = Invoke-GraphQL $charQuery @{ search = $term }
            Start-Sleep -Milliseconds 500
            $ch = $null
            if ($null -ne $r -and $null -ne $r.data.Character) { $ch = $r.data.Character }
            if ($ch) {
                $key = NormName $c.name
                $inWork = @($ch.media.nodes | ForEach-Object { $_.id }) -contains $mediaId
                # alternativa sozinha nao vale (ex.: "Gary" e alternativa de Green Okido, de outra obra)
                $exact = (NormName $ch.name.full) -eq $key
                $ct = @(NormTokens $c.name)
                $ht = @(NormTokens $ch.name.full)
                $sameTokens = ($ct.Count -eq $ht.Count) -and (($ct -join '|') -eq ($ht -join '|'))
                if ($inWork -or $exact -or $sameTokens) {
                    $url = $ch.image.large
                    $matched = $ch.name.full
                    $route = if ($inWork) { 'search+media' } else { 'search' }
                } else {
                    Add-Log ("SKIP|{0}|{1}|{2}|busca retornou [{3}] (fora da obra)" -f $work.slug, $c.slug, $c.name, $ch.name.full)
                }
            }
        }

        if ($null -eq $url) {
            $fbKey = "$($work.slug)/$($c.slug)"
            if ($fandomFallback.ContainsKey($fbKey)) {
                $fb = $fandomFallback[$fbKey]
                $fbUrl = Get-FandomImage $fb.host $fb.page
                if ($null -ne $fbUrl) { $url = $fbUrl; $route = 'fandom'; $matched = $fb.page }
            }
        }

        if ($null -eq $url) {
            Add-Log ("MISS|{0}|{1}|{2}" -f $work.slug, $c.slug, $c.name)
            $missed++
            continue
        }
        if ($DryRun) {
            Add-Log ("DRY |{0}|{1}|{2}|{3}|{4}" -f $work.slug, $c.slug, $c.name, $route, $matched)
            continue
        }
        if (Save-Resized $url $out) {
            Add-Log ("OK  |{0}|{1}|{2}|{3}|{4}" -f $work.slug, $c.slug, $c.name, $route, $matched)
            $saved++
        } else {
            Add-Log ("FAIL|{0}|{1}|{2}|{3}" -f $work.slug, $c.slug, $c.name, $route)
            $missed++
        }
    }
}

Write-Host "`n=== RESUMO ===" -ForegroundColor Green
Write-Host ("salvos: {0} | sem imagem: {1}" -f $saved, $missed)
$results | Set-Content $logPath -Encoding UTF8
Write-Host "log: $logPath"
