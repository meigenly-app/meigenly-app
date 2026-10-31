# Meigenly: foto para as obras antigas restantes (lote 2).
# Estrategia: Media(search, format_in TV/MANGA) paginado + matcher em estagios
# (dict PT->EN, igualdade exata, contencao de nome, token unico) + fallback de busca por personagem.
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

$stopTokens = @('do','da','de','dos','das','the','no','na','ni','san','sama')

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

# nome PT e coloquial -> nome exato no AniList
$dict = @{
    'saint-seiya/seiya-de-pegaso'   = 'Pegasus Seiya'
    'saint-seiya/ikki-de-fenix'     = 'Phoenix Ikki'
    'saint-seiya/shiryu-de-dragao'  = 'Dragon Shiryu'
    'saint-seiya/saga-de-gemeos'    = 'Gemini Saga'
    'saint-seiya/shaka-de-virgem'   = 'Virgo Shaka'
    'saint-seiya/camus-de-aquario'  = 'Aquarius Camus'
    'berserk/cavaleiro-caveira'     = 'Skull Knight'
    'dgray-man/conde-do-milenio'    = 'Millennium Earl'
    'one-piece/barba-branca'        = 'Edward Newgate'
    'one-piece/dr-hiriluk'          = 'Hiriluk'
    'dragon-ball-gt/narrador'       = 'Narrator'
    'kingdom/wang-qi'               = 'Ou Ki'
}

# slug da obra -> busca AniList + formato
$works = @(
    @{ ws='berserk';            search='Berserk';                          fmt='TV' }
    @{ ws='bleach';             search='Bleach';                           fmt='TV' }
    @{ ws='saint-seiya';        search='Saint Seiya';                      fmt='TV' }
    @{ ws='clannad';            search='Clannad';                          fmt='TV' }
    @{ ws='claymore';           search='Claymore';                         fmt='TV' }
    @{ ws='code-geass';         search='Code Geass: Hangyaku no Lelouch';  fmt='TV' }
    @{ ws='cowboy-bebop';       search='Cowboy Bebop';                     fmt='TV' }
    @{ ws='dgray-man';          search='D.Gray-man';                       fmt='TV' }
    @{ ws='dororo';             search='Dororo';                           fmt='TV' }
    @{ ws='dragon-ball-gt';     search='Dragon Ball GT';                   fmt='TV' }
    @{ ws='dragon-ball-z';      search='Dragon Ball Z';                    fmt='TV' }
    @{ ws='ergo-proxy';         search='Ergo Proxy';                       fmt='TV' }
    @{ ws='fullmetal-alchemist'; search='Fullmetal Alchemist: Brotherhood'; fmt='TV' }
    @{ ws='gachiakuta';         search='Gachiakuta';                       fmt='TV' }
    @{ ws='gantz';              search='Gantz';                            fmt='TV' }
    @{ ws='hajime-no-ippo';     search='Hajime no Ippo';                   fmt='TV' }
    @{ ws='jujutsu-kaisen';     search='Jujutsu Kaisen';                   fmt='TV' }
    @{ ws='kingdom';            search='Kingdom';                          fmt='TV' }
    @{ ws='mob-psycho-100';     search='Mob Psycho 100';                   fmt='TV' }
    @{ ws='naruto';             search='Naruto';                           fmt='TV' }
    @{ ws='one-piece';          search='One Piece';                        fmt='TV' }
    @{ ws='shingeki-no-kyojin'; search='Shingeki no Kyojin';               fmt='TV' }
    @{ ws='tokyo-revengers';    search='Tokyo Revengers';                  fmt='TV' }
    @{ ws='toriko';             search='Toriko';                           fmt='TV' }
)

$mq = @'
query ($search: String, $fmtIn: [MediaFormat], $page: Int) {
  Media(search: $search, type: ANIME, format_in: $fmtIn) {
    characters(page: $page, perPage: 50, sort: [ROLE]) {
      edges { node { name { full } image { large } } }
    }
  }
}
'@

function Find-Char([object[]]$candidates, [hashtable]$target) {
    # estagio 0: dict
    $key = "$($target.ws)/$($target.dest)"
    if ($dict.ContainsKey($key)) {
        $wanted = $dict[$key]
        foreach ($c in $candidates) {
            if ((NormName $c.name) -eq (NormName $wanted)) { return $c }
        }
    }
    $tn = $target.norm
    # estagio 1: igualdade exata
    foreach ($c in $candidates) {
        if ((NormName $c.name) -eq $tn) { return $c }
    }
    # estagio 2: contencao (nome inteiro), min len 4
    $hits = @($candidates | Where-Object {
        $cn = NormName $_.name
        ($cn.Length -ge 4 -and $cn.Contains($tn)) -or ($tn.Length -ge 4 -and $tn.Contains($cn) -and $cn.Length -ge 4)
    })
    if ($hits.Count -eq 1) { return $hits[0] }
    # estagio 3: tokens de sobreposicao unicos (token >= 3, sem stopword)
    $ttokens = $target.tokens
    $hits = @()
    foreach ($c in $candidates) {
        $ctokens = TokenSet $c.name
        foreach ($t in $ttokens) {
            if ($ctokens -contains $t) { $hits += $c; break }
        }
    }
    if ($hits.Count -eq 1) { return $hits[0] }
    return $null
}

$seed = Get-Content "$PSScriptRoot\..\app\src\main\assets\seed\app_data.json" -Raw -Encoding UTF8 | ConvertFrom-Json

foreach ($r in $works) {
    $dir = Join-Path $charsRoot $r.ws
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $work = $seed.works | Where-Object { $_.slug -eq $r.ws }
    if ($null -eq $work) { Write-Host "OBRA AUSENTE NO SEED: $($r.ws)"; continue }
    $targets = @()
    foreach ($c in $work.characters) {
        if (-not (Test-Path (Join-Path $dir "$($c.slug).jpg"))) {
            $targets += @{
                dest = $c.slug
                name = $c.name
                norm = NormName $c.name
                tokens = @(TokenSet $c.name)
                ws = $r.ws
            }
        }
    }
    if ($targets.Count -eq 0) { continue }
    # coleta candidatos (paginas 1..4)
    $candidates = New-Object System.Collections.Generic.List[object]
    foreach ($page in 1, 2, 3, 4) {
        $res = Invoke-GraphQL $mq @{ search = $r.search; fmtIn = @($r.fmt); page = $page }
        if ($null -eq $res -or $null -eq $res.data.Media) { break }
        $edges = $res.data.Media.characters.edges
        if ($null -eq $edges) { break }
        foreach ($e in $edges) {
            $candidates.Add(@{ name = $e.node.name.full; img = $e.node.image.large })
        }
        if ($edges.Count -lt 50) { break }
        Start-Sleep -Milliseconds 800
    }
    foreach ($t in $targets) {
        $picked = Find-Char $candidates.ToArray() $t
        if ($picked) {
            $out = Join-Path $dir "$($t.dest).jpg"
            if (Save-Image $picked.img $out) {
                Write-Host "  OK $($r.ws)/$($t.dest) <- $($picked.name)"
                continue
            }
        }
        Write-Host "  PENDENTE $($r.ws)/$($t.dest) [$($t.name)]"
    }
    Start-Sleep -Milliseconds 800
}
