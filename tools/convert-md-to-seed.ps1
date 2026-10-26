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
#   - textOriginal = romaji (o kanji do .md fica de fora; recurso futuro).
#   - Episode com "nao confirmado" -> normalizado + review:true (flag authoring,
#     ignorada pelo parser Kotlin).
#   - Variantes de personagem agrupadas (mapa $Renames abaixo).
#   - nameOriginal preenchido apenas para nomes ja validados no seed v1.

param(
    [string]$MdPath = "$PSScriptRoot\source\coletanea-frases.md",
    [string]$OutPath = "$PSScriptRoot\..\app\src\main\assets\seed\app_data.json"
)

$ErrorActionPreference = 'Stop'

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
    'Kanki (Huan Yi)'                 = 'Kanki'
    'Shin (Li Xin)'                   = 'Shin'
    'Wang Qi (Ou Ki)'                 = 'Wang Qi'
    'Esfera Negra (Gantz)'            = 'Gantz'
    'Gogeta (Super Saiyajin 4)'       = 'Gogeta'
    'Narrador (Final)'                = 'Narrador'
    'Shigeo Kageyama (Mob)'           = 'Shigeo Kageyama'
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
    'Ergo Proxy'                = 'O Proxy criador, agente do caos e da criação.'
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
    'Kanki'                     = 'General implacável, ex-bandido com táticas cruéis.'
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

$works = New-Object System.Collections.Generic.List[object]
$totalQuotes = 0
$reviewCount = 0

foreach ($secIdx in 0..($sections.Count - 1)) {
    $sec = $sections[$secIdx]
    $title = $sec.Title
    if (-not $WorksMeta.Contains($title)) {
        if ($title -like 'Itens a verificar*' -or $title -like 'Índice*') { continue }
        throw "Secao sem metadados: [$title]"
    }
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
        $cells = ($l.Trim('|') -split '\|') | ForEach-Object { $_.Trim() }

        $isPoem = $false; $vol = $null
        if ($cells.Count -eq 6) {
            $rawName = $cells[1]; $text = $cells[2]; $romaji = $cells[4]; $epRaw = $cells[5]
        } elseif ($cells.Count -eq 5) {
            $isPoem = $true; $vol = $cells[0]; $rawName = $cells[1]; $text = $cells[2]; $romaji = $cells[4]; $epRaw = ''
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
        }
        if ($ep.review) { $reviewCount++ }

        $quotesByChar[$name].Add([PSCustomObject]@{
            text         = $text
            textOriginal = if ($romaji -eq '') { $null } else { $romaji }
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
        $description = $null
        if ($CharDescriptions.ContainsKey($name)) { $description = $CharDescriptions[$name] }

        $characters.Add([PSCustomObject]@{
            slug         = $slug
            name         = $name
            nameOriginal = $nameOriginal
            arc          = $null
            description  = $description
            quotes       = [object[]]$quotesByChar[$name].ToArray()
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
