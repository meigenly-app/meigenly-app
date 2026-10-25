# Meigenly

App Android nativo de leitura offline de frases de animes, organizadas como um app de Bíblia:
**Obra → Personagem → Frase**, com leitor de tela cheia e swipe, busca com full-text search,
favoritos, histórico, compartilhamento (texto/imagem), tema claro/escuro e frase do dia
(notificação opcional).

100% offline: sem backend, sem contas, sem sincronia na nuvem. Todo o conteúdo vem embutido
no APK (`app/src/main/assets/seed/app_data.json`).

## Stack

| Componente | Versão |
|---|---|
| Kotlin | 2.1.0 |
| AGP / Gradle | 8.7.3 / 8.11.1 |
| Jetpack Compose (BOM) | 2024.12.01 |
| Room | 2.6.1 (FTS, schema versionado em `app/schemas/`) |
| Hilt | 2.56.2 (+ androidx.hilt 1.2.0 para WorkManager) |
| DataStore | 1.1.1 (tema + toggle de notificação) |
| WorkManager | 2.9.1 (frase do dia) |
| JDK de build | Temurin 21 (`org.gradle.java.home` em `gradle.properties`) |

## Como rodar

```powershell
# Windows (CLI): o JAVA_HOME é fixado pelo gradle.properties, mas para garantir:
$env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-21.0.12.101-hotspot"
.\gradlew.bat :app:testDebugUnitTest :app:assembleDebug
```

Ou abra a pasta no Android Studio e sincronize (o wrapper cuida do resto).

## Como testar

```powershell
.\gradlew.bat :app:testDebugUnitTest --console=plain
```

Os testes rodam com Robolectric (SDK 34, `TestApplication`), sem emulador: parser do seed
(JVM puro), SQLite em memória (DAOs, FTS, favoritos, histórico, busca) e tooling puro
(normalização de acentos, compartilhamento, sorteio diário).

## Estrutura

```
app/src/main/java/br/meigenly/
├── core/      # theme, share, daily, di, util (funções puras e configuradas)
├── data/      # db (Room: entidades, DAOs, seed), repository, settings, daily
├── domain/    # modelos de leitura desacoplados do Room
└── ui/        # navegação + telas (works, characters, quotes, reader, library, search, settings)
```

## Políticas e legal

- `docs/privacy_policy.md` — política de privacidade (Play Store)
- `docs/data_safety_form.md` — respostas do formulário Data Safety
- `docs/copyright_notice.md` — posicionamento de copyright + procedimento DMCA

## Assinatura de release

O keystore **não é versionado** (está fora do repo, em `AndroidProjects/keystores/`).
Para compilar releases assinados nesta máquina:

1. `keystore.properties` na raiz do projeto (gitignored) com:
   ```properties
   storeFile=C:\caminho\para\meigenly-release.jks
   storePassword=...
   keyAlias=meigenly
   keyPassword=...
   ```
2. `.\gradlew.bat :app:assembleRelease :app:bundleRelease`

Sem o arquivo, o build funciona normalmente e o release sai *unsigned*
(comportamento de CI/máquinas novas).

> ⚠️ **O keystore é permanente:** a Play Store só aceita updates assinados com a
> mesma chave. Guarde `meigenly-release.jks` + as senhas em local seguro
> (gerenciador de senhas / cofre). Se perder, o app na loja não pode mais ser
> atualizado sob o mesmo pacote.

## Nota de conteúdo

As frases são citações curtas, sempre com atribuição (personagem, obra e episódio
quando conhecido). Nenhuma arte de terceiros é usada: avatares são iniciais sobre
cor de destaque, e o ícone do app é arte original.
