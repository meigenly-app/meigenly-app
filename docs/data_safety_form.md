# Play Store — Data Safety (respostas do formulário)

Respostas para o formulário *Data Safety* do Play Console, refletindo o código real
do Meigenly (100% offline). Mantenha este documento junto do código e atualize-o
sempre que uma funcionalidade mudar as respostas.

## 1. O app coleta ou compartilha algum dos tipos de dados exigidos?

**Não — o app não coleta nem compartilha nenhum tipo de dado do usuário.**
(Sem números de telefone, e-mail, IDs de dispositivo, dados de uso, anything.)
Nenhum dado sai do aparelho e nenhuma biblioteca de analytics/publicidade está presente.

> Como o app não coleta e não compartilha, basta marcar "Não" no item principal
> do formulário. As seções de coleta/segurança de dados ficam vazias.

## 2. Justificativas que o Console pedirá mesmo com "Não"

- **Permissão POST_NOTIFICATIONS:** "Utilizada exclusivamente para envio opcional,
  diário e local de uma frase do acervo, apenas quando ativada pelo usuário.
  Nenhum dado é enviado ou coletado."
- **Permissões de INTERNET:** não declaradas (o app é offline por design —
  isso é um diferencial de segurança que pode ser mencionado na descrição).

## 3. Segurança de dados

- Dados em trânsito: N/A (o app nunca transmite dados).
- Dados em repouso: dados do usuário (favoritos, histórico, preferências) residem
  apenas no banco local do app, no armazenamento protegido do próprio app.
  Nada é compartilhado entre apps.
- Política de exclusão: desinstalar o app remove todos os dadoslocais.
  O usuário também pode limpar histórico/favoritos dentro do app.

## 4. Público

- Classificação de conteúdo: consulta ao **IARC** na primeira publicação
  (frases de anime para o público geral — sem violência real, sem conteúdo adulto).
- Crianças: o app não é direcionado a crianças e não coleta dados — responder
  que não há foco específico em menores de 13 anos, sem coleta de qualquer dado.

## 5. Checklist antes de publicar

- [ ] Hospedar `privacy_policy.md` em URL pública (GitHub Pages é suficiente)
  e colar a URL no Console (campo "Privacy policy").
- [ ] Classe de destino e IARC questionário concluídos.
- [ ] AAB de release assinado com keystore próprio (`assembleRelease` com
  `signingConfig` — ver nota no README).
- [ ] Screenshots mínimos: biblioteca, leitor, busca, favoritos, ajustes.
- [ ] Descrição curta (≤80 chars) + descrição completa.
- [ ] "App content" → anunciar que o app não contém anúncios e permite
  usuário de qualquer idade.
