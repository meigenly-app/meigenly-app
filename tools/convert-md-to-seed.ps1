# Meigenly seed converter: coletanea .md -> assets/seed/app_data.json
#
# Reproduz o seed v2 a partir do arquivo markdown enviado pelo autor.
# Uso:
#   powershell -File tools\convert-md-to-seed.ps1 -MdPath <caminho-do-.md>
#
# Regras aplicadas (decisoes autorais):
#   - Seed = conteudo integral do .md (substitui tudo).
#   - Bleach completo: dialogos + poemas de volume (poema vira frase com
#     episode "Poema do Vol. N" e contexto "Poema de abertura do volume N do manga.").
#   - textOriginal = romaji; textJapanese = kanji da coluna "Original (JP)".
#   - Episode com "nao confirmado" -> normalizado + review:true (flag authoring,
#     ignorada pelo parser Kotlin).
#   - Variantes de personagem agrupadas (mapa $Renames abaixo).
#   - nameOriginal preenchido apenas para nomes ja validados no seed v1.

param(
    # Por padrao, processa todos os .md em tools/source/ (ordem alfabetica).
    # Secao duplicada entre arquivos = erro: substitua o arquivo antigo na pasta.
    [string[]]$MdPaths = @(),
    [string]$OutPath = "$PSScriptRoot\..\app\src\main\assets\seed\app_data.json"
)

$ErrorActionPreference = 'Stop'

if (($MdPaths.Count -eq 0)) {
    $MdPaths = @(Get-ChildItem "$PSScriptRoot\source\*.md" -File | Sort-Object Name | ForEach-Object { $_.FullName })
}
if ($MdPaths.Count -eq 0) { throw "Nenhum .md encontrado em tools/source/" }

