# Meigenly image fetcher: AniList GraphQL -> covers/ + characters/
#
# Uso:
#   powershell -File tools\download_images.ps1                 # tudo
#   powershell -File tools\download_images.ps1 -CoversOnly     # so capas
#   powershell -File tools\download_images.ps1 -CharsOnly      # so personagens
#   powershell -File tools\download_images.ps1 -Force           # re-baixa existentes (fix capas)
#
# Idempotente: pula arquivos ja existentes (a menos de -Force).
# Rate limit AniList: 90 req/min -> 429 = pausa 30s e repete (max 3x).

param(
    [switch]$CoversOnly,
    [switch]$CharsOnly,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$root = "$PSScriptRoot\.."
$assets = "$root\app\src\main\assets"
$coversDir = "$assets\covers"
$charsRoot = "$assets\characters"
$seedPath = "$assets\seed\app_data.json"
New-Item -ItemType Directory -Force -Path $coversDir | Out-Null
New-Item -ItemType Directory -Force -Path $charsRoot | Out-Null

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Invoke-GraphQL([string]$query, [hashtable]$variables) {
    $body = @{ query = $query; variables = $variables } |
        ConvertTo-Json -Depth 6 -Compress
    $attempts = 0
    while ($true) {
        $attempts++
        try {
            return Invoke-RestMethod -Uri 'https://graphql.anilist.co' `
                -Method Post `
                -ContentType 'application/json' `
                -Headers @{ Accept = 'application/json' } `
                -Body ([System.Text.Encoding]::UTF8.GetBytes($body))
        } catch {
            $status = $null
            if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
            if ($status -eq 429 -and $attempts -le 3) {
                Write-Host "  429 rate limit; aguardando 30s (tentativa $attempts/3)..." -ForegroundColor Yellow
                Start-Sleep -Seconds 30
                continue
            }
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
    $folded = $folded -replace 'ou', 'o'   # Kishou -> Kisho
    $folded = $folded -replace '(\w)\1', '$1'  # Oozora -> Ozora
    return $folded
}

function Save-Image([string]$url, [string]$destPath) {
    if ([string]::IsNullOrWhiteSpace($url)) { return $false }
    try {
        $resp = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 60
        # -UseBasicParsing: Content e byte[] puro em PS 5.1 (sem corromper binario)
        [System.IO.File]::WriteAllBytes($destPath, [byte[]]$resp.Content)
    } catch {
        Write-Host "    download falhou: $url" -ForegroundColor Yellow
        return $false
    }
    return $true
}

function Test-Image([string]$path) { return (Test-Path $path) }

function Get-Media([string]$search, [string]$type) {
    $q = @'
query ($search: String, $type: MediaType) {
  Media(search: $search, type: $type, sort: SEARCH_MATCH) {
    id
    format
    startDate { year }
    title { english romaji native }
    coverImage { extraLarge }
    characters(perPage: 50, sort: [ROLE]) {
      edges { node { name { full } image { large } } }
    }
  }
}
'@
    $res = Invoke-GraphQL $q @{ search = $search; type = $type }
    if ($null -ne $res -and $null -ne $res.data.Media) { return $res.data.Media }
    return $null
}

function Get-CharacterBySearch([string]$search) {
    $q = @'
query ($search: String) {
  Character(search: $search) {
    name { full }
    image { large }
  }
}
'@
    $res = Invoke-GraphQL $q @{ search = $search }
    if ($null -ne $res -and $null -ne $res.data.Character) { return $res.data.Character }
    return $null
}

# ---------------------------------------------------------------------------
# Dados
# ---------------------------------------------------------------------------

# (slug, termo de busca AniList, tipo, verificação obrigatória da capa)
$workQueries = @(
    # --- correcoes de capa ---
    @{ slug='magi';                     search='Magi: The Labyrinth of Magic'; type='ANIME'; must='Labyrinth of Magic' },
    @{ slug='nanatsu-no-taizai';        search='The Seven Deadly Sins';        type='ANIME'; must='Seven Deadly Sins' },
    @{ slug='vagabond';                 search='Vagabond';                     type='MANGA'; must='Vagabond'; mangaka='Takehiko Inoue' },
    # --- novas obras do lote ---
    @{ slug='angel-beats';              search='Angel Beats!';                 type='ANIME'; must='Angel Beats' },
    @{ slug='ao-no-exorcist';           search='Blue Exorcist';                type='ANIME'; must='Exorcist' },
    @{ slug='baki';                     search='Baki';                         type='ANIME'; must='Baki' },
    @{ slug='blue-lock';                search='Blue Lock';                    type='ANIME'; must='Blue Lock' },
    @{ slug='blue-period';              search='Blue Period';                  type='ANIME'; must='Blue Period' },
    @{ slug='boku-no-hero-academia';    search='My Hero Academia';             type='ANIME'; must='Hero Academia' },
    @{ slug='captain-tsubasa';          search='Captain Tsubasa';              type='ANIME'; must='Tsubasa' },
    @{ slug='centuria';                 search='Centuria';                     type='MANGA'; must='Centuria' },
    @{ slug='chainsaw-man';             search='Chainsaw Man';                 type='ANIME'; must='Chainsaw Man' },
    @{ slug='clannad-after-story';      search='Clannad: After Story';         type='ANIME'; must='After Story' },
    @{ slug='daemons-of-the-shadow-realm'; search='Daemons of the Shadow Realm'; type='MANGA'; must='Shadow Realm' },
    @{ slug='dandadan';                 search='Dandadan';                     type='ANIME'; must='Dandadan' },
    @{ slug='dr-stone';                 search='Dr. Stone';                    type='ANIME'; must='Stone' },
    @{ slug='fairy-tail';               search='Fairy Tail';                   type='ANIME'; must='Fairy Tail' },
    @{ slug='fire-force';               search='Fire Force';                   type='ANIME'; must='Fire Force' },
    @{ slug='gintama';                  search='Gintama';                      type='ANIME'; must='Gintama' },
    @{ slug='girls-last-tour';          search='Girls Last Tour';              type='ANIME'; must='Shuumatsu' },
    @{ slug='haikyu';                   search='Haikyu!!';                     type='ANIME'; must='Haikyuu' },
    @{ slug='jojos-bizarre-adventure';  search='JoJo Bizarre Adventure';       type='ANIME'; must='Jojo' },
    @{ slug='kagurabachi';              search='Kagurabachi';                  type='MANGA'; must='Kagurabachi' },
    @{ slug='mairimashita-iruma-kun';   search='Welcome to Demon School Iruma-kun'; type='ANIME'; must='Iruma-kun' },
    @{ slug='mieruko-chan';             search='Mieruko-chan';                 type='ANIME'; must='Mieruko' },
    @{ slug='omori';                    search='OMORI';                        type='ANIME'; must=$null },
    @{ slug='one-punch-man';            search='One-Punch Man';                type='ANIME'; must='One Punch Man' },
    @{ slug='run-with-the-wind';        search='Run with the Wind';            type='ANIME'; must='Fuiteiru' },
    @{ slug='servamp';                  search='Servamp';                      type='ANIME'; must='Servamp' },
    @{ slug='solo-leveling';            search='Solo Leveling';                type='ANIME'; must='Ore dake Level Up' },
    @{ slug='soul-eater';               search='Soul Eater';                   type='ANIME'; must='Soul Eater' },
    @{ slug='spy-x-family';             search='Spy x Family';                 type='ANIME'; must='Spy' },
    @{ slug='gurren-lagann';            search='Gurren Lagann';                type='ANIME'; must='Gurren Lagann' },
    @{ slug='the-summer-hikaru-died';   search='The Summer Hikaru Died';       type='MANGA'; must='Hikaru' },
    @{ slug='tokyo-ghoul-re';           search='Tokyo Ghoul re';               type='MANGA'; must=$null },
    @{ slug='toilet-bound-hanako-kun';  search='Toilet-Bound Hanako-kun';      type='ANIME'; must='Hanako-kun' },
    @{ slug='witch-hat-atelier';        search='Witch Hat Atelier';            type='MANGA'; must='Atelier' },
    @{ slug='xxxholic';                 search='xxxHOLiC';                     type='ANIME'; must='HOLiC' },
    @{ slug='xxxholic-rei';             search='xxxHOLiC Rei';                 type='MANGA'; must='HOLiC' },
    @{ slug='yu-yu-hakusho';            search='Yu Yu Hakusho';                type='ANIME'; must='Hakusho' },
    # --- covers dos lotes 3/4 (v0.9.3) ---
    @{ slug='another';                  search='Another';                      type='ANIME'; must='Another' },
    @{ slug='astro-boy';                search='Astro Boy';                    type='ANIME'; must='Astro' },
    @{ slug='black-clover';             search='Black Clover';                 type='ANIME'; must='Black Clover' },
    @{ slug='black-torch';              search='Black Torch';                  type='MANGA'; must='Black Torch' },
    @{ slug='bungou-stray-dogs';        search='Bungou Stray Dogs';            type='ANIME'; must='Stray Dogs' },
    @{ slug='chained-soldier';          search='Chained Soldier';              type='ANIME'; must='Mato Seihei' },
    @{ slug='digimon-adventure';        search='Digimon Adventure';            type='ANIME'; must='Digimon' },
    @{ slug='dorohedoro';               search='Dorohedoro';                   type='ANIME'; must='Dorohedoro' },
    @{ slug='dusk-maiden';              search='Dusk Maiden of Amnesia';       type='ANIME'; must='Tasogare' },
    @{ slug='elfen-lied';               search='Elfen Lied';                   type='ANIME'; must='Elfen' },
    @{ slug='erased';                   search='Erased';                       type='ANIME'; must='Inai Machi' },
    @{ slug='fate-stay-night';          search='Fate stay night Unlimited Blade Works'; type='ANIME'; must='Blade Works' },
    @{ slug='fruits-basket';            search='Fruits Basket';                type='ANIME'; must='Fruits Basket' },
    @{ slug='gosick';                   search='GOSICK';                       type='ANIME'; must='GOSICK' },
    @{ slug='hells-paradise';           search='Hell''s Paradise';             type='ANIME'; must='Jigokuraku' },
    @{ slug='innocent';                 search='Innocent';                     type='MANGA'; must='Innocent' },
    @{ slug='inuyasha';                 search='InuYasha';                     type='ANIME'; must='InuYasha' },
    @{ slug='jigoku-shoujo';            search='Hell Girl';                    type='ANIME'; must='Jigoku' },
    @{ slug='kamisama-kiss';            search='Kamisama Kiss';                type='ANIME'; must='Kamisama' },
    @{ slug='kekkai-sensen';            search='Blood Blockade Battlefront';   type='ANIME'; must='Blood Blockade' },
    @{ slug='kengan-ashura';            search='Kengan Ashura';                type='ANIME'; must='Kengan' },
    @{ slug='lili-men';                 search='Lili-Men';                     type='MANGA'; must='Lili' },
    @{ slug='love-bullet';              search='Love Bullet';                  type='MANGA'; must=$null },
    @{ slug='mashle';                   search='Mashle';                       type='ANIME'; must='Mashle' },
    @{ slug='medalist';                 search='Medalist';                     type='ANIME'; must='Medalist' },
    @{ slug='mermaid-saga';             search='Mermaid''s Forest';            type='MANGA'; must='Mermaid' },
    @{ slug='mission-yozakura-family';  search='Mission: Yozakura Family';     type='ANIME'; must='Yozakura' },
    @{ slug='natsume-yuujinchou';       search='Natsume''s Book of Friends';   type='ANIME'; must='Natsume' },
    @{ slug='nue-no-onmyouji';          search='Nue''s Exorcist';              type='MANGA'; must='Nue' },
    @{ slug='orange';                   search='Orange';                       type='ANIME'; must='Orange' },
    @{ slug='pokemon';                  search='Pokemon';                      type='ANIME'; must='Pocket' },
    @{ slug='ragna-crimson';            search='Ragna Crimson';                type='ANIME'; must='Ragna' },
    @{ slug='record-of-ragnarok';       search='Record of Ragnarok';           type='ANIME'; must='Valkyrie' },
    @{ slug='relife';                   search='ReLIFE';                       type='ANIME'; must='ReLIFE' },
    @{ slug='rg-veda';                  search='RG Veda';                      type='ANIME'; must='RG Veda' },
    @{ slug='ruridragon';               search='Ruri Dragon';                  type='MANGA'; must='Ruri' },
    @{ slug='sakamoto-days';            search='Sakamoto Days';                type='ANIME'; must='Sakamoto' },
    @{ slug='tenmaku-no-jaadugar';      search='Tenmaku no Jaadugar';          type='MANGA'; must='Jaadugar' },
    @{ slug='the-promised-neverland';   search='The Promised Neverland';       type='ANIME'; must='Neverland' },
    @{ slug='ultimate-exorcist-kiyoshi'; search='Ultimate Exorcist Kiyoshi';   type='MANGA'; must='Kiyoshi' },
    @{ slug='undead-unluck';            search='Undead Unluck';                type='ANIME'; must='Undead' },
    @{ slug='vampire-hunter-d';         search='Vampire Hunter D';             type='ANIME'; must='Vampire' },
    @{ slug='wind-breaker';             search='Wind Breaker';                 type='ANIME'; must='Wind Breaker' },
    @{ slug='youjo-senki';              search='The Saga of Tanya the Evil';   type='ANIME'; must='Tanya' },
    @{ slug='zatch-bell';               search='Zatch Bell';                   type='ANIME'; must='Gash' }
)

# ---------------------------------------------------------------------------
# PARTE 1: capas
# ---------------------------------------------------------------------------

if (-not $CharsOnly) {
    Write-Host '=== COVERS ===' -ForegroundColor Cyan
    $failCovers = @()
    foreach ($w in $workQueries) {
        $out = Join-Path $coversDir "$($w.slug).jpg"
        if ((Test-Image $out) -and -not $Force) { continue }
        $media = Get-Media $w.search $w.type
        if ($null -eq $media) {
            $media = Get-Media $w.search ($(if ($w.type -eq 'ANIME') { 'MANGA' } else { 'ANIME' }))
        }
        if ($null -eq $media) {
            Write-Host "  $($w.slug): midia nao encontrada" -ForegroundColor Yellow
            $failCovers += $w.slug
            Start-Sleep -Milliseconds 700
            continue
        }
        $title = $media.title.english; if (-not $title) { $title = $media.title.romaji }
        # verificacao de titulo
        $matched = $true
        if ($w.must) { $matched = (($title -match $w.must) -or ($media.title.romaji -match $w.must) -or ($media.title.native -match $w.must)) }
        if ($w.mangaka) {
            # Vagabond: confere o autor também
            $q = 'query ($id: Int) { Media(id: $id) { staff { edges { node { name { full } } } } } }'
            $staffRes = Invoke-GraphQL $q @{ id = $media.id }
            $names = if ($staffRes) { ($staffRes.data.Media.staff.edges | ForEach-Object { $_.node.name.full }) -join ' ' } else { '' }
            if ($names -notmatch $w.mangaka) { $matched = $false }
        }
        if (-not $matched) {
            Write-Host "  $($w.slug): titulo inconsistente [$title]; SKIP" -ForegroundColor Yellow
            $failCovers += $w.slug
            Start-Sleep -Milliseconds 700
            continue
        }
        $ok = Save-Image $media.coverImage.extraLarge $out
        if ($ok) {
            Write-Host ("  {0,-30} <- {1} ({2}) {3:N0} KB" -f $w.slug, $title, $media.format, ((Get-Item $out).Length/1KB))
        } else {
            $failCovers += $w.slug
        }
        Start-Sleep -Milliseconds 700
    }
    if ($failCovers.Count -gt 0) {
        Write-Host "Cobertura pendente: $($failCovers -join ', ')" -ForegroundColor Yellow
    }
}

# ---------------------------------------------------------------------------
# PARTE 2: personagens
# ---------------------------------------------------------------------------

if (-not $CoversOnly) {
    Write-Host '=== CHARACTERS ===' -ForegroundColor Cyan
    $seed = Get-Content $seedPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $workBySlug = @{}
    foreach ($w in $workQueries) { $workBySlug[$w.slug] = $w }

    $totalSaved = 0
    $totalMiss = 0
    foreach ($work in $seed.works) {
        $wq = $workBySlug[$work.slug]
        if ($null -eq $wq) { continue }   # obras antigas fora deste lote
        $dir = Join-Path $charsRoot $work.slug
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        $media = Get-Media $wq.search $wq.type
        if ($null -eq $media) {
            $media = Get-Media $wq.search ($(if ($wq.type -eq 'ANIME') { 'MANGA' } else { 'ANIME' }))
        }
        if ($null -eq $media -or $null -eq $media.characters.edges) {
            Write-Host "  $($work.slug): sem midia/chars; fallback por nome" -ForegroundColor Yellow
            $media = $null
        } else {
            Start-Sleep -Milliseconds 700
        }

        $byNorm = @{}
        if ($media) {
            foreach ($e in $media.characters.edges) {
                $n = NormName $e.node.name.full
                if ($n -ne '' -and -not $byNorm.ContainsKey($n)) { $byNorm[$n] = $e.node.image.large }
            }
        }

        foreach ($c in $work.characters) {
            $out = Join-Path $dir "$($c.slug).jpg"
            if ((Test-Image $out) -and -not $Force) { continue }
            $key = NormName $c.name
            $url = $null
            $route = ''
            if ($byNorm.ContainsKey($key)) {
                $url = $byNorm[$key]; $route = 'media'
            } else {
                # tenta casar removendo o sobrenome (nomes de rota/apelido)
                $firstWord = ($key -split '-')[0]
                $hit = $byNorm.Keys | Where-Object { $_ -eq $firstWord -or $_.StartsWith($key) -or $key.StartsWith($_) }
                if ($hit) { $url = $byNorm[$hit[0]]; $route = 'fuzzy-media' }
                else {
                    $ch = Get-CharacterBySearch $c.name
                    if ($ch) {
                        $cn = NormName $ch.name.full
                        if ($cn -eq $key) { $url = $ch.image.large; $route = 'search' }
                        else {
                            Write-Host "    $($work.slug)/$($c.name): busca devolveu [$($ch.name.full)] - SKIP (evita pessoa errada)" -ForegroundColor Yellow
                            Start-Sleep -Milliseconds 700
                            continue
                        }
                    }
                    Start-Sleep -Milliseconds 700
                }
            }
            if ($null -ne $url -and (Save-Image $url $out)) {
                $totalSaved++
                Write-Host "    $route $($work.slug)/$($c.slug)" -ForegroundColor DarkGray
            } else {
                $totalMiss++
                Write-Host "    ))) SEM IMAGEM $($work.slug)/$($c.slug) (usa fallback)" -ForegroundColor Yellow
            }
        }
    }
    Write-Host "chars salvos: $totalSaved | sem imagem: $totalMiss" -ForegroundColor Green
}
