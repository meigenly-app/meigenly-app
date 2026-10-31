# Meigenly: conserto dos PENDENTE do lote 2 + masaki (imagem errada de Ichigo).
# Busca individual: Character(search, SEARCH_MATCH) + filtro de obra na media; match por nome.
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
    $folded = $folded -replace '(\w)\1', '$1'
    return $folded
}

$stopTokens = @('do','da','de','dos','das','the','no','na','san','sama')
function TokenSet([string]$name) {
    if ($null -eq $name) { return @() }
    return ($name -split '\s+') | ForEach-Object { NormName $_ } | Where-Object { $_.Length -ge 3 -and $stopTokens -notcontains $_ }
}

function Save-Image([string]$url, [string]$destPath) {
    if ([string]::IsNullOrWhiteSpace($url)) { return $false }
    try {
        $resp = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 60
        [System.IO.File]::WriteAllBytes($destPath, [byte[]]$resp.Content)
    } catch { return $false }
    return $true
}

# slug do alvo -> nome de busca no AniList (quando o romaji diverge)
$csOverride = @{
    'bleach/masaki-kurosaki'        = 'Masaki Kurosaki'
    'bleach/yamamoto'               = 'Yamamoto'
    'bleach/nimaiya-oetsu'          = 'Ouetsu Nimaiya'
    'bleach/ichibei-hyosube'        = 'Ichibei'
    'bleach/askin'                  = 'Askin'
    'bleach/nelliel'                = 'Nelliel'
    'bleach/yammy-llargo'           = 'Yammy'
    'bleach/luppi-antenor'          = 'Luppi'
    'bleach/dordonii'               = 'Dordonii'
    'bleach/nnoitra-gilga'          = 'Nnoitra'
    'bleach/mask-de-masculine'      = 'Mask De Masculine'
    'bleach/bazz-b'                 = 'Bazz'
    'dgray-man/conde-do-milenio'    = 'Millennium Earl'
    'berserk/cavaleiro-caveira'     = 'Skull Knight'
    'dragon-ball-z/son-goku'        = 'Goku'
    'dragon-ball-z/trunks-do-futuro' = 'Trunks'
    'dragon-ball-gt/son-goku'       = 'Goku'
    'dragon-ball-gt/narrador'       = 'Narrator'
    'one-piece/gol-d-roger'         = 'Roger'
    'one-piece/dr-hiriluk'          = 'Hiriluk'
    'one-piece/barba-branca'        = 'Edward Newgate'
    'dororo/daigo-kagemitsu'        = 'Kagemitsu'
    'ergo-proxy/ergo-proxy'         = 'Ergo Proxy'
}

# slug da obra -> keyword para casar a media dos candidatos
$workKw = @{
    'berserk'             = 'Berserk'
    'bleach'              = 'Bleach'
    'clannad'             = 'Clannad'
    'dgray-man'           = 'D.Gray'
    'dororo'              = 'Dororo'
    'dragon-ball-gt'      = 'Dragon Ball GT'
    'dragon-ball-z'       = 'Dragon Ball Z'
    'ergo-proxy'          = 'Ergo Proxy'
    'gantz'               = 'Gantz'
    'kingdom'             = 'Kingdom'
    'one-piece'           = 'One Piece'
}

$q = @'
query ($search: String) {
  Page(perPage: 10) {
    characters(search: $search, sort: [SEARCH_MATCH]) {
      name { full }
      image { large }
      media { nodes { title { english romaji native } } }
    }
  }
}
'@

$seed = Get-Content "$PSScriptRoot\..\app\src\main\assets\seed\app_data.json" -Raw -Encoding UTF8 | ConvertFrom-Json

foreach ($w in $seed.works) {
    if (-not $workKw.ContainsKey($w.slug)) { continue }
    $dir = Join-Path $charsRoot $w.slug
    foreach ($c in $w.characters) {
        $out = Join-Path $dir "$($c.slug).jpg"
        if (Test-Path $out) { continue }
        $key = "$($w.slug)/$($c.slug)"
        $cs = $c.name
        if ($csOverride.ContainsKey($key)) { $cs = $csOverride[$key] }
        $b = @{ query = $q; variables = @{ search = $cs } } | ConvertTo-Json -Depth 6 -Compress
        $res = Invoke-GraphQL $q @{ search = $cs }
        if ($null -eq $res -or $null -eq $res.data.Page.characters) {
            Write-Host "  PENDENTE $key (sem resposta)"
            Start-Sleep -Milliseconds 700
            continue
        }
        $tn = NormName $c.name
        $tt = @(TokenSet $c.name)
        $picked = $null
        foreach ($cand in $res.data.Page.characters) {
            $titles = $cand.media.nodes | ForEach-Object { "$($_.title.english) $($_.title.romaji) $($_.title.native)" }
            $inWork = $titles | Where-Object { $_ -match $workKw[$w.slug] }
            if (-not $inWork) { continue }
            $cn = NormName $cand.name.full
            $matched = ($cn -eq $tn) -or ($cn -like "*$tn*" -and $tn.Length -ge 4) -or (($tt | Where-Object { (TokenSet $cand.name.full) -contains $_ }).Count -gt 0)
            if ($matched) { $picked = $cand; break }
        }
        if ($picked) {
            if (Save-Image $picked.image.large $out) {
                Write-Host "  OK $key <- $($picked.name.full)"
            } else {
                Write-Host "  PENDENTE $key (download falhou)"
            }
        } else {
            Write-Host "  PENDENTE $key [$($c.name)]"
        }
        Start-Sleep -Milliseconds 700
    }
}