# ---------------------------------------------------------------------------
# Metadados autorais das obras (chave = titulo exato da secao no .md)
# ---------------------------------------------------------------------------
$WorksMeta = [ordered]@{
    'Berserk'                                                                    = @{ slug='berserk'; title='Berserk'; titleOriginal='ベルセルク'; year=1997; accentColor='#A93226'; description='A jornada sombria de Guts, o espadachim marcado, contra um destino cruel.' }
    'Bleach'                                                                     = @{ slug='bleach'; title='Bleach'; titleOriginal=$null; year=2004; accentColor='#FF9F1C'; description='Ichigo Kurosaki herda o poder de uma Shinigami e protege vivos e espíritos.' }
    'Cavaleiros do Zodíaco (Saint Seiya)'                                        = @{ slug='saint-seiya'; title='Cavaleiros do Zodíaco'; titleOriginal='聖闘士星矢'; year=1986; accentColor='#5C6BC0'; description='Jovens cavaleiros protegem Athena queimando seus Cosmos na batalha.' }
    'Clannad'                                                                    = @{ slug='clannad'; title='Clannad'; titleOriginal=$null; year=2007; accentColor='#7CB342'; description='Tomoya encontra família, amizade e redenção no clube de teatro.' }
    'Claymore'                                                                   = @{ slug='claymore'; title='Claymore'; titleOriginal='クレイモア'; year=2007; accentColor='#78909C'; description='Guerreiras meio-demônio caçam Yomas num mundo medieval sombrio.' }
    'Code Geass'                                                                 = @{ slug='code-geass'; title='Code Geass'; titleOriginal='コードギアス 反逆のルルーシュ'; year=2006; accentColor='#8E24AA'; description='Lelouch ganha o poder da obediência absoluta e declara guerra ao império.' }
    'Cowboy Bebop'                                                               = @{ slug='cowboy-bebop'; title='Cowboy Bebop'; titleOriginal='カウボーイビバップ'; year=1998; accentColor='#26A69A'; description='Caçadores de recompensas vagam pelo espaço ao som de jazz.' }
    'D.Gray-man'                                                                 = @{ slug='dgray-man'; title='D.Gray-man'; titleOriginal=$null; year=2006; accentColor='#6D4C41'; description='Exorcistas combatem o Conde do Milênio e seu exército de akumas.' }
    'Dororo'                                                                     = @{ slug='dororo'; title='Dororo'; titleOriginal='どろろ'; year=2019; accentColor='#8D6E63'; description='Um samurai sem corpo caça demônios para recuperar o que lhe roubaram.' }
    'Dragon Ball GT'                                                             = @{ slug='dragon-ball-gt'; title='Dragon Ball GT'; titleOriginal='ドラゴンボールGT'; year=1996; accentColor='#FF7043'; description='Goku, de volta à infância, parte pelo universo atrás das Esferas do Dragão.' }
    'Dragon Ball Z'                                                              = @{ slug='dragon-ball-z'; title='Dragon Ball Z'; titleOriginal='ドラゴンボールZ'; year=1989; accentColor='#F4B400'; description='Goku e os guerreiros Z defendem a Terra de inimigos cada vez mais fortes.' }
    'Ergo Proxy'                                                                 = @{ slug='ergo-proxy'; title='Ergo Proxy'; titleOriginal='エルゴプラクシー'; year=2006; accentColor='#546E7A'; description='Numa cidade-cúpula perfeita, uma inspetora desenterra a verdade sobre os Proxies.' }
    'Fullmetal Alchemist'                                                        = @{ slug='fullmetal-alchemist'; title='Fullmetal Alchemist: Brotherhood'; titleOriginal='鋼の錬金術師'; year=2009; accentColor='#D84315'; description='Dois irmãos pagam o preço da alquimia proibida e buscam a Pedra Filosofal.' }
    'Gachiakuta'                                                                 = @{ slug='gachiakuta'; title='Gachiakuta'; titleOriginal='ガチアクタ'; year=2025; accentColor='#00897B'; description='Jogado num abismo de lixo, Rudo sobe para punir quem descarta pessoas.' }
    'Gantz'                                                                      = @{ slug='gantz'; title='Gantz'; titleOriginal='ガンツ'; year=2004; accentColor='#37474F'; description='Mortos ressuscitam num jogo brutal comandado por uma esfera negra.' }
    'Hajime no Ippo'                                                             = @{ slug='hajime-no-ippo'; title='Hajime no Ippo'; titleOriginal='はじめの一歩'; year=2000; accentColor='#EF6C00'; description='Um tímido descobre no boxe a força para mudar a própria vida.' }
    'Hunter x Hunter'                                                            = @{ slug='hunter-x-hunter'; title='Hunter x Hunter'; titleOriginal=$null; year=2011; accentColor='#2E7D32'; description='Gon vira Hunter para encontrar o pai e encontra amigos e perigos.' }
    'Ichi the Witch (Madan no Ichi)'                                             = @{ slug='ichi-the-witch'; title='Ichi the Witch'; titleOriginal='魔男のイチ'; year=2025; accentColor='#AB47BC'; description='Um caçador de monstros sem magia se torna o primeiro bruxo homem.' }
    'Jujutsu Kaisen'                                                             = @{ slug='jujutsu-kaisen'; title='Jujutsu Kaisen'; titleOriginal='呪術廻戦'; year=2020; accentColor='#1E88E5'; description='Yuji engole um dedo amaldiçoado e entra no mundo sombrio dos feitiços.' }
    'Kimetsu no Yaiba'                                                           = @{ slug='kimetsu-no-yaiba'; title='Kimetsu no Yaiba'; titleOriginal='鬼滅の刃'; year=2019; accentColor='#00695C'; description='Tanjiro caça demônios para curar a irmã transformada em oni.' }
    'Kingdom'                                                                    = @{ slug='kingdom'; title='Kingdom'; titleOriginal='キングダム'; year=2012; accentColor='#A1887F'; description='Na China antiga, um servo e um rei caminham juntos rumo à unificação.' }
    'Kuroko no Basket'                                                           = @{ slug='kuroko-no-basket'; title='Kuroko no Basket'; titleOriginal='黒子のバスケ'; year=2012; accentColor='#0288D1'; description='A sombra e a luz buscam derrotar a lendária Geração dos Milagres.' }
    'Magi: The Labyrinth of Magic'                                               = @{ slug='magi'; title='Magi'; titleOriginal='マギ'; year=2012; accentColor='#F9A825'; description='Aladdin e Alibaba exploram masmorras mágicas e forjam destinos reais.' }
    'Mob Psycho 100'                                                             = @{ slug='mob-psycho-100'; title='Mob Psycho 100'; titleOriginal='モブサイコ100'; year=2016; accentColor='#C0CA33'; description='Um psíquico tímido aprende que poder não define uma pessoa.' }
    'Nanatsu no Taizai'                                                          = @{ slug='nanatsu-no-taizai'; title='Nanatsu no Taizai'; titleOriginal='七つの大罪'; year=2014; accentColor='#C2185B'; description='Sete cavaleiros infames se reúnem para salvar o reino que os condenou.' }
    'Naruto'                                                                     = @{ slug='naruto'; title='Naruto'; titleOriginal='NARUTO -ナルト-'; year=2002; accentColor='#FF8A00'; description='A história do ninja rebelde Naruto Uzumaki, que sonha em se tornar Hokage.' }
    'Naruto Shippuden'                                                           = @{ slug='naruto-shippuden'; title='Naruto Shippuden'; titleOriginal='NARUTO -ナルト- 疾風伝'; year=2007; accentColor='#E65100'; description='Naruto retorna mais forte; a Akatsuki caça os Jinchuriki.' }
    'Neon Genesis Evangelion'                                                    = @{ slug='neon-genesis-evangelion'; title='Neon Genesis Evangelion'; titleOriginal='新世紀エヴァンゲリオン'; year=1995; accentColor='#6A1B9A'; description='Adolescentes pilotam unidades EVA contra os Anjos — e contra si mesmos.' }
    'One Piece'                                                                  = @{ slug='one-piece'; title='One Piece'; titleOriginal='ワンピース'; year=1999; accentColor='#D6453D'; description='A jornada de Monkey D. Luffy rumo ao título de Rei dos Piratas.' }
    'Re:Zero kara Hajimeru Isekai Seikatsu'                                      = @{ slug='rezero'; title='Re:Zero'; titleOriginal='Re:ゼロから始める異世界生活'; year=2016; accentColor='#7B1FA2'; description='Subaru revive a cada morte e recomeça do zero para salvar quem ama.' }
    'Serial Experiments Lain'                                                    = @{ slug='serial-experiments-lain'; title='Serial Experiments Lain'; titleOriginal='シリアルエクスペリメンツレイン'; year=1998; accentColor='#00838F'; description='Uma menina silenciosa mergulha na rede global chamada Wired.' }
    'Shingeki no Kyojin'                                                         = @{ slug='shingeki-no-kyojin'; title='Shingeki no Kyojin'; titleOriginal='進撃の巨人'; year=2013; accentColor='#616161'; description='A humanidade luta por trás de muros contra gigantes devoradores.' }
    'The Apothecary Diaries (Kusuriya no Hitorigoto)'                            = @{ slug='apothecary-diaries'; title='The Apothecary Diaries'; titleOriginal='薬屋のひとりごと'; year=2023; accentColor='#7E57C2'; description='Uma farmacêutica resolve mistérios no palácio imperial chinês.' }
    'Tokyo Ghoul'                                                                = @{ slug='tokyo-ghoul'; title='Tokyo Ghoul'; titleOriginal='東京喰種'; year=2014; accentColor='#C62828'; description='Um estudante vira meio-ghoul e aprende o peso dos dois mundos.' }
    'Tokyo Revengers'                                                            = @{ slug='tokyo-revengers'; title='Tokyo Revengers'; titleOriginal='東京リベンジャーズ'; year=2021; accentColor='#D81B60'; description='Takemichi volta 12 anos no tempo para salvar seu primeiro amor.' }
    'Toriko'                                                                     = @{ slug='toriko'; title='Toriko'; titleOriginal='トリコ'; year=2011; accentColor='#F4511E'; description='Caçadores gourmet buscam os ingredientes mais raros e deliciosos.' }
    'Vagabond'                                                                   = @{ slug='vagabond'; title='Vagabond'; titleOriginal='バガボンド'; year=1998; accentColor='#4E342E'; description='A vida de Miyamoto Musashi na busca da espada perfeita.' }
    'Vinland Saga'                                                               = @{ slug='vinland-saga'; title='Vinland Saga'; titleOriginal='ヴィンランド・サガ'; year=2019; accentColor='#33691E'; description='Thorfinn cresce entre vikings, entre vingança e a promessa de terra sem guerra.' }
    'Youkoso Jitsuryoku Shijou Shugi no Kyoushitsu e (Classroom of the Elite)'   = @{ slug='classroom-of-the-elite'; title='Classroom of the Elite'; titleOriginal='ようこそ実力至上主義の教室へ'; year=2017; accentColor='#3949AB'; description='Na escola de elite, só resultados importam — e Ayanokoji joga em outro nível.' }
    'Sousou no Frieren'                                                          = @{ slug='sousou-no-frieren'; title='Sousou no Frieren'; titleOriginal='葬送のフリーレン'; year=2023; accentColor='#5DADE2'; description='A maga elfa Frieren viaja para entender o valor do tempo humano.' }
    # ---- Coletânea "nova seleção" (seed v4) --------------------------------
    'Angel Beats!'                                                               = @{ slug='angel-beats'; title='Angel Beats!'; titleOriginal='エンジェルビーツ!'; year=2010; accentColor='#F06292'; description='Numa escola pós-morte, estudantes se rebelam contra Deus para honrar os sonhos que lhes foram tomados.' }
    'Ao no Exorcist (Blue Exorcist)'                                             = @{ slug='ao-no-exorcist'; title='Blue Exorcist'; titleOriginal='青の祓魔師'; year=2011; accentColor='#3F51B5'; description='Rin, filho de Satanás, entra para a ordem dos exorcistas para enfrentá-lo.' }
    'Baki the Grappler / Baki'                                                   = @{ slug='baki'; title='Baki'; titleOriginal='バキ'; year=2017; accentColor='#B71C1C'; description='Lutadores extremos disputam o título de criatura mais forte da Terra.' }
    'Blue Lock'                                                                  = @{ slug='blue-lock'; title='Blue Lock'; titleOriginal='ブルーロック'; year=2022; accentColor='#1565C0'; description='301 atacantes disputam o futuro do futebol japonês num experimento impiedoso.' }
    'Blue Period'                                                                = @{ slug='blue-period'; title='Blue Period'; titleOriginal='ブルーピリオド'; year=2021; accentColor='#4527A0'; description='Um aluno nota dedicado descobre na arte uma forma de dizer o que não consegue falar.' }
    'Boku no Hero Academia (My Hero Academia)'                                   = @{ slug='boku-no-hero-academia'; title='My Hero Academia'; titleOriginal='僕のヒーローアカデミア'; year=2016; accentColor='#F57C00'; description='Num mundo de superpoderes, um garoto sem dons herda a chama do maior herói.' }
    'Captain Tsubasa'                                                            = @{ slug='captain-tsubasa'; title='Captain Tsubasa'; titleOriginal='キャプテン翼'; year=1983; accentColor='#1976D2'; description='Tsubasa e uma geração de craques rumo ao topo do futebol mundial.' }
    'Centuria'                                                                   = @{ slug='centuria'; title='Centuria'; titleOriginal='センチュリア'; year=2024; accentColor='#5D4037'; description='Um rapaz em dívida herda o poder de cem escravos — e uma vida nova entre mil forças.' }
    'Chainsaw Man'                                                               = @{ slug='chainsaw-man'; title='Chainsaw Man'; titleOriginal='チェンソーマン'; year=2022; accentColor='#C62828'; description='Um caçador endividado se funde com seu cachorro-motosserra e entra no mundo dos caçadores de demônios.' }
    'Clannad: After Story'                                                       = @{ slug='clannad-after-story'; title='Clannad: After Story'; titleOriginal=$null; year=2009; accentColor='#558B2F'; description='Terminada a escola, Tomoya e Nagisa começam a própria família — e aprendem o que é permanecer.' }
    'Daemons of the Shadow Realm (Yomi no Tsugai)'                               = @{ slug='daemons-of-the-shadow-realm'; title='Daemons of the Shadow Realm'; titleOriginal=$null; year=2024; accentColor='#263238'; description='Gêmeos e seus daemons lutam contra uma organização que persegue os guardiões do lado escuro.' }
    'Dandadan'                                                                   = @{ slug='dandadan'; title='Dandadan'; titleOriginal='ダンダダン'; year=2024; accentColor='#7B1FA2'; description='Uma garota espiritualista e um fanático por alienígenas unem os dois mundos mais estranhos da ficção.' }
    'Dr. Stone'                                                                  = @{ slug='dr-stone'; title='Dr. Stone'; titleOriginal='ドクターストーン'; year=2019; accentColor='#00ACC1'; description='Após a petrificação da humanidade, a ciência reconstrói a civilização do zero.' }
    'Fairy Tail'                                                                 = @{ slug='fairy-tail'; title='Fairy Tail'; titleOriginal='フェアリーテイル'; year=2009; accentColor='#0097A7'; description='A guilda mais barulhenta — e mais família — da magia protege os próprios laços.' }
    'Fire Force (Enen no Shouboutai)'                                            = @{ slug='fire-force'; title='Fire Force'; titleOriginal='炎炎ノ消防隊'; year=2019; accentColor='#E64A19'; description='Brigadeiros especiais combatem a combustão humana em Tóquio.' }
    'Gintama'                                                                    = @{ slug='gintama'; title='Gintama'; titleOriginal='銀魂'; year=2006; accentColor='#607D8B'; description='Um samurai que aceita qualquer trabalho numa Edo ocupada — e ri do próprio gênero.' }
    'Girls'' Last Tour (Shoujo Shuumatsu Ryokou)'                                = @{ slug='girls-last-tour'; title='Girls'' Last Tour'; titleOriginal='少女終末旅行'; year=2017; accentColor='#90A4AE'; description='Duas garotas atravessam as ruínas do fim do mundo, juntas e bem devagar.' }
    'Haikyu!!'                                                                   = @{ slug='haikyu'; title='Haikyu!!'; titleOriginal='ハイキュー!!'; year=2014; accentColor='#FF7043'; description='O menino baixinho do vôlei prova que altura não marca ponto — coragem marca.' }
    'JoJo''s Bizarre Adventure'                                                  = @{ slug='jojos-bizarre-adventure'; title='JoJo''s Bizarre Adventure'; titleOriginal='ジョジョの奇妙な冒険'; year=2012; accentColor='#FFB300'; description='Gerações Joestar enfrentam males bizarros com garra, poses e espírito de luta.' }
    'Kagurabachi'                                                                = @{ slug='kagurabachi'; title='Kagurabachi'; titleOriginal='カグラバチ'; year=2023; accentColor='#212121'; description='O herdeiro de lâminas encantadas caça bruxos pela vingança do pai.' }
    'Mairimashita! Iruma-kun'                                                    = @{ slug='mairimashita-iruma-kun'; title='Mairimashita! Iruma-kun'; titleOriginal='魔入りました!入間くん'; year=2019; accentColor='#00897B'; description='Vendido a um demônio, um humano gentil tenta sobreviver à escola do inferno.' }
    'Mieruko-chan'                                                               = @{ slug='mieruko-chan'; title='Mieruko-chan'; titleOriginal='見える子ちゃん'; year=2021; accentColor='#5C6BC0'; description='Ela vê espíritos e finge que não vê — a coragem dela fica no silêncio.' }
    'OMORI'                                                                      = @{ slug='omori'; title='OMORI'; titleOriginal=$null; year=2020; accentColor='#37474F'; description='Um mundo dos sonhos guarda a verdade que o dono se nega a sentir.' }
    'One-Punch Man'                                                              = @{ slug='one-punch-man'; title='One-Punch Man'; titleOriginal='ワンパンマン'; year=2015; accentColor='#FFD600'; description='O herói mais forte do mundo busca a emoção que a força absoluta levou.' }
    'Run with the Wind (Kaze ga Tsuyoku Fuiteiru)'                               = @{ slug='run-with-the-wind'; title='Run with the Wind'; titleOriginal='風が強く吹いている'; year=2018; accentColor='#8D6E63'; description='Dez estudantes despreparados correm o ekiden mais famoso do Japão.' }
    'Servamp'                                                                    = @{ slug='servamp'; title='Servamp'; titleOriginal='サーヴァンプ'; year=2016; accentColor='#546E7A'; description='Um garota preeguiçosa firma contrato com o mais preguiçoso dos vampiros-servos.' }
    'Solo Leveling (Ore dake Level Up na Ken)'                                   = @{ slug='solo-leveling'; title='Solo Leveling'; titleOriginal='俺だけレベルアップな件'; year=2024; accentColor='#4A148C'; description='O caçador mais fraco recebe um sistema: só ele pode subir de nível.' }
    'Soul Eater'                                                                 = @{ slug='soul-eater'; title='Soul Eater'; titleOriginal='ソウルイーター'; year=2008; accentColor='#7E57C2'; description='Na Shibusen, mestres e armas humanas caçam as almas corruptas antes do caos.' }
    'Spy x Family'                                                               = @{ slug='spy-x-family'; title='Spy x Family'; titleOriginal='スパイファミリー'; year=2022; accentColor='#26A69A'; description='Um espião, uma assassina e uma telepata: uma família unida por segredos sinceros.' }
    'Tengen Toppa Gurren Lagann'                                                 = @{ slug='gurren-lagann'; title='Tengen Toppa Gurren Lagann'; titleOriginal='天元突破グレンラガン'; year=2007; accentColor='#FFAB00'; description='Perfuradores cavam o próprio destino até o céu.' }
    'The Summer Hikaru Died (Hikaru ga Shinda Natsu)'                            = @{ slug='the-summer-hikaru-died'; title='The Summer Hikaru Died'; titleOriginal='ヒカルが死んだ夏'; year=2024; accentColor='#2E7D32'; description='Uma vila rural sente o resto de verão esfriando quando o amigo volta diferente do que era.' }
    'Tokyo Ghoul:re'                                                             = @{ slug='tokyo-ghoul-re'; title='Tokyo Ghoul:re'; titleOriginal='東京喰種:re'; year=2018; accentColor='#37474F'; description='Reconstruído sob outro nome, o ex-ghoul mais procurado serve aos próprios caçadores.' }
    'Toilet-Bound Hanako-kun (Jibaku Shounen Hanako-kun)'                         = @{ slug='toilet-bound-hanako-kun'; title='Toilet-Bound Hanako-kun'; titleOriginal='地縛少年花子くん'; year=2020; accentColor='#EF9A9A'; description='Entre os sete mistérios da escola, Hanako-kun guarda segredos maiores que o próprio medo.' }
    'Witch Hat Atelier (Tongari Boushi no Atelier)'                              = @{ slug='witch-hat-atelier'; title='Witch Hat Atelier'; titleOriginal='とんがり帽子のアトリエ'; year=2025; accentColor='#8D6E63'; description='Toda magia é desenho: uma menina entra no ateliê das bruxas proibida de errar.' }
    'xxxHOLiC'                                                                   = @{ slug='xxxholic'; title='xxxHOLiC'; titleOriginal='×××HOLiC'; year=2006; accentColor='#7B1FA2'; description='Uma loja realiza qualquer desejo — cobrando o equivalente certo por ele.' }
    'xxxHOLiC Rei'                                                               = @{ slug='xxxholic-rei'; title='xxxHOLiC Rei'; titleOriginal=$null; year=2013; accentColor='#9575CD'; description='A loja reabre as portas; os desejos continuam cobrando o seu preço.' }
    'Yu Yu Hakusho'                                                              = @{ slug='yu-yu-hakusho'; title='Yu Yu Hakusho'; titleOriginal='幽遊白書'; year=1992; accentColor='#00695C'; description='Um delinquente morre salvando um menino e vira detetive do mundo espiritual.' }
    # ---- Lote 3 (v0.9.3) -----------------------------------------------------
    'Another'                                                                    = @{ slug='another'; title='Another'; titleOriginal='アナザー'; year=2012; accentColor='#455A64'; description='A turma 3-3 esconde uma morte que volta todo ano para cobrar o preço do silêncio.' }
    'Astro Boy (Tetsuwan Atom)'                                                  = @{ slug='astro-boy'; title='Astro Boy'; titleOriginal='鉄腕アトム'; year=1963; accentColor='#F9A825'; description='O menino-robô de coração humano protege um futuro onde robôs e humanos convivem.' }
    'Black Torch'                                                                = @{ slug='black-torch'; title='Black Torch'; titleOriginal='BLACK TORCH'; year=2017; accentColor='#EF6C00'; description='Um jovem que fala com animais divide o corpo com um mononoke de fogo e vira shinobi.' }
    'Bungou Stray Dogs'                                                          = @{ slug='bungou-stray-dogs'; title='Bungou Stray Dogs'; titleOriginal='文豪ストレイドッグス'; year=2016; accentColor='#26A69A'; description='Detetives com os poderes dos grandes escritores protegem Yokohama.' }
    'Dorohedoro'                                                                 = @{ slug='dorohedoro'; title='Dorohedoro'; titleOriginal='ドロヘドロ'; year=2020; accentColor='#78909C'; description='Um homem de cabeça de jacaré caça o feiticeiro que o transformou.' }
    'Erased (Boku dake ga Inai Machi)'                                           = @{ slug='erased'; title='Erased'; titleOriginal='僕だけがいない街'; year=2016; accentColor='#5C6BC0'; description='Um mangaká volta ao passado para salvar uma colega da própria morte.' }
    'Fate/stay night'                                                            = @{ slug='fate-stay-night'; title='Fate/stay night'; titleOriginal=$null; year=2014; accentColor='#1565C0'; description='Na Guerra do Santo Graal, Shirou jura manter de pé o ideal de ser um herói.' }
    'Fruits Basket'                                                              = @{ slug='fruits-basket'; title='Fruits Basket'; titleOriginal='フルーツバスケット'; year=2019; accentColor='#F48FB1'; description='Tohru descubra a maldição do zodíaco na família Sohma — e desfaz uma por uma.' }
    'GOSICK'                                                                     = @{ slug='gosick'; title='GOSICK'; titleOriginal='ゴシック'; year=2011; accentColor='#00838F'; description='Numa academia nos céus da Europa, a pequena detetive dourada refaz o caos em verdade.' }
    'Hell''s Paradise (Jigokuraku)'                                              = @{ slug='hells-paradise'; title='Hell''s Paradise'; titleOriginal='地獄楽'; year=2023; accentColor='#66BB6A'; description='Um ninja condenado busca o elixir da imortalidade numa ilha paradisíaca e mortal.' }
    'Innocent'                                                                   = @{ slug='innocent'; title='Innocent'; titleOriginal='イノセント'; year=2013; accentColor='#90A4AE'; description='A saga do carrasco de Paris que deu dignidade à guilhotina do povo.' }
    'InuYasha'                                                                   = @{ slug='inuyasha'; title='InuYasha'; titleOriginal='犬夜叉'; year=2000; accentColor='#C62828'; description='A garota do poço e o meio-youkai caçam os cacos da Jóia de Shikon.' }
    'Jigoku Shoujo (Hell Girl)'                                                  = @{ slug='jigoku-shoujo'; title='Hell Girl'; titleOriginal='地獄少女'; year=2005; accentColor='#7B1FA2'; description='A garota do inferno executa vinganças — e cobra a alma de quem pede.' }
    'Kamisama Hajimemashita (Kamisama Kiss)'                                     = @{ slug='kamisama-kiss'; title='Kamisama Kiss'; titleOriginal='神様はじめました'; year=2012; accentColor='#AD1457'; description='Sem teto e sem família, Nanami vira deusa de terra — com um youkai-raposa fiel.' }
    'Kekkai Sensen (Blood Blockade Battlefront)'                                 = @{ slug='kekkai-sensen'; title='Blood Blockade Battlefront'; titleOriginal='血界戦線'; year=2015; accentColor='#00897B'; description='Na Nova York tomada por brechas, a Libra segura o equilíbrio dos dois mundos.' }
    'Lili-Men'                                                                   = @{ slug='lili-men'; title='Lili-Men'; titleOriginal='リリメン'; year=2022; accentColor='#8E24AA'; description='Succubi usam humanos como matrizes para se reproduzir e a humanidade jura exterminar cada uma — até nascer o rei que encerrará a guerra.' }
    'Love Bullet'                                                                = @{ slug='love-bullet'; title='Love Bullet'; titleOriginal=$null; year=2023; accentColor='#EC407A'; description='As cupidos de hoje carregam revólver: uma bala calibrada faz o amor florescer.' }
    'Mashle: Magic and Muscles'                                                  = @{ slug='mashle'; title='Mashle'; titleOriginal='マッシュル'; year=2023; accentColor='#455A64'; description='Sem uma gota de magia, Mash atravessa a academia de magia com músculos.' }
    'Mato Seihei no Slave (Chained Soldier)'                                     = @{ slug='chained-soldier'; title='Chained Soldier'; titleOriginal='魔都精兵のスレイブ'; year=2024; accentColor='#7B1FA2'; description='Só mulheres enfrentam os demônios de Mato — e Yuuki se torna o escravo de Kyouka.' }
    'Medalist'                                                                   = @{ slug='medalist'; title='Medalist'; titleOriginal='メダリスト'; year=2025; accentColor='#039BE5'; description='A menina que começou tarde e o instrutor falido patinam rumo ao pódio.' }
    'Mermaid Saga (Ningyo Series)'                                               = @{ slug='mermaid-saga'; title='Mermaid Saga'; titleOriginal=$null; year=2003; accentColor='#00838F'; description='A carne de sereia ergue os vivos por séculos — pagando com a própria humanidade.' }
    'Mission: Yozakura Family (Yozakura-san Chi no Daisakusen)'                  = @{ slug='mission-yozakura-family'; title='Mission: Yozakura Family'; titleOriginal='夜桜さんちの大作戦'; year=2024; accentColor='#AD1457'; description='Casado na família-espionagem Yozakura, Taiyo aprende a proteger de verdade.' }
    'Natsume Yuujinchou (Natsume''s Book of Friends)'                            = @{ slug='natsume-yuujinchou'; title='Natsume''s Book of Friends'; titleOriginal='夏目友人帳'; year=2008; accentColor='#558B2F'; description='O único que vê youkais devolve os nomes roubados — sempre com o gato por perto.' }
    'Nue''s Exorcist (Nue no Onmyouji)'                                          = @{ slug='nue-no-onmyouji'; title='Nue''s Exorcist'; titleOriginal='鵺の陰陽師'; year=2024; accentColor='#5C6BC0'; description='Assombrado no colégio, Gakuro alia-se ao youkai Nue para proteger os vivos.' }
    'Orange'                                                                     = @{ slug='orange'; title='Orange'; titleOriginal='オレンジ'; year=2016; accentColor='#FB8C00'; description='Cartas do futuro pedem uma única coisa: não deixe o Kakeru morrer de novo.' }
    'Ragna Crimson'                                                              = @{ slug='ragna-crimson'; title='Ragna Crimson'; titleOriginal='ラグナクリムゾン'; year=2023; accentColor='#C62828'; description='Armado com o poder do próprio eu futuro, Ragna declara guerra aos dragões.' }
    'RG Veda (Seiden: RG Veda)'                                                  = @{ slug='rg-veda'; title='RG Veda'; titleOriginal='聖伝-RG VEDA-'; year=1991; accentColor='#8E24AA'; description='O senhor Yasha e a criança Ashura desafiam a profecia e o imperador usurpador.' }
    'RuriDragon'                                                                 = @{ slug='ruridragon'; title='RuriDragon'; titleOriginal='ルリドラゴン'; year=2022; accentColor='#558B2F'; description='Chifres de dragão de uma noite para outra: Ruri segue o dia a dia em passo normal.' }
    'Sakamoto Days'                                                              = @{ slug='sakamoto-days'; title='Sakamoto Days'; titleOriginal='SAKAMOTO DAYS'; year=2025; accentColor='#F9A825'; description='O lendário assassino virou dono de bairro — e o submundo ainda cobra o preço.' }
    'Tasogare Otome x Amnesia (Dusk Maiden of Amnesia)'                          = @{ slug='dusk-maiden'; title='Dusk Maiden of Amnesia'; titleOriginal='黄昏乙女×アムネジア'; year=2012; accentColor='#6A1B9A'; description='O clube do paranormal acolhe a fantasma elegante — e investe contra o mistério dela.' }
    'Tenmaku no Jaadugar'                                                        = @{ slug='tenmaku-no-jaadugar'; title='Tenmaku no Jaadugar'; titleOriginal='天幕のジャードゥガー'; year=2021; accentColor='#5D4037'; description='No império das estepes, uma sábia cativa arma a própria liberdade com tinta e livros.' }
    'The Promised Neverland (Yakusoku no Neverland)'                             = @{ slug='the-promised-neverland'; title='The Promised Neverland'; titleOriginal='約束のネバーランド'; year=2019; accentColor='#33691E'; description='Órfãos descobrem que são gado — e planejam do zero a fuga perfeita.' }
    'The Saga of Tanya the Evil (Youjo Senki)'                                   = @{ slug='youjo-senki'; title='The Saga of Tanya the Evil'; titleOriginal='幼女戦記'; year=2017; accentColor='#263238'; description='Uma soldada impiedosa declara guerra ao próprio deus que a renasceu.' }
    'Ultimate Exorcist Kiyoshi (Exorcist no Kiyoshi-kun)'                        = @{ slug='ultimate-exorcist-kiyoshi'; title='Ultimate Exorcist Kiyoshi'; titleOriginal=$null; year=2024; accentColor='#00897B'; description='O exorcista forte demais tenta, inutilmente, uma vida escolar comum.' }
    'Undead Unluck'                                                              = @{ slug='undead-unluck'; title='Undead Unluck'; titleOriginal='アンデッドアンラック'; year=2023; accentColor='#7B1FA2'; description='A garota da má-sorte e o morto-vivo atrás da melhor morte viram negadores do mundo.' }
    'Vampire Hunter D'                                                           = @{ slug='vampire-hunter-d'; title='Vampire Hunter D'; titleOriginal='吸血鬼ハンター'; year=1985; accentColor='#6D4C41'; description='No crepúsculo da nobreza, o dhampir solitário caça os senhores da noite.' }
    'Wind Breaker'                                                               = @{ slug='wind-breaker'; title='Wind Breaker'; titleOriginal='Wind Breaker'; year=2024; accentColor='#1565C0'; description='Os punhos da Furin não espalham violência: protegem a cidade e o próprio orgulho.' }
    'Zatch Bell! (Konjiki no Gash Bell!)'                                        = @{ slug='zatch-bell'; title='Zatch Bell!'; titleOriginal='金色のガッシュ!!'; year=2003; accentColor='#F9A825'; description='Cem demônios disputam o trono do mundo mamodo com livro e parceiro humano.' }
    # ---- Lote 4 (v0.9.3) -----------------------------------------------------
    'Black Clover'                                                               = @{ slug='black-clover'; title='Black Clover'; titleOriginal='ブラッククローバー'; year=2017; accentColor='#37474F'; description='Sem uma gota de magia, Asta disputa o trono de Rei Mago pela pura obstinação.' }
    'Digimon Adventure'                                                          = @{ slug='digimon-adventure'; title='Digimon Adventure'; titleOriginal='デジモンアドベンチャー'; year=1999; accentColor='#0288D1'; description='Crianças e parceiros digitais crescem juntos salvando dois mundos.' }
    'Elfen Lied'                                                                 = @{ slug='elfen-lied'; title='Elfen Lied'; titleOriginal='エルフェンリート'; year=2004; accentColor='#AD1457'; description='A diclonius Lucy carrega a crueldade de um mundo que a criou como arma.' }
    'Kengan Ashura'                                                              = @{ slug='kengan-ashura'; title='Kengan Ashura'; titleOriginal='ケンガンアシュラ'; year=2019; accentColor='#E64A19'; description='Nos duelos Kengan que decidem negócios, Ohma busca ser o Asura do ringue.' }
    'Pokémon'                                                                    = @{ slug='pokemon'; title='Pokémon'; titleOriginal='ポケットモンスター'; year=1997; accentColor='#FBC02D'; description='Ao lado de Pikachu, Ash atravessa regiões inteiras para se tornar Mestre Pokémon.' }
    'ReLIFE'                                                                     = @{ slug='relife'; title='ReLIFE'; titleOriginal='リライフ'; year=2016; accentColor='#26A69A'; description='Um adulto fracassado recomeça o ensino médio como experimento secreto.' }
    'Shuumatsu no Valkyrie (Record of Ragnarok)'                                 = @{ slug='record-of-ragnarok'; title='Record of Ragnarok'; titleOriginal='終末のワルキューレ'; year=2021; accentColor='#B0BEC5'; description='Treze humanos históricos enfrentam treze deuses em duelos que decidem a espécie.' }
}

