# Meigenly: conserto final dos stragglers com cs/target overrides + scans de obra.
# Requisitos por linha: cs (busca), dest, tokens esperados, kw da obra (quando filtro de media).
# Para DBGT Baby usa o scan de Media.characters (Busca por Character 'Baby' nao traz DBGT).
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

function NormTokens([string]$name) {
    if ($null -eq $name) { return @() }
    return ($name -split '\s+') | ForEach-Object {
        ($_.Normalize([System.Text.NormalizationForm]::FormD) -replace '[^a-zA-Z0-9]', '').ToLowerInvariant()
    } | Where-Object { $_.Length -ge 3 }
}

function Save-Image([string]$url, [string]$destPath) {
    if ([string]::IsNullOrWhiteSpace($url)) { return $false }
    try {
        $resp = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 60
        [System.IO.File]::WriteAllBytes($destPath, [byte[]]$resp.Content)
    } catch { return $false }
    return $true
}

# Query individual com filtro de media por keyword
$charQ = @'
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

# rows: key, cs, tokens (nomes de match permitidos), kw (regex media)
$rows = @(
  @{ key='berserk/cavaleiro-caveira';        cs='The Skull Knight';      tokens=@('skull','knight');          kw='Berserk' }
  @{ key='bleach/kukaku-shiba';              cs='Kuukaku Shiba';         tokens=@('kuukaku','shiba','kukaku'); kw='Bleach' }
  @{ key='bleach/hanataro-yamada';           cs='Hanatarou Yamada';      tokens=@('hanatarou','hanataro');    kw='Bleach' }
  @{ key='bleach/szayelaporro';              cs='Szayel Aporro Grantz';  tokens=@('szayel','aporro','grantz'); kw='Bleach' }
  @{ key='bleach/shuhei-hisagi';             cs='Shuuhei Hisagi';        tokens=@('shuuhei','hisagi','shuhei'); kw='Bleach' }
  @{ key='bleach/kugo-ginjo';                cs='Kugo Ginjou';           tokens=@('kugo','ginjou','ginjo');   kw='Bleach' }
  @{ key='bleach/ichibei-hyosube';           cs='Ichibei Hyousube';      tokens=@('ichibei','hyousube');      kw='Bleach' }
  @{ key='dgray-man/conde-do-milenio';       cs='Sennen Hakushaku';      tokens=@('sennen','hakushaku');      kw='D.DGray|D.Gray|D Gray' }
  @{ key='one-piece/dr-hiriluk';             cs='Hiluluk';               tokens=@('hiluluk');                 kw='ONE PIECE|One Piece' }
  @{ key='one-piece/barba-branca';           cs='Newgate Edward';        tokens=@('newgate','edward');        kw='ONE PIECE|One Piece' }
  @{ key='kingdom/shin';                     cs='Xin Li';                tokens=@('xin','li');                kw='Kingdom' }
  @{ key='kingdom/ei-sei';                   cs='Zheng Ying';            tokens=@('zheng','ying');            kw='Kingdom' }
  @{ key='kingdom/duke-hyou';                cs='Biao Gong';             tokens=@('biao','gong');             kw='Kingdom' }
  @{ key='kingdom/kanki';                    cs='Kan Ki';                tokens=@('kanki','ki');              kw='Kingdom' }
  @{ key='dragon-ball-gt/gogeta';            cs='Gogeta';                tokens=@('gogeta');                  kw='Dragon Ball' }
  @{ key='dragon-ball-gt/baby';              cs='Baby';                  tokens=@('baby');                    kw='Dragon Ball GT' }
)

foreach ($r in $rows) {
    $parts = $r.key -split '/'
    $out = Join-Path (Join-Path $charsRoot $parts[0]) "$($parts[1]).jpg"
    if (Test-Path $out) { Write-Host "  ja-tem $($r.key)"; continue }
    $res = Invoke-GraphQL $charQ @{ search = $r.cs }
    $picked = $null
    if ($res -and $res.data.Page.characters) {
        foreach ($cand in $res.data.Page.characters) {
            $titles = $cand.media.nodes | ForEach-Object { "$($_.title.english) $($_.title.romaji) $($_.title.native)" }
            $inWork = $titles | Where-Object { $_ -match $r.kw }
            if (-not $inWork) { continue }
            $ct = @(NormTokens $cand.name.full)
            if ($r.tokens | Where-Object { $ct -contains $_ }) { $picked = $cand; break }
        }
    }
    if ($picked) {
        if (Save-Image $picked.image.large $out) {
            Write-Host "  OK $($r.key) <- $($picked.name.full)"
        } else {
            Write-Host "  PENDENTE $($r.key) (download falhou)"
        }
    } else {
        Write-Host "  PENDENTE $($r.key) (sem match)"
    }
    Start-Sleep -Milliseconds 800
}

# DBGT Baby via scan de Media.characters (pagina 2)
$mq = @'
query ($search: String, $fmtIn: [MediaFormat], $page: Int) {
  Media(search: $search, type: ANIME, format_in: $fmtIn) {
    characters(page: $page, perPage: 50, sort: [ROLE]) {
      edges { node { name { full } image { large } } }
    }
  }
}
'@
$out = Join-Path $charsRoot "dragon-ball-gt\baby.jpg"
if (-not (Test-Path $out)) {
    foreach ($page in 1, 2) {
        $res = Invoke-GraphQL $mq @{ search = 'Dragon Ball GT'; fmtIn = @('TV'); page = $page }
        $e = $res.data.Media.characters.edges | Where-Object { $_.node.name.full -eq 'Baby' } | Select-Object -First 1
        if ($e) {
            if (Save-Image $e.node.image.large $out) { Write-Host "  OK dragon-ball-gt/baby <- scan pag$page" }
            break
        }
        Start-Sleep -Milliseconds 800
    }
}
