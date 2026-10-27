# Meigenly: 2a passada (v3) - estrategia A corrigida (strict match + dest slugs)
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
    return ($folded -replace '[^a-z0-9]', '')
}

function MatchName([string]$full, [string]$target) {
    $n = NormName $full
    $t = NormName $target
    if ($n -eq $t) { return $true }
    # variantes de romana (kes/kess etc): permite ordem invertida sobrenome-nome
    $parts = $full -split '\s+'
    if ($parts.Count -eq 2) {
        $reversed = NormName ($parts[1] + ' ' + $parts[0])
        if ($reversed -eq $t) { return $true }
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

# (ws, search, fmt, atalhos: dest=slug do app, names=aceitos no AniList, extraOutras=aceitos adicionais)
$mrows = @(
    @{ ws='the-summer-hikaru-died'; search='Hikaru ga Shinda Natsu'; fmt='MANGA';
       targets=@(
           @{ dest='yoshiki'; names=@('Yoshiki Tsujinaka') },
           @{ dest='hikaru'; names=@('Hikaru','Hikaru Indou') },
           @{ dest='tanaka';  names=@('Kaoru Tanaka','Tanaka') }
       ) },
    @{ ws='tokyo-ghoul-re'; search='Tokyo Ghoul:re'; fmt='MANGA';
       targets=@(
           @{ dest='haise-sasaki'; names=@('Haise Sasaki','Ken Kaneki') }
       ) },
    @{ ws='haikyu'; search='Haikyu!!'; fmt='MANGA';
       targets=@(
           @{ dest='kotaro-bokuto'; names=@('Kotaro Bokuto') }
       ) },
    @{ ws='yu-yu-hakusho'; search='Yu Yu Hakusho'; fmt='TV';
       targets=@(
           @{ dest='younger-toguro'; names=@('Younger Toguro','Toguro Otouto') }
       ) },
    @{ ws='angel-beats'; search='Angel Beats!'; fmt='TV';
       targets=@(
           @{ dest='yui'; names=@('Yui','Yui Yoshioka') }
       ) },
    @{ ws='servamp'; search='Servamp'; fmt='TV';
       targets=@(
           @{ dest='misono-alicein'; names=@('Misono Alicein') }
       ) },
    @{ ws='toilet-bound-hanako-kun'; search='Toilet-Bound Hanako-kun'; fmt='TV';
       targets=@(
           @{ dest='hanako-kun'; names=@('Hanako-kun','Hanako') }
       ) },
    @{ ws='daemons-of-the-shadow-realm'; search='Daemons of the Shadow Realm'; fmt='MANGA';
       targets=@(
           @{ dest='dera'; names=@('Dera') },
           @{ dest='direita'; names=@('Direita') }
       ) },
    @{ ws='omori'; search='OMORI'; fmt='MANGA';
       targets=@(
           @{ dest='omori'; names=@('Omori') }
       ) }
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
    $left = $r.targets | Where-Object { -not (Test-Path (Join-Path $dir "$($_.dest).jpg")) }
    foreach ($page in 1, 2, 3, 4) {
        if ($left.Count -eq 0) { break }
        $res = Invoke-GraphQL $mq @{ search = $r.search; type = 'ANIME'; fmtIn = @($r.fmt); page = $page }
        if ($r.fmt -eq 'MANGA') {
            $res = Invoke-GraphQL $mq @{ search = $r.search; type = 'MANGA'; fmtIn = @($r.fmt); page = $page }
        }
        if ($null -eq $res -or $null -eq $res.data.Media) { break }
        Write-Host ("  [{0}] pag {1}: {2} edges | formato {3}" -f $r.ws, $page, @($res.data.Media.characters.edges).Count, $res.data.Media.format) -ForegroundColor DarkGray
        foreach ($t in $left) {
            foreach ($e in $res.data.Media.characters.edges) {
                $matched = $false
                foreach ($nm in $t.names) {
                    if (MatchName $e.node.name.full $nm) { $matched = $true; break }
                }
                if ($matched) {
                    $out = Join-Path $dir "$($t.dest).jpg"
                    if (Save-Image $e.node.image.large $out) {
                        Write-Host ("  OK {0}/{1} <- {2}" -f $r.ws, $t.dest, $e.node.name.full) -ForegroundColor Green
                        $left = $left | Where-Object { $_.dest -ne $t.dest }
                    }
                    break
                }
            }
        }
        Start-Sleep -Milliseconds 800
    }
    foreach ($t in $left) {
        Write-Host "  PENDENTE $($r.ws)/$($t.dest) (usa fallback avatar)" -ForegroundColor Yellow
    }
}