# ---------------------------------------------------------------------------
# Agrupamento de variantes de personagem (nome bruto no .md -> nome final)
# ---------------------------------------------------------------------------
$Renames = @{
    'Ichigo (Bankai)'                 = 'Ichigo Kurosaki'
    'Ichigo & Rukia'                  = 'Ichigo Kurosaki'
    'Kugo Ginjo (Final)'              = 'Kugo Ginjo'
    'Rukia (Retorno)'                 = 'Rukia Kuchiki'
    'Shinji (Passado)'                = 'Shinji Hirako'
    'Ulquiorra (Etapa)'               = 'Ulquiorra Cifer'
    'Yammy (Ira)'                     = 'Yammy Llargo'
    'Grimmjow (Res.)'                 = 'Grimmjow'
    'Yamamoto (Bankai)'               = 'Yamamoto'
    'Haschwalth (Criança)'            = 'Haschwalth'
    'Yasutora Sado (Chad)'            = 'Yasutora Sado'
    'Kaien / Aaroniero'               = 'Kaien Shiba'
    'Lelouch vi Britannia'            = 'Lelouch Lamperouge'
    'Majin Vegeta'                    = 'Vegeta'
    'Pain (Nagato)'                   = 'Pain'
    'Edward Newgate (Barba Branca)'   = 'Barba Branca'
    'Manjiro Sano (Mikey)'            = 'Manjiro Sano'
    'Ken Ryuguji (Draken)'            = 'Ken Ryuguji'
    'Duke Hyou (Biao Gong)'           = 'Duke Hyou'
    'Ei Sei (Ying Zheng)'             = 'Ei Sei'
    'Kanki (Huan Yi)'                 = 'Kan Ki'
    'Shin (Li Xin)'                   = 'Shin'
    'Wang Qi (Ou Ki)'                 = 'Wang Qi'
    'Esfera Negra (Gantz)'            = 'Gantz'
    'Gogeta (Super Saiyajin 4)'       = 'Gogeta'
    'Narrador (Final)'                = 'Narrador'
    'Shigeo Kageyama (Mob)'           = 'Shigeo Kageyama'
    # Nova seleção (v4)
    'Iruma Suzuki (Ciclo do Mal)'     = 'Iruma Suzuki'
    'Ken Kaneki (Ceifador Negro)'     = 'Ken Kaneki'
    'Ken Kaneki (Rei de Um Olho)'     = 'Ken Kaneki'
    'Loid Forger (Twilight)'          = 'Loid Forger'
    'Ken Takakura (Okarun)'           = 'Ken Takakura'
    'Kuro (Sleepy Ash)'               = 'Kuro'
    'Direita (Tsugai)'                = 'Right'
    'Ryuji Ayukawa (Yuka)'            = 'Ryuji Ayukawa'
    # Lotes 3/4 (v0.9.3) — renames pedidos
    'Ergo Proxy'                      = 'Proxy'
    'Deusa do Mar'                    = 'Sea'
    'Dera'                            = 'Ryu Tadera'
    # Lotes 3/4 (v0.9.3) — variantes agrupadas
    'Astro Boy (Atom)'                = 'Astro Boy'
    'Saber (Artoria Pendragon)'       = 'Saber'
    'Archer (EMIYA)'                  = 'Archer'
    'Madara (Nyanko-sensei)'          = 'Nyanko-sensei'
    'Gabimaru o Vazio'                = 'Gabimaru'
    'Yuko Kanoe (Sombra)'             = 'Yuko Kanoe'
    'Andy (Undead)'                   = 'Andy'
    'Fuuko Izumo (Unluck)'            = 'Fuuko Izumo'
    'Isabella (Mama)'                 = 'Isabella'
    'Ash Ketchum (Satoshi)'           = 'Ash Ketchum'
    'Meowth (Nyarth)'                 = 'Meowth'
    'Zatch Bell (Gash Bell)'          = 'Zatch Bell'
    'Rei Demônio (Pai)'               = 'Rei Demônio'
    'Mão Esquerda (Left Hand)'        = 'Mão Esquerda'
    'Juiz (Juiz da Union)'            = 'Juiz'
}

# Contexto adicional para variantes mescladas (preserva a distincao perdida)
$VariantContexts = @{
    'Ichigo (Bankai)'        = 'Forma Bankai'
    'Ichigo & Rukia'         = 'Poema em dupla com Rukia Kuchiki'
    'Kugo Ginjo (Final)'     = 'Momento final'
    'Rukia (Retorno)'        = 'Retorno'
    'Shinji (Passado)'       = 'Passado'
    'Ulquiorra (Etapa)'      = 'Segunda Etapa (Resurrección)'
    'Yammy (Ira)'            = 'Forma de Ira (Resurrección)'
    'Grimmjow (Res.)'        = 'Forma Resurrección'
    'Yamamoto (Bankai)'      = 'Forma Bankai'
    'Haschwalth (Criança)'   = 'Infância'
    'Gogeta (Super Saiyajin 4)' = 'Fusão Super Saiyajin 4'
    'Narrador (Final)'       = 'Encerramento da série'
    'Majin Vegeta'           = 'Saga Majin (Buu)'
    'Kaien / Aaroniero'      = 'Poema recitado por Aaroniero com a aparência de Kaien'
    'Lelouch vi Britannia'   = 'Identidade imperial'
    'Pain (Nagato)'          = 'Identidade: Nagato'
    # Nova seleção (v4)
    'Iruma Suzuki (Ciclo do Mal)' = 'Ciclo do Mal'
    'Ken Kaneki (Ceifador Negro)' = 'Ceifador Negro'
    'Ken Kaneki (Rei de Um Olho)' = 'Rei de Um Olho'
    'Loid Forger (Twilight)'      = 'Codinome: Twilight'
    'Ken Takakura (Okarun)'       = 'Apelido: Okarun'
    'Kuro (Sleepy Ash)'           = 'Sleepy Ash'
    'Direita (Tsugai)'            = 'Tsugai'
    'Ryuji Ayukawa (Yuka)'        = 'Também conhecida como Yuka'
    # Lotes 3/4 (v0.9.3)
    'Astro Boy (Atom)'          = 'Também conhecido como Atom'
    'Saber (Artoria Pendragon)' = 'Nome verdadeiro: Artoria Pendragon'
    'Archer (EMIYA)'            = 'O Servo de um futuro distante (EMIYA)'
    'Madara (Nyanko-sensei)'    = 'Apelido: Nyanko-sensei'
    'Gabimaru o Vazio'          = 'Estado "vazio" do ninja, sem emoções'
    'Yuko Kanoe (Sombra)'       = 'A Sombra'
    'Andy (Undead)'             = 'Undead'
    'Fuuko Izumo (Unluck)'      = 'Unluck'
    'Isabella (Mama)'           = 'Conhecida como Mama'
    'Ash Ketchum (Satoshi)'     = 'Nome japonês: Satoshi'
    'Meowth (Nyarth)'           = 'Nome japonês: Nyarth'
    'Zatch Bell (Gash Bell)'    = 'Nome japonês: Gash Bell'
    'Rei Demônio (Pai)'         = 'O pai de Kiyoshi'
    'Mão Esquerda (Left Hand)'  = 'Também conhecida como Left Hand'
    'Juiz (Juiz da Union)'      = 'Juiz da União'
}

