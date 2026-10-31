# Meigenly: passada para as obras antigas (fotos de personagens + omori)
# Estrategia A: Media(search, format_in) + paginacao; match de nome com ordem invertida
# e variacao de romana (Asuka Langley Soryu <-> Souryuu).
param([switch]$Force)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$charsRoot = "$PSScriptRoot\..\app\src\main\assets\characters"

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
            if ($status -eq 429 -and $attempts -le 3) { Start-Sleep -Seconds 30; continue }
            return $null
        }
    }
}

function NormName([string]$s) {
    if ($null -eq $s) { return '' }
    $t = $s.Normalize([System.Text.NormalizationForm]::FormD)
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $t.ToCharArray()) {
        if ([System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch) -ne [System.Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$sb.Append($ch)
        }
    }
    $folded = $sb.ToString().Normalize([System.Text.NormalizationForm]::FormC).ToLowerInvariant()
    $folded = ($folded -replace '[^a-z0-9]', '')
    $folded = $folded -replace 'ou', 'o'
    # colapsa letras duplicadas (Souryuu -> Soryu, Ayanokouji -> Ayanokoji base)
    $folded = $folded -replace '(\w)\1', '$1'
    return $folded
}

function MatchName([string]$full, [string]$target) {
    $n = NormName $full
    $t = NormName $target
    if ($n -eq $t) { return $true }
    if ($n.Length -gt 4 -and $t.Length -gt 4) {
        if ($n.StartsWith($t) -or $t.StartsWith($n)) { return $true }
    }
    $parts = $full -split '\s+'
    if ($parts.Count -eq 2) {
        if ((NormName ($parts[1] + ' ' + $parts[0])) -eq $t) { return $true }
    }
    $tparts = $target -split '\s+'
    if ($tparts.Count -ge 2 -and $parts.Count -ge 2) {
        # mesmos tokens em qualquer ordem
        $a = (NormName $tparts[0]) + (NormName $tparts[1])
        $b = (NormName $parts[0]) + (NormName $parts[1])
        if ($a -eq $b) { return $true }
    }
    return $false
}

function Save-Image([string]$url, [string]$destPath) {
    if ([string]::IsNullOrWhiteSpace($url)) { return $false }
    try {
        $resp = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 60
        [System.IO.File]::WriteAllBytes($destPath, [byte[]]$resp.Content)
    } catch { return $false }
    return $true
}

# slug -> busca na AniList; $null slug aliases tratados manualmente no fim
$mrows = @(
    @{ ws='hunter-x-hunter';        search='Hunter x Hunter';              mt='ANIME'; fmt='TV' },
    @{ ws='ichi-the-witch';         search='Ichi the Witch';               mt='MANGA'; fmt='MANGA' },
    @{ ws='kimetsu-no-yaiba';       search='Demon Slayer: Kimetsu no Yaiba'; mt='ANIME'; fmt='TV' },
    @{ ws='kuroko-no-basket';       search='Kuroko no Basket';             mt='ANIME'; fmt='TV' },
    @{ ws='naruto-shippuden';       search='Naruto: Shippuuden';           mt='ANIME'; fmt='TV' },
    @{ ws='neon-genesis-evangelion'; search='Neon Genesis Evangelion';     mt='ANIME'; fmt='TV' },
    @{ ws='rezero';                 search='Re:Zero kara Hajimeru Isekai Seikatsu'; mt='ANIME'; fmt='TV' },
    @{ ws='serial-experiments-lain'; search='Serial Experiments Lain';     mt='ANIME'; fmt='TV' },
    @{ ws='shingeki-no-kyojin';     search='Shingeki no Kyojin';           mt='ANIME'; fmt='TV' },
    @{ ws='apothecary-diaries';     search='Kusuriya no Hitorigoto';       mt='ANIME'; fmt='TV' },
    @{ ws='tokyo-ghoul';            search='Tokyo Ghoul';                  mt='ANIME'; fmt='TV' },
    @{ ws='vinland-saga';           search='Vinland Saga';                 mt='ANIME'; fmt='TV' },
    @{ ws='classroom-of-the-elite'; search='Classroom of the Elite';       mt='ANIME'; fmt='TV' },
    @{ ws='sousou-no-frieren';      search='Sousou no Frieren';            mt='ANIME'; fmt='TV' },
    @{ ws='omori';                  search='OMORI';                        mt='MANGA'; fmt='MANGA' }
)

$mq = @'
query ($search: String, $type: MediaType, $fmtIn: [MediaFormat], $page: Int) {
  Media(search: $search, type: $type, format_in: $fmtIn) {
    format
    title { romaji }
    characters(page: $page, perPage: 50, sort: [ROLE]) {
      edges { node { name { full } image { large } } }
    }
  }
}
'@

foreach ($r in $mrows) {
    $dir = Join-Path $charsRoot $r.ws
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    # dest slugs derivados do seed
    $seed = Get-Content "$PSScriptRoot\..\app\src\main\assets\seed\app_data.json" -Raw -Encoding UTF8 | ConvertFrom-Json
    $work = $seed.works | Where-Object { $_.slug -eq $r.ws }
    if ($null -eq $work) { continue }
    $left = New-Object System.Collections.Generic.List[object]
    foreach ($c in $work.characters) {
        if (-not (Test-Path (Join-Path $dir "$($c.slug).jpg"))) {
            $left.Add(@{ dest = $c.slug; name = $c.name })
        }
    }
    if ($left.Count -eq 0) { continue }
    foreach ($page in 1, 2, 3) {
        if ($left.Count -eq 0) { break }
        $res = Invoke-GraphQL $mq @{ search = $r.search; type = $r.mt; fmtIn = @($r.fmt); page = $page }
        if ($null -eq $res -or $null -eq $res.data.Media) { break }
        foreach ($e in $res.data.Media.characters.edges) {
            foreach ($t in $left.ToArray()) {
                if (MatchName $e.node.name.full $t.name) {
                    $out = Join-Path $dir "$($t.dest).jpg"
                    if (Save-Image $e.node.image.large $out) {
                        Write-Host ("  OK {0}/{1} <- {2}" -f $r.ws, $t.dest, $e.node.name.full) -ForegroundColor Green
                        $left.Remove($t)
                    }
                    break
                }
            }
        }
        Start-Sleep -Milliseconds 800
    }
    foreach ($t in $left) {
        Write-Host ("  PENDENTE {0}/{1} [{2}]" -f $r.ws, $t.dest, $t.name) -ForegroundColor Yellow
    }
}