# Contextos pontuais por frase: obra -> kanji exato (coluna Original (JP)) -> contexto.
# Aplica-se QUANDO a frase nao tiver contexto de variante; consumed no quote-build.
$ExtraQuoteContexts = @{
    'Haikyu!!' = @{
        'コンクリート出身日向翔陽です。あなたをブッ倒して全国へ行きます。' = 'Resposta a Wakatoshi Ushijima: nascido do concreto, Hinata promete esmagar o time dele e ir aos Nacionais.'
    }
}

# Kanji ja validados no seed v1 (null para personagens novos)
$NameOriginals = @{
    'Haku'            = '白'
    'Obito Uchiha'    = 'うちは オビト'
    'Naruto Uzumaki'  = 'うずまき ナルト'
    'Itachi Uchiha'   = 'うちは イタチ'
    'Vegeta'          = 'ベジータ'
    'Son Goku'        = '孫 悟空'
    'Piccolo'         = 'ピッコロ'
    'Monkey D. Luffy' = 'モンキー・D・ルフィ'
    'Roronoa Zoro'    = 'ロロノア・ゾロ'
}

# Descricoes de 1 linha por personagem (chave = nome final)
$CharDescriptions = @{
    # Reaproveitados do seed v1
    'Vegeta'                    = 'Príncipe dos Saiyajins, movido pelo orgulho da sua raça.'
    'Son Goku'                  = 'Protagonista; sempre em busca de adversários mais fortes.'
    'Piccolo'                   = 'De rival a mentor de Gohan; frio nas palavras e orgulhoso por natureza.'
    'Haku'                      = 'Servo leal de Zabuza, vê a própria existência como uma ferramenta.'
    'Naruto Uzumaki'            = 'Protagonista e futuro Hokage.'
    'Itachi Uchiha'             = 'Irmão de Sasuke; viveu como espião em silêncio pela paz da vila.'
    'Obito Uchiha'              = 'Companheiro de equipe de Kakashi, lembrado por suas palavras sobre companheiros.'
    'Monkey D. Luffy'           = 'Capitão dos Chapéus de Palha, futuro Rei dos Piratas.'
    'Roronoa Zoro'              = 'Espadachim determinado a se tornar o melhor do mundo.'
    # Berserk
    'Guts'                      = 'Espadachim marcado pelo Brandão, guerreiro que desafia o próprio destino.'
    'Griffith'                  = 'Líder carismático dos Bando do Falcão, movido pelo sonho de ter o próprio reino.'
    'Cavaleiro Caveira'         = 'Misterioso cavaleiro de armadura que testa e orienta Guts.'
    # Bleach
    'Ichigo Kurosaki'           = 'Substituto Shinigami com energia espiritual extraordinária.'
    'Rukia Kuchiki'             = 'Shinigami da nobreza Kuchiki que introduz Ichigo ao mundo espiritual.'
    'Sosuke Aizen'              = 'Ex-capitão da 5ª Divisão, gênio manipulador que busca o trono dos céus.'
    'Kisuke Urahara'            = 'Ex-capitão da 12ª Divisão e dono de loja, estrategista de chapéu listrado.'
    'Byakuya Kuchiki'           = 'Capitão da 6ª Divisão, guardião do orgulho nobre e irmão adotivo de Rukia.'
    'Zaraki Kenpachi'           = 'Capitão da 11ª Divisão, obcecado por batalhas intensas.'
    'Orihime Inoue'             = 'Colega de Ichigo com poder de cura e rejeição de eventos.'
    'Uryu Ishida'               = 'Quincy sobrevivente, rival e aliado de Ichigo.'
    'Yasutora Sado'             = 'Amigo silencioso e forte de Ichigo, de coração gentil.'
    'Zangetsu'                  = 'Zanpakuto encarnada de Ichigo, manifestação de sua alma.'
    'Gin Ichimaru'              = 'Ex-capitão da 3ª Divisão, sorriso enigmático e intenções ocultas.'
    'Yoruichi Shihoin'          = 'Ex-capitã e mestra do Shunpo, que se transforma em gata.'
    'Renji Abarai'              = 'Tenente da 6ª Divisão, amigo de infância de Rukia.'
    'Retsu Unohana'             = 'Capitã da 4ª Divisão, curandeira com um passado sombrio.'
    'Mayuri Kurotsuchi'         = 'Capitão da 12ª Divisão, cientista excêntrico e cruel.'
    'Hitsugaya Toshiro'         = 'Capitão prodígio da 10ª Divisão, mestre do gelo.'
    'Soi Fon'                   = 'Capitã da 2ª Divisão, mestra de assassinos e leal a Yoruichi.'
    'Yamamoto'                  = 'Capitão-general do Gotei 13, portador da chama mais antiga.'
    'Coyote Starrk'             = 'Primera Espada relutante, poderoso mas preguiçoso.'
    'Tier Harribel'             = 'Terceira Espada, rainha defensora de Hueco Mundo.'
    'Nelliel'                   = 'Antiga Terceira Espada com aparência de criança e coração nobre.'
    'Grimmjow'                  = 'Sexta Espada, predador impiedoso que busca lutas verdadeiras.'
    'Ulquiorra Cifer'           = 'Quarta Espada, nihilista que questiona o conceito de coração.'
    'Szayelaporro'              = 'Oitava Espada, cientista louco dos Arrancar.'
    'Nnoitra Gilga'             = 'Quinta Espada, movida pelo ódio e pelo orgulho ferido.'
    'Baraggan'                  = 'Rei decadente de Hueco Mundo, dono do poder do tempo.'
    'Yammy Llargo'              = 'Décima Espada, cuja ira multiplica seu poder.'
    'Luppi Antenor'             = 'Arrancar arrogante que substituiu Grimmjow por um tempo.'
    'Dordonii'                  = 'Arrancar veterano que preserva o orgulho de guerreiro.'
    'Cirucci'                   = 'Arrancar elegante com arma em forma de disco.'
    'Kaien Shiba'               = 'Tenente carismático da 13ª Divisão, memória querida por Rukia.'
    'Ganju Shiba'               = 'Irmão da família Shiba, especialista em fogos de artifício.'
    'Kukaku Shiba'              = 'Mestre de canhões da família Shiba, explosiva e destemida.'
    'Hanataro Yamada'           = 'Curandeiro tímido da 4ª Divisão com uma lâmina inusitada.'
    'Ikkaku Madarame'           = 'Oficial da 11ª Divisão, guerreiro calvo que esconde sua Bankai.'
    'Yumichika'                 = 'Oficial da 11ª Divisão, obcecado por beleza nas batalhas.'
    'Izuru Kira'                = 'Tenente da 3ª Divisão, leal e melancólico.'
    'Shuhei Hisagi'             = 'Tenente da 9ª Divisão, marcado pela busca do verdadeiro poder.'
    'Sajin Komamura'            = 'Capitão da 7ª Divisão, humano-lobo de lealdade absoluta.'
    'Kaname Tosen'              = 'Capitão da 9ª Divisão, que busca justiça sem luz.'
    'Rangiku'                   = 'Tenente da 10ª Divisão, vibrante e fiel a Hitsugaya.'
    'Nemu Kurotsuchi'           = 'Tenente artificial criada por Mayuri.'
    'Jidanbo'                   = 'Gigante guardião do portão leste da Soul Society.'
    'Masaki Kurosaki'           = 'Mãe de Ichigo, antiga Quincy de coração luminoso.'
    'Shinji Hirako'             = 'Capitão exilado dos Vizard, sarcástico e perspicaz.'
    'Kugo Ginjo'                = 'Primeiro substituto Shinigami e líder dos Xcution.'
    'Tsukishima'                = 'Xcution com poder de inserir-se no passado das pessoas.'
    'Riruka'                    = 'Xcution apaixonada por tudo que é fofo.'
    'Yukio'                     = 'Xcution jovem gênio que cria salas de jogo digitais.'
    'Ichibei Hyosube'           = 'Monarca da Soul Society, guardião dos nomes.'
    'Nimaiya Oetsu'             = 'Forjador de todas as Zanpakuto, o rei da espada.'
    'Gremmy'                    = 'Sternritter que materializa a própria imaginação.'
    'Giselle Gewelle'           = 'Sternritter que zombifica seus inimigos.'
    'Mask De Masculine'         = 'Sternritter luchador fortalecido por aplausos.'
    'Askin'                     = 'Sternritter de venenos, casual e letal.'
    'Bazz-B'                    = 'Sternritter de fogo, rebelde e explosivo.'
    'Haschwalth'                = 'Grão-mestre dos Sternritter, balança do poder de Yhwach.'
    'Yhwach'                    = 'Pai dos Quincy e rei dos Wandenreich, o poder da onipotência.'
    # Saint Seiya
    'Seiya de Pégaso'           = 'Cavaleiro de bronze teimoso que protege Athena com o Cosmo.'
    'Ikki de Fênix'             = 'Cavaleiro de Fênix, o mais forte e solitário dos irmãos de Bronze.'
    'Shiryu de Dragão'          = 'Cavaleiro de Dragão, sábio e disposto a dar a vida pelos amigos.'
    'Saga de Gêmeos'            = 'Cavaleiro de Gêmeos dividido entre luz e trevas.'
    'Shaka de Virgem'           = 'Cavaleiro de Virgem, dito o mais próximo dos deuses.'
    'Camus de Aquário'          = 'Cavaleiro de Ouro de Aquário, mestre do gelo absoluto.'
    # Clannad
    'Tomoya Okazaki'            = 'Estudante desiludido que reencontra o sentido da família.'
    'Nagisa Furukawa'           = 'Garota frágil que sonha reerguer o clube de teatro.'
    'Akio Furukawa'             = 'Pai de Nagisa, ex-ator virado padeiro de bom coração.'
    'Sanae Furukawa'            = 'Mãe de Nagisa, doce e inabalavelmente otimista.'
    'Ushio Okazaki'             = 'Filha de Tomoya e Nagisa, luz da nova geração.'
    # Claymore
    'Clare'                     = 'Guerreira meio-humana que caça Yomas em busca de vingança.'
    'Miria'                     = 'Líder das Claymore rebeldes, veloz como o vento.'
    'Teresa do Sorriso Tênue'   = 'A mais forte das Claymore, cujo sorriso mudou Clare.'
    # Code Geass
    'Lelouch Lamperouge'        = 'Príncipe exilado que lidera uma rebelião sob a máscara de Zero.'
    'C.C.'                      = 'Imortal que concede o Geass e guarda os segredos do mundo.'
    'Suzaku Kururugi'           = 'Soldado que acredita em mudar o império de dentro para fora.'
    # Cowboy Bebop
    'Spike Spiegel'             = 'Caçador de recompensas preguiçoso que vive no passado.'
    'Jet Black'                 = 'Ex-policial e capitão do Bebop, âncora moral da tripulação.'
    'Faye Valentine'            = 'Caçadora de dívidas com memória fragmentada e língua afiada.'
    # D.Gray-man
    'Allen Walker'              = 'Exorcista com olho amaldiçoado e Inocência na mão esquerda.'
    'Yu Kanda'                  = 'Esgrimista de temperamento feroz e passado secreto.'
    'Lavi'                      = 'Bookman em treinamento, otimista com martelo transformável.'
    'Conde do Milênio'          = 'Líder da Noé, criador das akuma e arquiteto da tragédia.'
    # Dororo
    'Hyakkimaru'                = 'Samurai sem 48 partes do corpo, que as recupera caçando demônios.'
    'Dororo'                    = 'Menino órfão trapaceiro que acompanha Hyakkimaru.'
    'Daigo Kagemitsu'           = 'Senhor feudal que sacrificou o filho ao poder dos demônios.'
    'Biwamaru'                  = 'Monge cego errante que lê o destino de Hyakkimaru.'
    'Mio'                       = 'Jovem cantora que oferece a Hyakkimaru um instante de paz.'
    # Dragon Ball GT / Z
    'Baby'                      = 'Parasita Tsufru que vinga seu povo dominando os Saiyajins.'
    'Gogeta'                    = 'Fusão de Goku e Vegeta, poder espetacular e efêmero.'
    'Narrador'                  = 'Voz que emoldura a saga e seus encerramentos.'
    'Trunks do Futuro'          = 'Filho de Vegeta vindo de um futuro devastado pelos androides.'
    # Ergo Proxy
    'Re-l Mayer'                = 'Inspetora da cidade-cúpula Romdeau, caçadora de Proxies.'
    'Vincent Law'               = 'Imigrante introspectivo que carrega a identidade de Ergo Proxy.'
    'Pino'                      = 'AutoReiv infantil que desperta para a consciência.'
    'Proxy'                     = 'O Proxy criador, agente do caos e da criação.'
    # Fullmetal Alchemist
    'Edward Elric'              = 'Alquimista de Aço que busca recuperar o corpo do irmão.'
    'Alphonse Elric'            = 'Irmão de Edward, alma presa numa armadura de aço.'
    'Roy Mustang'               = 'Coronel de chamas que almeja liderar Amestris.'
    'Izumi Curtis'              = 'Mestra de alquimia dos irmãos Elric, severa e amorosa.'
    'Greed'                     = 'Pecado da avidez, que quer tudo — inclusive amigos.'
    # Gachiakuta
    'Rudo'                      = 'Menino jogado no abismo que sobe para punir quem descarta pessoas.'
    'Enjin'                     = 'Limpador misterioso que guia Rudo no mundo dos resíduos.'
    'Zanka Nijiku'              = 'Limpador de temperamento sério, veterano dos poços.'
    # Gantz
    'Kei Kurono'                = 'Estudante egoísta que amadurece entre missões letais.'
    'Masaru Kato'               = 'Amigo de infância de Kurono, forte e justo.'
    'Kei Kishimoto'             = 'Colega resgatada pelo jogo, que busca seu lugar.'
    'Gantz'                     = 'A esfera negra que recruta mortos e distribui missões.'
    # Hajime no Ippo
    'Ippo Makunouchi'           = 'Boxeador tímido que descobre sua força no ringue.'
    'Mamoru Takamura'           = 'Campeão multicategorias, talento bruto e carisma.'
    'Genji Kamogawa'            = 'Treinador veterano que forja campeões com punho e sabedoria.'
    'Eiji Date'                 = 'Campeão veterano que ensina o peso do topo.'
    # Hunter x Hunter
    'Gon Freecss'               = 'Menino otimista que parte em busca do pai caçador.'
    'Killua Zoldyck'            = 'Herdeiro de família de assassinos, amigo leal de Gon.'
    'Kurapika'                  = 'Último sobrevivente do clã Kurta, movido pela vingança.'
    'Ging Freecss'              = 'Caçador lendário e pai distante de Gon.'
    'Isaac Netero'              = 'Presidente da Associação Hunter, mestre do Nen.'
    'Meruem'                    = 'Rei das Quimeras, que descobre a humanidade num jogo de tabuleiro.'
    # Ichi the Witch
    'Ichi'                      = 'Menino caçador de monstros que se torna o primeiro bruxo homem.'
    'Desscaras'                 = 'Bruxa poderosa e arrogante que aceita Ichi como aprendiz.'
    'Gokuraku Kagami'           = 'Bruxo da guilda que observa o talento de Ichi.'
    # Jujutsu Kaisen
    'Yuji Itadori'              = 'Vaso de Sukuna, estudante que escolhe dar uma morte digna.'
    'Satoru Gojo'               = 'Feiticeiro mais forte da era, professor irreverente.'
    'Suguru Geto'               = 'Feiticeiro que desvia para o ódio contra não-feiticeiros.'
    'Kento Nanami'              = 'Ex-assalariado virado feiticeiro, pragmático e justo.'
    'Aoi Todo'                  = 'Feiticeiro excêntrico que elege irmãos pelo espírito.'
    'Ryomen Sukuna'             = 'Rei das maldições, poder ancestral de mil anos.'
    # Kimetsu no Yaiba
    'Tanjiro Kamado'            = 'Caçador de demônios que busca a cura da irmã Nezuko.'
    'Kyojuro Rengoku'           = 'Pilar das Chamas, de coração ardente e sorriso firme.'
    'Giyu Tomioka'              = 'Pilar da Água, silencioso e severo consigo mesmo.'
    'Inosuke Hashibira'         = 'Caçador criado por javalis, selvagem e competitivo.'
    'Muzan Kibutsuji'           = 'Progenitor dos demônios, tirano que teme a própria morte.'
    # Kingdom
    'Shin'                      = 'Servo que sonha virar Grande General em guerra.'
    'Ei Sei'                    = 'Rei de Qin que almeja unificar a China.'
    'Wang Qi'                   = 'General lendário, mentor de Shin no campo de batalha.'
    'Duke Hyou'                 = 'General do fogo, instinto puro de guerra.'
    'Kan Ki'                    = 'General implacável, ex-bandido com táticas cruéis.'
    # Kuroko no Basket
    'Tetsuya Kuroko'            = 'A sombra do time, passe invisível e amor pelo basquete.'
    'Taiga Kagami'              = 'Ala que retorna dos EUA, luz para a sombra de Kuroko.'
    'Daiki Aomine'              = 'Gênio do basquete de rua, veloz e letal.'
    'Ryota Kise'                = 'Copiador perfeito dos movimentos dos rivais.'
    'Shintaro Midorima'         = 'Arremessador perfeito, supersticioso e orgulhoso.'
    'Seijuro Akashi'            = 'Capitão da Geração dos Milagres, imperador do domínio.'
    # Magi
    'Aladdin'                   = 'Jovem Magi, filho de Salomão, guiado pelo djinn Ugo.'
    'Alibaba Saluja'            = 'Príncipe exilado que domina a espada e o próprio valor.'
    'Morgiana'                  = 'Guerreira fanalis de origem escrava, força sobre-humana.'
    'Sinbad'                    = 'Rei de Sindria, conquistador de masmorras e carismático.'
    'Judar'                     = 'Magi negro provocador, ligado à organização Al-Thamen.'
    # Mob Psycho 100
    'Shigeo Kageyama'           = 'Estudante psíquico tímido que quer crescer sem depender de poderes.'
    'Arataka Reigen'            = 'Mentor autoproclamado de Mob, charlatão com conselhos de ouro.'
    'Ritsu Kageyama'            = 'Irmão mais novo de Mob, que esconde a própria inveja.'
    # Nanatsu no Taizai
    'Meliodas'                  = 'Capitão dos Sete Pecados, dragão da ira aparentemente jovem.'
    'Ban'                       = 'Pecado da ganância, imortal e risonho.'
    'Escanor'                   = 'Pecado do orgulho, o humano mais forte ao meio-dia.'
    'Gowther'                   = 'Pecado da luxúria, boneco que aprende emoções.'
    # Naruto / Shippuden
    'Kakashi Hatake'            = 'Líder do Time 7, ninja copiador de mil técnicas.'
    'Gaara'                     = 'Jinchuriki de Suna que encontra sentido em proteger.'
    'Rock Lee'                  = 'Ninja de taijutsu puro, exemplo de esforço incansável.'
    'Jiraiya'                   = 'Sannin pervertido, mestre de Naruto e escritor de novelas.'
    'Minato Namikaze'           = 'Quarto Hokage, herói da guerra e pai de Naruto.'
    'Madara Uchiha'             = 'Lendário fundador do clã Uchiha, arquiteto do Plano Olho da Lua.'
    'Pain'                      = 'Líder da Akatsuki que impõe a dor como caminho da paz.'
    'Shikamaru Nara'            = 'Estrategista preguiçoso com QI acima de 200.'
    # Neon Genesis Evangelion
    'Shinji Ikari'              = 'Piloto do Eva-01, fugindo da própria solidão.'
    'Rei Ayanami'               = 'Piloto reservada que questiona a própria existência.'
    'Asuka Langley Soryu'       = 'Piloto orgulhosa que recusa depender de alguém.'
    'Gendo Ikari'               = 'Comandante da NERV, pai que sacrifica tudo pelo plano.'
    'Ryoji Kaji'                = 'Agente duplo charmoso, que cultiva a verdade e melancias.'
    # One Piece
    'Nico Robin'                = 'Arqueóloga da tripulação, única capaz de ler os Poneglyphs.'
    'Dr. Hiriluk'               = 'Médico amador que ensinou a Chopper o poder dos sonhos.'
    'Gol D. Roger'              = 'O Rei dos Piratas, cujas palavras iniciaram a grande era.'
    'Barba Branca'              = 'O homem mais forte do mundo, pai de sua tripulação.'
    # Re:Zero
    'Natsuki Subaru'            = 'Estudante comum que morre e volta, armado só de persistência.'
    'Emilia'                    = 'Candidata ao trono, meio-elfa preterida pelo preconceito.'
    'Rem'                       = 'Oni serva devotada que enxerga o valor de Subaru.'
    'Echidna'                   = 'Bruxa da Ganância, obsessivamente curiosa pelo conhecimento.'
    'Petelgeuse Romanee-Conti'  = 'Arcebispo do Pecado da Preguiça, louco devoto.'
    # Serial Experiments Lain
    'Lain Iwakura'              = 'Menina que dissolve a fronteira entre a Wired e o mundo.'
    'Chisa Yomoda'              = 'Colega cuja mensagem póstuma abre a porta da Wired.'
    'Masami Eiri'               = 'Designer que se declara deus da Wired.'
    # Shingeki no Kyojin
    'Eren Yeager'               = 'Soldado que jura erradicar os Titãs — e descobre ser um.'
    'Mikasa Ackerman'           = 'Guerreira prodígio que protege Eren acima de tudo.'
    'Armin Arlert'              = 'Estrategista frágil fisicamente, gigante em ideias.'
    'Levi Ackerman'             = 'Capitão mais forte da humanidade, limpo até na guerra.'
    'Erwin Smith'               = 'Comandante que arrisca tudo pela verdade dentro do muro.'
    # The Apothecary Diaries
    'Maomao'                    = 'Farmacêutica curiosa que desvenda venenos e mistérios do palácio.'
    'Jinshi'                    = 'Administrador belíssimo do palácio interior, com identidade oculta.'
    'Lakan'                     = 'Estrategista obcecado por padrões e pelo Go.'
    # Tokyo Ghoul
    'Ken Kaneki'                = 'Estudante meio-ghoul que aprende a viver entre dois mundos.'
    'Touka Kirishima'           = 'Ghoul garçonete que equilibra vida humana e fome.'
    'Shu Tsukiyama'             = 'Ghoul gourmet obcecado pelo sabor de Kaneki.'
    # Tokyo Revengers
    'Takemichi Hanagaki'        = 'Viajante do tempo que salva a todos com coragem de covarde.'
    'Manjiro Sano'              = 'Líder carismático da Toman, o invencível Mikey.'
    'Ken Ryuguji'               = 'Vice-líder da Toman, voz da razão de Mikey.'
    'Keisuke Baji'              = 'Membro fundador da Toman, leal até o fim.'
    'Chifuyu Matsuno'           = 'Parceiro fiel de Baji e braço direito de Takemichi.'
    # Toriko
    'Toriko'                    = 'Caçador gourmet em busca do cardápio completo da vida.'
    'Coco'                      = 'Caçador elegante que domina venenos e previsões.'
    'Sunny'                     = 'Caçador vaidoso que transforma o cabelo em arte e arma.'
    'Zebra'                     = 'Caçador bruto cujo grito devasta tudo.'
    # Vagabond
    'Miyamoto Musashi'          = 'Espadachim que busca a verdade da espada e de si.'
    'Inshun Hozoin'             = 'Mestre da lança do templo Hozoin, que enfrenta Musashi.'
    'Takuan Soho'               = 'Monge zen que aconselha Musashi com dureza sábia.'
    # Vinland Saga
    'Thorfinn'                  = 'Menino guerreiro que busca vingança e descobre a paz.'
    'Askeladd'                  = 'Líder viking astuto e trágico, alvo da vingança de Thorfinn.'
    'Thors Snorresson'          = 'Guerreiro lendário que escolheu não lutar mais.'
    'Canute'                    = 'Príncipe dinamarquês que evolui de ovelha a rei.'
    # Classroom of the Elite
    'Kiyotaka Ayanokoji'        = 'Gênio treinado na White Room que prefere passar despercebido.'
    'Suzune Horikita'           = 'Aluna brilhante e solitária que aprende a confiar.'
    'Kikyo Kushida'             = 'Aluna simpática que esconde um lado explosivo.'
    # Sousou no Frieren
    'Frieren'                   = 'Maga elfa milenar que busca magia — e o sentido do tempo que perdeu.'
    'Himmel'                    = 'O herói do grupo de Frieren, cujas escolhas ecoam por séculos.'
    'Fern'                      = 'Aprendiz de Frieren, madura além da idade.'
    'Eisen'                     = 'Guerreiro anão veterano da jornada do herói.'
    'Heiter'                    = 'Sacerdote boêmio que criou Fern nos últimos anos de vida.'
}

# Descricoes por obra da nova selecao (chave = titulo da secao -> hashtable por nome;
# precede o mapa global para evitar colisoes de nomes iguais entre obras, ex. Sunny)
$WorkCharDescriptions = [ordered]@{
    'Angel Beats!' = @{
        'Yuzuru Otonashi' = 'Ex-internista que acordou no pós-morte sem memórias e vira o coração do grupo.'
        'Kanade Tachibana' = 'Presidente de classe silenciosa que os rebeldes chamam de Angel.'
        'Yuri Nakamura'   = 'Fundadora da SSS, lidera a guerra contra Deus pelo que perderam.'
        'Hideki Hinata'   = 'O companheiro brincalhão e leal que sempre se oferece para brigar.'
        'Yui'             = 'Ex-guitarrista explosiva do Girls Dead Monster, cheia de sonhos a cumprir.'
    }
    'Ao no Exorcist (Blue Exorcist)' = @{
        'Rin Okumura'     = 'Filho de Satanás criado por um padre, saca a espada contra o próprio pai.'
        'Shiro Fujimoto'  = 'Padre exorcista Paladino e pai adotivo dos gêmeos Okumura.'
        'Yukio Okumura'   = 'Gêmeo de Rin, gênio professor exorcista credenciado aos treze anos.'
        'Mephisto Pheles' = 'Diretor excêntrico da True Cross, demônio milenar e cheio de truques.'
    }
    'Baki the Grappler / Baki' = @{
        'Yujiro Hanma'   = 'O Ogro: a criatura mais forte do mundo e o alvo impossível de Baki.'
        'Baki Hanma'     = 'Herdeiro do nome da família, treina até a dor para vencer o pai.'
        'Kaoru Hanayama' = 'Yakuza gigante de punhos brutais e um código de honra à própria moda.'
        'Doppo Orochi'   = 'O tigre do karatê, mestre da aplicação real do golpe.'
    }
    'Blue Lock' = @{
        'Jinpachi Ego'   = 'Arquiteto do Blue Lock, aposta o futuro da seleção num egoísta absoluto.'
        'Yoichi Isagi'   = 'O cérebro do projeto, lê a partida e transforma leitura em gol.'
        'Meguru Bachira' = 'Driblista imprevisível guiado pelo seu monstro interior.'
        'Rin Itoshi'     = 'Prodígio frio movido pela rivalidade que cultivou com o próprio irmão.'
        'Seishiro Nagi'  = 'Talento preguiçoso que descobre, no meio do jogo, a fome de vencer.'
    }
    'Blue Period' = @{
        'Yatora Yaguchi' = 'Aluno nota máxima que troca o curso garantido pela pintura de madrugada.'
        'Masako Saeki'   = 'Veterana dedicada da escola de arte, exigente consigo e com Yatora.'
        'Ryuji Ayukawa'  = 'Artista sensível que preserva o carisma e luta contra a própria fragilidade.'
        'Maki Kuwana'    = 'Colega impulsiva que mostra a emoção crua nas telas.'
    }
    'Boku no Hero Academia (My Hero Academia)' = @{
        'All Might'      = 'O Símbolo da Paz: herói número um que sorri para dar coragem.'
        'Izuku Midoriya' = 'Deku, o garoto sem dom que herda o One For All por nunca desistir.'
        'Katsuki Bakugo' = 'Rival explosivo de Deku, transforma orgulho em combustível.'
        'Shoto Todoroki' = 'Fogo e gelo em um filho dividido entre o poder e a raiva da família.'
    }
    'Captain Tsubasa' = @{
        'Tsubasa Oozora'    = 'O craque que cresce com a bola aos pés e o sonho da Copa.'
        'Kojiro Hyuga'      = 'Atacante fortão dono do chute do tigre que arranca gol.'
        'Genzo Wakabayashi' = 'Goleiro-gênio rival de Tsubasa, encara qualquer chute de frente.'
        'Taro Misaki'       = 'Meio-campo criativo que forma com Tsubasa a dupla dourada.'
    }
    'Centuria' = @{
        'Julian'  = 'Jovem escravo que herda o poder das cem vidas e a chance de recomeçar.'
        'Sea'     = 'Entidade dos mares que se liga à sorte de Julian.'
        'Mira'    = 'A jovem que foge com Julian e vê nele a última esperança.'
    }
    'Chainsaw Man' = @{
        'Makima'       = 'A caçadora-chefe de sorriso calmo e controle absoluto sobre as pessoas.'
        'Denji'        = 'Garoto endividado que se funde ao cachorro Pochita por sonhos simples.'
        'Aki Hayakawa' = 'Caçador sério movido pela vingança da própria família.'
        'Power'        = 'Demônio-sangue mentirosa que vira parceira e amiga de Denji.'
        'Kishibe'      = 'O caçador mais veterano da organização, professor implacável.'
    }
    'Clannad: After Story' = @{
        'Ushio Okazaki'  = 'Filha de Tomoya e Nagisa, a luz que reergue o pai abatido.'
        'Tomoya Okazaki' = 'O ex-delinquente que aprende, devagar, o que é ser pai e marido.'
        'Akio Furukawa'  = 'Pai da Nagisa e avô da Ushio, padeiro tagarela de coração enorme.'
        'Sanae Furukawa' = 'Mãe da Nagisa, doce e pronta a chorar pelo pão que ninguém quis.'
    }
    'Daemons of the Shadow Realm (Yomi no Tsugai)' = @{
        'Yuru'       = 'O gêmeo criado no lado sombrio, guardião por contrato da vila.'
        'Asa'        = 'A gêmea da superfície, descobre tarde o lado sombrio da própria família.'
        'Ryu Tadera' = 'Daemon pareado de Asa, teimoso e grácil nas batalhas.'
        'Right'      = 'Daemon pareado de Yuru, força bruta com prumo no comando.'
    }
    'Dandadan' = @{
        'Momo Ayase'    = 'Neta do médium Seiko, enxerga espíritos e nunca fica parada.'
        'Ken Takakura'  = 'O fã de aliens apelidado de Okarun, herda a velocidade amaldiçoada.'
        'Turbo-Obaba'   = 'Espírito veloz do túnel, furioso quando amarrado a um corpo.'
        'Seiko Ayase'   = 'Médium lendária e avó de Momo, tutora excêntrica do oculto.'
    }
    'Dr. Stone' = @{
        'Senku Ishigami'  = 'O cérebro da humanidade petrificada, reconstrói tudo em fórmula.'
        'Tsukasa Shishio' = 'O lutador mais forte da era petrificada, imperador de um império ideal.'
        'Chrome'          = 'O mago de vilarejo que troca magia por ciência.'
        'Gen Asagiri'     = 'Estrategista das palavras, negocia alianças e dribla desconfianças.'
    }
    'Fairy Tail' = @{
        'Natsu Dragneel'  = 'Mago do fogo criado pelo dragão Igneel, coração mais quente da guilda.'
        'Erza Scarlet'    = 'Maga de armaduras que protege os amigos como uma promessa própria.'
        'Makarov Dreyar'  = 'Mestre da guilda: pequeno no tamanho, gigante no coração.'
        'Gray Fullbuster' = 'Mago do gelo rival de Natsu, aprendiz da mestra Ur.'
    }
    'Fire Force (Enen no Shouboutai)' = @{
        'Shinra Kusakabe'  = 'Sorriso de demônio e joelhos de recuo, sonha em ser herói de verdade.'
        'Akitaru Obi'      = 'Capitão sem poderes que comanda a Oitava com suor e coragem.'
        'Arthur Boyle'     = 'Cavaleiro autoproclamado que acende a própria Excalibur na imaginação.'
        'Iris'             = 'Irmã noviça da Oitava, reza pelas chamas e por quem queima.'
        'Benimaru Shinmon' = 'Mestre de Asakusa, resolve o sossego na base do punho.'
    }
    'Gintama' = @{
        'Gintoki Sakata'    = 'O samurai de prata que vive de bicos, doces e espada afiada.'
        'Shinsuke Takasugi' = 'O guerrilheiro da Kiheitai, guarda um olho e uma revolta.'
        'Kotaro Katsura'    = 'Líder do Jōi que vira alvo favorito das brincadeiras de Gintoki.'
        'Toshiro Hijikata'  = 'Vice-comandante da Shinsengumi, sério com tudo menos com a maionese.'
    }
    'Girls'' Last Tour (Shoujo Shuumatsu Ryokou)' = @{
        'Chito' = 'A leitora silenciosa da dupla, registra tudo no caderno.'
        'Yuuri' = 'A comilona otimista que carrega as armas e a leveza do fim do mundo.'
    }
    'Haikyu!!' = @{
        'Shoyo Hinata'   = 'O pequeno gigante do vôlei, salta mais alto do que qualquer barreira.'
        'Tobio Kageyama' = 'O setter apelidado de Rei da Quadra, exige precisão absurda.'
        'Toru Oikawa'    = 'Setter estiloso de Aoba Johsai, genial e movido pelo esforço.'
        'Keishin Ukai'   = 'O ex-craque convencido a treinar a nova geração de Karasuno.'
        'Kotaro Bokuto'  = 'Ace da Fukurodani, alterna entre o melhor e o pior humor da liga.'
    }
    'JoJo''s Bizarre Adventure' = @{
        'Dio Brando'      = 'Adotado dos Joestar, vira vampiro e sombra eterna da linhagem.'
        'Jotaro Kujo'     = 'O estudante que fala pouco e resolve com um soco do Star Platinum.'
        'Joseph Joestar'  = 'O Joestar das manhas, vence monstros com blefe e previsão.'
        'Rohan Kishibe'   = 'O mangaká dono do Heaven''s Door, lê e reescreve as pessoas.'
        'Giorno Giovanna' = 'O filho de Dio que se torna o Gang-Star com coração justo.'
    }
    'Kagurabachi' = @{
        'Chihiro Rokuhira'   = 'Herdeiro das lâminas encantadas, caça os bruxos que mataram o pai.'
        'Kunishige Rokuhira' = 'O ferreiro de lâminas encantadas, morto pelos que cobiçam suas obras.'
        'Sojo Genichi'       = 'Bruxo caçador das lâminas encantadas, movido por admiração retorcida.'
    }
    'Mairimashita! Iruma-kun' = @{
        'Iruma Suzuki'   = 'O humano vendido pelos próprios pais, adotado pelo mestre do inferno.'
        'Asmodeus Alice' = 'Demônio de fogo que elege Iruma como mestre e honra o posto.'
        'Clara Valac'    = 'A caótica alegre que imita qualquer coisa com a própria magia.'
        'Sullivan'       = 'Um dos três demônios mais poderosos, avô adotivo superprotetor.'
    }
    'Mieruko-chan' = @{
        'Miko Yotsuya'    = 'A garota que vê espíritos e finge que não vê, todo dia.'
        'Hana Yurikawa'   = 'A melhor amiga radiante que atrai espíritos sem notar.'
        'Yulia Niguredou' = 'Outra que vê os mortos, se aproxima de Miko querendo entender.'
    }
    'OMORI' = @{
        'Omori'  = 'O rosto pálido do mundo dos sonhos, guarda tudo que Sunny esconde.'
        'Mari'   = 'A irmã mais velha e pianista, apoio afetuoso do grupo.'
        'Aubrey' = 'A amiga de sempre, cresce entre mágoas e coragem.'
        'Basil'  = 'O fotógrafo do grupo, guardião da verdade e do segredo.'
        'Sunny'  = 'O garoto real atrás dos sonhos, precisa sair do quarto e falar.'
    }
    'One-Punch Man' = @{
        'Saitama'     = 'O herói que resolve tudo em um soco, morre de tédio.'
        'Genos'       = 'O ciborgue discípulo de Saitama, queima de vingança desde a vila perdida.'
        'Mumen Rider' = 'O herói de bicicleta da classe C, coragem acima do ranking.'
        'Garou'       = 'O caçador de heróis humano, quer virar o monstro absoluto.'
    }
    'Run with the Wind (Kaze ga Tsuyoku Fuiteiru)' = @{
        'Haiji Kiyose'    = 'A mente por trás do ekiden, transforma dez vizinhos em corredores.'
        'Kakeru Kurahara' = 'O talento fugitivo que reencontra o próprio ritmo nas pistas.'
        'Prince'          = 'O otaku do apartamento que troca o sofá pelo asfalto.'
    }
    'Servamp' = @{
        'Mahiru Shirota' = 'O estudante da vida simples que leva o gato preto para casa.'
        'Kuro'           = 'O Sleepy Ash, o servamp mais preguiçoso, escondido no próprio passado.'
        'Tsubaki'        = 'O servamp da loucura, persegue os próprios irmãos com caos.'
        'Misono Alicein' = 'O mestre do Snow Lily, franzino e apegado às próprias regras.'
    }
    'Solo Leveling (Ore dake Level Up na Ken)' = @{
        'Sung Jin-woo' = 'O caçador mais fraco que desperta um sistema só dele: subir de nível.'
        'Cha Hae-in'   = 'A espadachina classe S, silenciosa e implacável nas dungeons.'
    }
    'Soul Eater' = @{
        'Maka Albarn'      = 'A técnica exemplar que empunha a foice Soul com cérebro e coragem.'
        'Soul Eater Evans' = 'A foice espinhosa de Maka, arrogante por fora e leal por dentro.'
        'Black☆Star'       = 'O ninja barulhento que quer superar os próprios deuses.'
        'Death the Kid'    = 'O herdeiro de Shinigami, obcecado por simetria perfeita.'
    }
    'Spy x Family' = @{
        'Anya Forger'  = 'A pequena telepata que sabe todos os segredos da família.'
        'Loid Forger'  = 'O espião Twilight, monta uma família falsa para uma missão impossível.'
        'Yor Forger'   = 'A Princesa Espinho: assassina noturna em dia de secretária comum.'
        'Yuri Briar'   = 'Irmão da Yor e agente da SSS, adora a própria irmã.'
    }
    'Tengen Toppa Gurren Lagann' = @{
        'Kamina' = 'O líder do Gurren-dan, crê no irmão Simon e perfura o céu.'
        'Simon'  = 'O perfurador tímido que herda a broca e as palavras de Kamina.'
    }
    'The Summer Hikaru Died (Hikaru ga Shinda Natsu)' = @{
        'Yoshiki'   = 'O amigo que protege o Hikaru que voltou.'
        '"Hikaru"'  = 'A criatura da montanha que veste o corpo do amigo morto.'
        'Tanaka'    = 'A vizinha curiosa que investiga o ritual local.'
    }
    'Tokyo Ghoul:re' = @{
        'Haise Sasaki' = 'O mentor do Quinx com outro nome, caça o próprio passado esquecido.'
        'Ken Kaneki'   = 'O Rei de Um Olho, ghoul entre dois mundos de medo e afeto.'
        'Kuki Urie'    = 'O Quinx ambicioso, sobe de posto questionando os próprios limites.'
        'Kisho Arima'  = 'O Ceifador da CCG, caçador lendário e imbatível.'
    }
    'Toilet-Bound Hanako-kun (Jibaku Shounen Hanako-kun)' = @{
        'Hanako-kun'    = 'O sétimo mistério do banheiro feminino e guardião da escola.'
        'Nene Yashiro'  = 'A assistente humana apaixonada por príncipes.'
        'Kou Minamoto'  = 'O exorcista novato da família Minamoto, amigo leal dos dois.'
    }
    'Witch Hat Atelier (Tongari Boushi no Atelier)' = @{
        'Coco'   = 'A aprendiz que descobre que toda magia é desenho.'
        'Qifrey' = 'O mestre do ateliê, bruxo atento com segredos próprios.'
        'Agott'  = 'A aprendiz talentosa e reservada, orgulhosa do próprio traço.'
    }
    'xxxHOLiC' = @{
        'Yuko Ichihara'     = 'A dona da loja dos desejos, cobra o preço justo de cada pedido.'
        'Kimihiro Watanuki' = 'O garoto que vê espíritos e trabalha para pagar o próprio desejo.'
        'Shizuka Doumeki'   = 'O arqueiro silencioso que derruba o que Watanuki não vê.'
    }
    'xxxHOLiC Rei' = @{
        'Kimihiro Watanuki' = 'O dono da loja, herdeiro dos desejos cobrados.'
        'Shizuka Doumeki'   = 'O arqueiro fiel que protege a loja.'
        'Yuko Ichihara'     = 'A dona ausente da loja, presente em cada detalhe.'
    }
    'Yu Yu Hakusho' = @{
        'Yusuke Urameshi' = 'O delinquente de escola que morre salvando uma criança.'
        'Kazuma Kuwabara' = 'O rival leal com espírito-espada e coração grande.'
        'Hiei'            = 'O espadachim veloz do olho rubro, frio por fora e irmão fiel.'
        'Kurama'          = 'A raposa demoníaca renascida em humano, estrategista calculista.'
        'Younger Toguro'  = 'A força das trevas encarnada, ex-atleta que escolheu o medo.'
    }
    # ---- Lote 3 (v0.9.3) ----------------------------------------------------
    'Another' = @{
        'Mei Misaki'        = 'A aluna de olho-muñeca que enxerga o inelutável e é tratada como inexistente.'
        'Koichi Sakakibara' = 'O transferido da turma 3-3 que se recusa a fingir que ninguém existe.'
        'Reiko Mikami'      = 'Tia e conselheira severa de Mei sobre a maldição da classe.'
    }
    'Astro Boy (Tetsuwan Atom)' = @{
        'Astro Boy'    = 'O menino-robô criado no lugar de Tobio, guardião do céu azul.'
        'Dr. Tenma'    = 'O cientista que criou Astro e o rejeitou por não crescer como humano.'
        'Dr. Ochanomizu' = 'O cientista bondoso que resgata Astro e crê na convivência das duas espécies.'
        'Uran'         = 'A irmãzinha robô, destemida e apegada ao irmão.'
    }
    'Black Torch' = @{
        'Jiro Azuma'        = 'O jovem que entende a voz dos animais e acolhe o mononoke Rago.'
        'Rago'              = 'Mononoke milenar de fogo, preso na forma de gatinho fogoso.'
        'Ichika Kishimojin' = 'Capitã dos shinobi da Black Torch, caça os kaii que rompem a ordem.'
        'Reiji Kirihara'    = 'Shinobi veterano severo, dono das regras de sangue da equipe.'
    }
    'Bungou Stray Dogs' = @{
        'Osamu Dazai'          = 'Ex-executor da Port Mafia, charlatão suicida e gênio tático da Agência.'
        'Atsushi Nakajima'     = 'O tigre branco órfão que aprende, na Agência, a querer viver.'
        'Ryunosuke Akutagawa'  = 'A espada negra da Port Mafia, sedento pelo reconhecimento de Dazai.'
        'Chuya Nakahara'       = 'O ex-parceiro de Dazai, dono da gravidade como arma e do orgulho como manto.'
        'Sakunosuke Oda'       = 'O soldado de baixo escalão que deseja, antes de tudo, salvar os órfãos.'
    }
    'Dorohedoro' = @{
        'Caiman'  = 'O caçador de cabeça de jacaré, vive no buraco da própria maldição.'
        'Nikaido' = 'Dona do restaurante e da magia mais poderosa, parceira incondicional de Caiman.'
        'En'      = 'O chefão feiticeiro dos cogumelos, que protege a própria família.'
        'Shin'    = 'Feiticeiro da máscara-caveira, despede inimigos com o martelo.'
        'Noi'     = 'A feiticeira gigante da cura, sempre de bom humor na pancadaria.'
    }
    'Erased (Boku dake ga Inai Machi)' = @{
        'Satoru Fujinuma' = 'O mangaká que volta no tempo para salvar quem está morrendo.'
        'Kayo Hinazuki'   = 'A menina-alvo do abdutor, primeira vida que Satoru jura salvar.'
        'Sachiko Fujinuma' = 'A mãe jornalista que lê a verdade nas pequenas coisas.'
        'Gaku Yashiro'    = 'O professor genial que deseja, acima de tudo, ser derrotado.'
    }
    'Fate/stay night' = @{
        'Saber'         = 'O Servo Saber: a restante Artoria Pendragon, rei de Camelot.'
        'Shirou Emiya'  = 'O sobrevivente que herda de Kiritsugu o ideal de ser herói.'
        'Archer'        = 'O Servo de lâminas que veio de um futuro de erros ajustados.'
        'Gilgamesh'     = 'O Rei dos Heróis de Uruk, dono de todos os tesouros.'
        'Rin Tohsaka'   = 'A segunda geração dos Tohsaka, talentosa e exigente consigo.'
        'Kirei Kotomine' = 'O sacerdote supervisionador que busca o próprio vazio.'
    }
    'Fruits Basket' = @{
        'Tohru Honda'    = 'A órfã radiante que leva luz à casa amaldiçoada dos Sohma.'
        'Kyo Sohma'      = 'O gato exilado do zodíaco, raiva e ternura no mesmo peito.'
        'Yuki Sohma'     = 'O príncipe da escola que busca um lugar onde ninguém exija perfeição.'
        'Shigure Sohma'  = 'O cão do zodíaco: escritor leviano por fora, estrategista por dentro.'
    }
    'GOSICK' = @{
        'Victorique de Blois' = 'A pequena detetive dourada que refaz o caos em verdade.'
        'Kazuya Kujo'         = 'O estudante japonês que se torna baluarte de Victorique.'
        'Cordelia Gallo'      = 'A mãe que liberta a filha da vila cinzenta com o próprio amor.'
    }
    'Hell''s Paradise (Jigokuraku)' = @{
        'Gabimaru'                = 'O ninja letal de Iwagakure que quer voltar vivo para a esposa.'
        'Sagiri Yamada Asaemon'   = 'A executora que lê corações — e a dúvida — na própria lâmina.'
        'Yuzuriha'                = 'A kunoichi de vida agarrada, que mostra a própria humanidade na ilha.'
        'Chobe Aza'               = 'O brigão canibal irmão de Toma, guiado só pelo próprio punho.'
    }
    'Innocent' = @{
        'Charles-Henri Sanson'  = 'O carrasco de Paris que humaniza a guilhotina como misericórdia.'
        'Marie-Joseph Sanson'   = 'A irmã que empunha a mesma lâmina como revolta própria.'
    }
    'InuYasha' = @{
        'InuYasha'          = 'O meio-youkai da Tessaiga, protetor bruto e fiel de Kagome.'
        'Kagome Higurashi'  = 'A garota vinda do poço, portadora da Jóia de Shikon.'
        'Sesshomaru'        = 'O youkai completo elegante, que trilha o próprio caminho.'
        'Kikyo'             = 'A sacerdotisa ressuscitada em barro e rancor.'
        'Naraku'            = 'O demônio tecido de malícia humana, aranha nas sombras.'
    }
    'Jigoku Shoujo (Hell Girl)' = @{
        'Ai Enma'     = 'A garota do inferno: recebe o ódio e enterra os dois lados.'
        'Ren Ichimoku' = 'O servo de olhos nas ruínas, que lê a fragilidade humana.'
        'Hone Onna'   = 'A serva óssea de Ai, cronista dos ódios levados ao inferno.'
    }
    'Kamisama Hajimemashita (Kamisama Kiss)' = @{
        'Nanami Momozono' = 'A ex-desabrigada que vira deusa de terra do templo esquecido.'
        'Tomoe'           = 'O youkai-raposa familiar, braço e coração do templo.'
        'Mizuki'          = 'O youkai-serpente branco, devoto eterno de Nanami.'
        'Kurama Shinjuro' = 'O youkai-pássaro idol, o anjo caído do rock.'
    }
    'Kekkai Sensen (Blood Blockade Battlefront)' = @{
        'Leonardo Watch'       = 'O novato dono dos Olhos Que Tudo Veem dos Deuses.'
        'Klaus Von Reinherz'   = 'O gigante que lidera a Libra com punhos e fé na luz.'
        'Zapp Renfro'          = 'O parceiro barulhento de Leonardo, mestre das técnicas de sangue.'
        'Steven A. Starphase'  = 'O vice elegante de Klaus, que encerra a diplomacia congelando tudo.'
    }
    'Lili-Men' = @{
        'Nito'     = 'O abrigado que viu os amigos serem mortos e agora caça succubi pela Seção S.'
        'Kurogane' = 'O chefe implacável da Seção S, que mata succubi antes de nascerem.'
        'Unno'     = 'A arqueira do sangue pegajoso, vice-comandante da unidade Mochizuki.'
    }
    'Love Bullet' = @{
        'Koharu' = 'A cupido nova que carrega revólver para fazer o amor florescer.'
        'Chiyo'  = 'A cupido veterana que calibra a paixão com a própria bala.'
        'Ena'    = 'A cupido sniper que não admite um milímetro de falha.'
    }
    'Mashle: Magic and Muscles' = @{
        'Mash Burnedead'  = 'O aluno sem magia que derrota encantamentos com músculos e disciplina.'
        'Regro Burnedead' = 'O pai adotivo que escondeu e criou Mash com carinho.'
        'Lance Crown'     = 'O gênio da geomancia obcecado pela própria irmã.'
        'Dot Barrett'     = 'O autoproclamado protagonista, rival tolo e leal de Mash.'
    }
    'Mato Seihei no Slave (Chained Soldier)' = @{
        'Kyouka Uzen'  = 'A capitã do 7º Esquadrão, que monta e liberta o poder de Yuuki.'
        'Yuuki Wakura' = 'O escravo da capitã que se torna escudo dos inocentes.'
        'Himari Azuma' = 'A vice exigente que mede o mérito pelo próprio esforço.'
        'Tenka Izumo'  = 'A capitã carismática rival, que torce para levá-lo ao próprio time.'
    }
    'Medalist' = @{
        'Inori Yuitsuka'  = 'A aluna tardia da patinação que sonha em brilhar no pódio.'
        'Tsukasa Akeuraji' = 'O instrutor que troca a própria vida pelo sonho da aluna.'
        'Hikaru Kamisaki' = 'O talento nato do gelo, rival pura e impiedosa.'
    }
    'Mermaid Saga (Ningyo Series)' = @{
        'Yuta' = 'O imortal que procura a sereia capaz de devolver sua morte.'
        'Mana' = 'A menina que partilha a carne de sereia e a viagem com Yuta.'
        'Rin'  = 'A mulher que troca a velhice pela beleza eterna e apodrecida.'
    }
    'Mission: Yozakura Family (Yozakura-san Chi no Daisakusen)' = @{
        'Taiyo Asano'         = 'O rapaz comum que entra na família-espionagem para proteger Mutsumi.'
        'Mutsumi Yozakura'    = 'A cabeça gentil da família Yozakura, coração do grupo.'
        'Kyoichiro Yozakura'  = 'O irmão devastador e devoto de Mutsumi, dono dos fios.'
        'Shion Yozakura'      = 'A irmã hacker que intercepta dados e alvos.'
    }
    'Natsume Yuujinchou (Natsume''s Book of Friends)' = @{
        'Takashi Natsume'  = 'O garoto que vê youkais e devolve os nomes roubados.'
        'Nyanko-sensei'    = 'O youkai felino, guardião cômico e ganancioso do Livro dos Amigos.'
        'Reiko Natsume'    = 'A avó que criou o Livro dos Amigos colecionando nomes.'
    }
    'Nue''s Exorcist (Nue no Onmyouji)' = @{
        'Gakuro Yajima'   = 'O aluno que troca o armário do medo pela espada do colégio.'
        'Nue'             = 'O youkai lendário pactuado com Gakuro por um jogo.'
        'Shiroha Fujino'  = 'A exorcista fria da família Fujino, lâmina sem hesitação.'
    }
    'Orange' = @{
        'Naho Takamiya'  = 'A aluna que recebe cartas do futuro para salvar Kakeru.'
        'Kakeru Naruse'  = 'O transferido em luto, salvo pela coragem de todos.'
        'Hiroto Suwa'    = 'O amigo que abre mão do próprio amor para salvar o amigo.'
    }
    'Ragna Crimson' = @{
        'Ragna'     = 'O caçador silencioso que herda o poder e a dor do próprio eu futuro.'
        'Crimson'   = 'O estrategista que mira só a cabeça do Rei dos Dragões.'
        'Leonica'   = 'A parceira de caça de Ragna, a razão da sua força.'
        'Ultimatia' = 'A rainha dos dragões que concede o tempo como esmola.'
    }
    'RG Veda (Seiden: RG Veda)' = @{
        'Yasha-oh'      = 'O senhor Yasha que acolhe Ashura e desafia o trono.'
        'Ashura'        = 'A estrela selada da profecia, capaz de incendiar os Seis Mundos.'
        'Taishakuten'   = 'O imperador usurpador que derrubou Ashura-oh.'
        'Kujaku'        = 'O andarilho misterioso que tece os fios do destino.'
        'Kendappa-oh'   = 'O rei-músico fiel ao próprio amado.'
    }
    'RuriDragon' = @{
        'Ruri Aoki'   = 'A colegial meia-dragão que leva chifres e chamas no dia a dia.'
        'Mãe da Ruri' = 'A mãe serena que trata a herança dragão como notícia comum.'
        'Yuka Maeda'  = 'A amiga próxima que acha os chifres até bonitos.'
    }
    'Sakamoto Days' = @{
        'Taro Sakamoto' = 'O lendário assassino virado dono de mercadinho de família.'
        'Shin Asakura'  = 'O telepata fiel que lê mentes — menos a do chefe.'
        'Lu Xiaotang'   = 'A herdeira chinesa que briga melhor bebendo.'
        'Nagumo'        = 'O assassino camaleão da Ordem, mestre das máscaras.'
    }
    'Tasogare Otome x Amnesia (Dusk Maiden of Amnesia)' = @{
        'Yuko Kanoe'   = 'A fantasma elegante que quer desvendar a própria morte.'
        'Teiichi Niiya' = 'O aluno que se apaixona por uma fantasma e recupera suas memórias.'
        'Kirie Kanoe'  = 'A parente distante que teme o preço dos laços com os vivos.'
    }
    'Tenmaku no Jaadugar' = @{
        'Fatima'   = 'A sábia cativa que arma a própria liberdade com tinta e livros.'
        'Toregene' = 'A imperatriz na sombra que governa pela ambição dos homens.'
    }
    'The Promised Neverland (Yakusoku no Neverland)' = @{
        'Emma'     = 'A órfã de coração imenso que jura levar todos para fora.'
        'Norman'   = 'O gênio do orfanato que ama Emma e planeja com ela.'
        'Ray'      = 'O estrategista seco que se recusa a ser alimentação.'
        'Isabella' = 'A mãe do orfanato: ama os filhos e serve ao abismo.'
    }
    'The Saga of Tanya the Evil (Youjo Senki)' = @{
        'Tanya von Degurechaff'            = 'A soldada prodígio que declara guerra ao próprio deus.'
        'Viktoriya Ivanovna Serebryakov'   = 'A tenente devota de Tanya, fiel até a trincheira.'
    }
    'Ultimate Exorcist Kiyoshi (Exorcist no Kiyoshi-kun)' = @{
        'Kiyoshi Harai' = 'O exorcista poderoso demais para a vida escolar comum.'
        'Rei Demônio'   = 'O demônio pai de Kiyoshi, que cobra a herança de sangue.'
        'Tsurugi'       = 'O companheiro franco, que admira o desequilíbrio de Kiyoshi.'
    }
    'Undead Unluck' = @{
        'Andy'         = 'O morto-vivo que busca a melhor morte como se fosse presente.'
        'Fuuko Izumo'  = 'A garota da má-sorte letal que aprende a usá-la com coragem.'
        'Victor'       = 'O ser que atravessou eras de loops sádicos de Deus.'
        'Juiz'         = 'A líder da União que nega as regras cruéis do mundo.'
    }
    'Vampire Hunter D' = @{
        'D'            = 'O dhampir caçador da fronteira, metade humano e metade nobreza.'
        'Mão Esquerda' = 'A mão falante de D, sarcástica e fiel à caçada.'
        'Meier Link'   = 'O nobre vampiro que cruza eras por Charlotte.'
    }
    'Wind Breaker' = @{
        'Haruka Sakura'      = 'O garoto sozinho que tenta o topo apenas com os punhos.'
        'Hajime Umemiya'     = 'O líder da Furin que protege a cidade com o próprio corpo.'
        'Akihiko Nirei'      = 'O arquivista sem punhos que registra a bravura dos amigos.'
        'Kyotaro Sugishita'  = 'O gigante devoto de Umemiya, fiel as ordens dele.'
    }
    'Zatch Bell! (Konjiki no Gash Bell!)' = @{
        'Zatch Bell'   = 'O demônio dourado que quer ser um rei bondoso.'
        'Kiyo Takamine' = 'O estudante que lê o livro do Zatch e vira parceiro de batalha.'
        'Brago'        = 'O demônio arrogante da gravidade, rival leal de Sherry.'
        'Folgore'      = 'O ídolo italiano escandaloso que dá risada — e protege o demônio.'
        'Sherry Belmont' = 'A mestra aristocrática de Brago, que briga pelo amigo cego.'
    }
    # ---- Lote 4 (v0.9.3) ----------------------------------------------------
    'Black Clover' = @{
        'Asta'                  = 'O camponês sem magia que disputa o trono de Rei Mago pela obstinação.'
        'Yami Sukehiro'         = 'O capitão do Touro Negro, imigrante com espada de trevas e conselhos brutais.'
        'Yuno Grinberryall'     = 'O prodígio do vento, rival leal e herdeiro real.'
        'Julius Novachrono'     = 'O Rei Mago apaixonado pelo futuro e pelas magias ainda desconhecidas.'
        'Noelle Silva'          = 'A realeza da Casa Silva que domina a água contra os próprios complexos.'
        'Mereoleona Vermillion' = 'A leonina dos Vermillion, que queima herança com o próprio fogo.'
    }
    'Digimon Adventure' = @{
        'Taichi Yagami' = 'O líder corajoso das crianças escolhidas.'
        'Agumon'        = 'O parceiro-lagarto de Taichi, coragem em digivoluções de fogo.'
        'Yamato Ishida' = 'O lobo solitário do grupo, que aprende a confiar.'
        'Gabumon'       = 'O parceiro tímido de Yamato, fiel pelo mundo inteiro.'
        'Angemon'       = 'O anjo alado que protege a esperança até encontrá-la.'
    }
    'Elfen Lied' = @{
        'Lucy'  = 'A diclonius que aprendeu crueldade pelas mãos dos humanos.'
        'Nyu'   = 'A persona infantil de Lucy, nascida de um trauma.'
        'Kouta' = 'O sobrevivente do passado que abraça a dor de Lucy.'
        'Nana'  = 'A diclonius gentil, devota ao próprio "papai".'
    }
    'Kengan Ashura' = @{
        'Ohma Tokita'     = 'O lutador errante que vive de verdade dentro do ringue.'
        'Kuroki Gensai'   = 'O karateca que lapida o próprio punho até a sepultura.'
        'Kazuo Yamashita' = 'O funcionário comum que se torna gerente e voz de Ohma.'
        'Raian Kure'      = 'O assassino dos Kure, que ri de regras e cortes.'
    }
    'Pokémon' = @{
        'Ash Ketchum'           = 'O treinador eterno de Pallet atrás do título de Mestre Pokémon.'
        'Mewtwo'                = 'O clone lendário que questiona o valor de ter sido criado.'
        'Jessie, James & Meowth' = 'A Equipe Rocket: o trio teatral que persegue Pikachu.'
        'Meowth'                = 'O gato que aprendeu a falar — e a ver o mesmo céu.'
    }
    'ReLIFE' = @{
        'Arata Kaizaki'  = 'O adulto que recomeça o colégio como experimento pago.'
        'Chizuru Hishiro' = 'A aluna de excelência que aprende, palavra por palavra, a sorrir.'
        'Ryo Yoake'      = 'O observador do experimento que apoia com paciência e carinho.'
    }
    'Shuumatsu no Valkyrie (Record of Ragnarok)' = @{
        'Brunhilde'         = 'A valquíria que aposta a humanidade contra os deuses.'
        'Kojiro Sasaki'     = 'O espadachim que perdeu toda a vida e venceu o lugar mais alto.'
        'Adam (Adão)'       = 'O primeiro pai da humanidade, que abraça qualquer golpe pela família.'
        'Jack, o Estripador' = 'O humano mais odiado da história, que pinta o próprio horror.'
        'Lu Bu'             = 'O invencível dos três reinos, atrás de um oponente digno.'
        'Qin Shi Huang'     = 'O primeiro imperador que corta o próprio caminho.'
    }
}


# ---------------------------------------------------------------------------
# Utilitarios
# ---------------------------------------------------------------------------
function Get-Slug([string]$name) {
    # fold diacriticos
    $formD = $name.Normalize([System.Text.NormalizationForm]::FormD)
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $formD.ToCharArray()) {
        if ([System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch) -ne [System.Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$sb.Append($ch)
        }
    }
    $folded = $sb.ToString().Normalize([System.Text.NormalizationForm]::FormC).ToLowerInvariant()
    # ponto colado entre letras some (C.C. -> cc); ponto com espaco vira separador (Dr. Hiriluk)
    $folded = $folded -replace '(?<=\w)\.(?=\w)', ''
    $folded = $folded -replace '[^a-z0-9]+', '-'
    return $folded.Trim('-')
}

function Derive-First([object[]]$charQuotes) {
    # primeira aparencia do personagem: menor Cap. (manga) e menor Ep. (anime)
    # "Ep. N (Tn)" compara por temporada; poemas ("Poema do Vol. N") sao ignorados
    $firstCap = $null
    $best = $null
    foreach ($q in $charQuotes) {
        if ($null -eq $q.episode) { continue }
        $e = [string]$q.episode
        if ($e -like 'Poema do Vol.*') { continue }
        if ($e -match 'Cap\.\s*(\d+)') {
            $v = [int]$Matches[1]
            if ($null -eq $firstCap -or $v -lt $firstCap) { $firstCap = $v }
        }
        $m = [regex]::Match($e, '(?i)Ep\.\s*(\d+)(?:\s*\(T(\d+)\))?')
        if ($m.Success) {
            $nEp = [int]$m.Groups[1].Value
            $nSe = 1
            if ($m.Groups[2].Success) { $nSe = [int]$m.Groups[2].Value }
            $better = ($null -eq $best) -or ($nSe -lt $best.Season) -or (($nSe -eq $best.Season) -and ($nEp -lt $best.Episode))
            if ($better) { $best = [PSCustomObject]@{ Season = $nSe; Episode = $nEp } }
        }
    }
    $res = @{ firstChapter = $firstCap; firstEpisode = $null; firstEpisodeSeason = $null }
    if ($null -ne $best) {
        $res.firstEpisode = $best.Episode
        if ($best.Season -gt 1) { $res.firstEpisodeSeason = $best.Season }
    }
    return $res
}

function Normalize-Episode([string]$raw, [bool]$isPoem, [string]$vol) {
    if ($isPoem) {
        return @{ episode = "Poema do Vol. $vol"; review = $false }
    }
    $e = $raw.Trim()
    $review = $false
    if ($e -match 'não confirmado') {
        $review = $true
        $e = $e -replace 'Cap\.\s*não confirmado\s*/\s*', ''
        $e = $e -replace '\s*/\s*Cap\.\s*não confirmado', ''
        $e = $e -replace '\s*não confirmado\s*', ' '
        $e = $e.Trim(' ', '/')
        $e = $e -replace '\s+\)', ')'
        $e = $e -replace '\(\s+', '('
        $e = $e -replace '\s{2,}', ' '
        if ($e -eq '') { $e = $null }
    } elseif ($e -eq '') {
        $e = $null
    }
    return @{ episode = $e; review = $review }
}

# ---------------------------------------------------------------------------
# Parse do .md
# ---------------------------------------------------------------------------
$works = New-Object System.Collections.Generic.List[object]
$totalQuotes = 0
$reviewCount = 0
$seenTitles = @{}

foreach ($MdPath in $MdPaths) {
if (-not (Test-Path $MdPath)) { throw "Arquivo nao encontrado: $MdPath" }
$md = [System.IO.File]::ReadAllText($MdPath, [System.Text.Encoding]::UTF8)
$lines = $md -split "`r?`n"

# secoes ## na ordem do arquivo
$sections = New-Object System.Collections.Generic.List[object]
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^##\s+(.+?)\s*$') {
        $sections.Add([PSCustomObject]@{ Title = $Matches[1]; Start = $i })
    }
}

foreach ($secIdx in 0..($sections.Count - 1)) {
    $sec = $sections[$secIdx]
    $title = $sec.Title
    if (-not $WorksMeta.Contains($title)) {
        if ($title -like 'Itens a verificar*' -or $title -like 'Índice*') { continue }
        throw "Secao sem metadados: [$title]"
    }
    if ($seenTitles.ContainsKey($title)) { throw "Secao [$title] duplicada entre os arquivos de tools/source/. Mantenha apenas uma versao de cada obra." }
    $seenTitles[$title] = $true
    $meta = $WorksMeta[$title]
    $end = if ($secIdx -lt $sections.Count - 1) { $sections[$secIdx + 1].Start } else { $lines.Count }

    # personagens em ordem de primeira aparencia; quotes por personagem
    $charOrder = New-Object System.Collections.Generic.List[string]
    $rawNameByChar = @{}   # nome final -> primeiro nome bruto visto
    $quotesByChar = @{}    # nome final -> List[quote]

    for ($i = $sec.Start + 1; $i -lt $end; $i++) {
        $l = $lines[$i].Trim()
        if (-not $l.StartsWith('|')) { continue }
        if ($l -match 'Personagem' -or $l -match '^Vol\s') { continue }   # header
        if ($l -match '^[\|\s\-:]+$') { continue }                        # separator
        # unescape de \~ e \# nas celulas (lote 4 usa cabeçalho '\#', romaji usa '\~')
        $cells = (($l.Trim('|') -split '\|') | ForEach-Object { $_.Trim() }) | ForEach-Object { ($_ -replace '\\([~#])', '$1') }

        $isPoem = $false; $vol = $null
        if ($cells.Count -eq 6) {
            $rawName = $cells[1]; $text = $cells[2]; $kanji = $cells[3]; $romaji = $cells[4]; $epRaw = $cells[5]
        } elseif ($cells.Count -eq 5) {
            $isPoem = $true; $vol = $cells[0]; $rawName = $cells[1]; $text = $cells[2]; $kanji = $cells[3]; $romaji = $cells[4]; $epRaw = ''
        } else {
            throw "Linha inesperada ($($cells.Count) colunas) na secao [$title], linha $($i+1): $l"
        }
        if ($rawName -eq '' -or $text -eq '') { throw "Celula vazia na secao [$title], linha $($i+1): $l" }

        $name = $rawName
        if ($Renames.ContainsKey($rawName)) { $name = $Renames[$rawName] }

        if (-not $quotesByChar.ContainsKey($name)) {
            $charOrder.Add($name)
            $rawNameByChar[$name] = $rawName
            $quotesByChar[$name] = New-Object System.Collections.Generic.List[object]
        }

        $ep = Normalize-Episode -raw $epRaw -isPoem $isPoem -vol $vol
        $context = $null
        if ($isPoem) {
            $context = "Poema de abertura do volume $vol do mangá."
            if ($VariantContexts.ContainsKey($rawName)) {
                $context = "Poema de abertura do volume $vol do mangá ($($VariantContexts[$rawName]))."
            }
        } elseif ($VariantContexts.ContainsKey($rawName)) {
            $context = $VariantContexts[$rawName]
        } elseif ($ExtraQuoteContexts.ContainsKey($title) -and $ExtraQuoteContexts[$title].ContainsKey($kanji)) {
            $context = $ExtraQuoteContexts[$title][$kanji]
        }
        if ($ep.review) { $reviewCount++ }

        $quotesByChar[$name].Add([PSCustomObject]@{
            text         = $text
            textOriginal = if ($romaji -eq '') { $null } else { $romaji }
            textJapanese = if ($kanji -eq '') { $null } else { $kanji }
            episode      = $ep.episode
            context      = $context
            review       = [bool]$ep.review
        })
        $totalQuotes++
    }

    # monta personagens (valida slug unico por obra)
    $seenSlugs = @{}
    $characters = New-Object System.Collections.Generic.List[object]
    foreach ($name in $charOrder) {
        $slug = Get-Slug $name
        if ($slug -eq '') { throw "Slug vazio para [$name] em [$title]" }
        if ($seenSlugs.ContainsKey($slug)) { throw "Slug duplicado [$slug] em [$title]" }
        $seenSlugs[$slug] = $true

        $nameOriginal = $null
        if ($NameOriginals.ContainsKey($name)) { $nameOriginal = $NameOriginals[$name] }
        # descricao: mapa per-work da obra tem precedencia sobre o global
        # (evita colisoes de nomes iguais entre obras, ex. Sunny de OMORI/Toriko)
        $description = $null
        if ($WorkCharDescriptions.Contains($title) -and $WorkCharDescriptions[$title].ContainsKey($name)) {
            $description = $WorkCharDescriptions[$title][$name]
        } elseif ($CharDescriptions.ContainsKey($name)) { $description = $CharDescriptions[$name] }

        $first = Derive-First $quotesByChar[$name].ToArray()
        $characters.Add([PSCustomObject]@{
            slug               = $slug
            name               = $name
            nameOriginal       = $nameOriginal
            arc                = $null
            description        = $description
            firstChapter       = $first.firstChapter
            firstEpisode       = $first.firstEpisode
            firstEpisodeSeason = $first.firstEpisodeSeason
            quotes             = [object[]]$quotesByChar[$name].ToArray()
        })
    }

    $works.Add([PSCustomObject]@{
        slug          = $meta.slug
        title         = $meta.title
        titleOriginal = $meta.titleOriginal
        year          = $meta.year
        description   = $meta.description
        accentColor   = $meta.accentColor
        characters    = [object[]]$characters.ToArray()
    })
}
} # fim do loop de arquivos

# ---------------------------------------------------------------------------
# Validacoes
# ---------------------------------------------------------------------------
if ($works.Count -ne $WorksMeta.Count) { throw "Esperava $($WorksMeta.Count) obras, obtive $($works.Count)" }
$totalChars = ($works | ForEach-Object { $_.characters.Count } | Measure-Object -Sum).Sum
Write-Host "Obras: $($works.Count) | Personagens: $totalChars | Frases: $totalQuotes | review:true: $reviewCount"
foreach ($w in $works) {
    Write-Host ("  {0,-24} {1,-28} chars={2,3} quotes={3,3}" -f $w.slug, $w.title, $w.characters.Count, ($w.characters | ForEach-Object { $_.quotes.Count } | Measure-Object -Sum).Sum)
}

# ---------------------------------------------------------------------------
# Escrita do JSON (UTF-8 sem BOM)
# ---------------------------------------------------------------------------
$root = [PSCustomObject]@{
    schemaVersion = 1
    _note         = "Authoring-only fields: 'review' (boolean) marks quotes/statement details to double-check before release. The E1 parser must ignore unknown fields."
    works         = [object[]]$works.ToArray()
}
$json = $root | ConvertTo-Json -Depth 10
$outFull = [System.IO.Path]::GetFullPath($OutPath)
$dir = Split-Path $outFull -Parent
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
[System.IO.File]::WriteAllText($outFull, $json, (New-Object System.Text.UTF8Encoding($false)))

# round-trip
$back = [System.IO.File]::ReadAllText($outFull, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
$backQuotes = 0
foreach ($w in $back.works) { foreach ($c in $w.characters) { $backQuotes += $c.quotes.Count } }
Write-Host "JSON gravado em $outFull (round-trip OK: $($back.works.Count) obras, $backQuotes frases)"
