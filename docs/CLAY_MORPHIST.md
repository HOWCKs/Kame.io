# CLAY MORPHIST

Sistema de design do **Kame.io**. Este documento é a especificação viva: decisão,
motivo e limite de cada escolha.

---

## 1. Interpretação do objetivo

O Kame.io é um app de câmera. O pedido não era “trocar as cores”: era dar ao app
uma **identidade própria e reconhecível**, com nível de acabamento de produto
premium, mantendo a clareza de uso que um app de câmera exige.

A tradução prática disso virou uma regra única, aplicada em todo o sistema:

> **Estado é volume, não cor.**

Cor é esmalte: decora e sinaliza. Volume é estrutura: informa. Quando o modo
ativo é o lugar para onde a massa escorreu, o usuário entende o estado mesmo sem
ler o rótulo — e entende de novo quando a tela está sob o sol, com pouco
contraste, ou quando a visão não distingue vermelho de laranja.

## 2. Hipóteses adotadas

Não havia pesquisa de usuário disponível. Estas são as hipóteses — explícitas
para poderem ser contestadas:

| # | Hipótese | Como validar |
| - | -------- | ------------ |
| H1 | Usuário principal: 18–35 anos, fotografa com o celular e quer controle expressivo sem a poluição de um app “pro” | Entrevista + análise de telas mais usadas |
| H2 | Dor: apps de câmera são estéreis (feedback de toque inexistente) ou inchados (controles demais) | Teste de usabilidade comparativo |
| H3 | Ação central: **capturar** — tudo na tela existe para facilitar ou embelezar esse gesto | Funil de eventos |
| H4 | Diferencial: matéria que responde. O toque tem peso, inércia e retorno | Teste cego de preferência |
| H5 | Sensação desejada: “estou moldando algo”, não “estou preenchendo um formulário” | Escala de percepção pós-tarefa |
| H6 | Fluxo ideal: abrir → compor → capturar → conferir no Atlas → compartilhar | Gravação de sessão |
| H7 | Risco de abandono: permissão negada no primeiro uso, primeiro frame demorado, Atlas vazio | Telemetria de funil |
| H8 | Ações críticas: capturar, trocar de modo, gravar, excluir (destrutiva) | Testes de regressão + confirmação |
| H9 | Erros recuperáveis: permissão, câmera ocupada, armazenamento cheio, mídia corrompida | Estados implementados em `ClayErrorState` |
| H10 | Resultado esperado: uma forma guardada e encontrada depois | Taxa de retorno ao Atlas |

## 3. Direção conceitual

**Matéria que guarda o que você viu.**

Três movimentos sustentam o conceito:

1. **A massa cresce, não é recortada.** A barra de controle antiga abria um
   recorte côncavo para o obturador caber. A nova barra faz o oposto: uma
   **cúpula** de porcelana sobe para receber a peça. Recorte é ausência;
   cúpula é matéria.
2. **O estado escorre.** O seletor de modo é um veio de argila dentro de um
   sulco. Trocar de modo não repinta um botão: empurra a massa para outro lugar
   (340 ms, curva `melt`).
3. **O toque tem peso.** 90 ms para afundar, 340 ms para voltar com sobrecurso
   (`Cubic(0.34, 1.42, 0.64, 1)`). Erro de 10 ms aqui é perceptível como
   “barato”.

### O que foi deliberadamente evitado

Barro literal, mãos moldando, gradiente genérico, neon, cards com sombra
gratuita, telas brancas sem personalidade, engrenagem como “configurações”,
ícones de biblioteca pronta, layout de template e qualquer coisa que parecesse
Figma/Notion/Framer.

## 4. Princípios de experiência

1. **Uma ideia por tela.** Título curto, uma ação principal, o resto é suporte.
2. **Nada de botão sem função.** Cada controle dos Ajustes muda comportamento
   verificável. O que não podia ser implementado com honestidade foi removido.
3. **Permissão no momento certo.** O pedido de câmera acontece quando o usuário
   aperta “Dar forma”, não no boot.
4. **Feedback em três canais.** Visual (massa), tátil (háptica) e sonoro
   (obturador) — todos desligáveis, nenhum obrigatório.
5. **Erro com saída.** Nenhum estado de erro termina sem uma ação possível.
6. **Vazio com convite.** Todo estado vazio tem um objeto para tocar e a ação
   que resolve.
7. **Exploração recompensada.** A massa reage ao arrasto, a luz segue o dedo,
   a íris da abertura fecha quando o modo foto fica ativo.

## 5. Estrutura do produto

```
primeira vez ──► Estúdio (captura) ──► Atlas (biblioteca)
                    │                     │
                    │                     ├── compartilhar / excluir (com confirmação)
                    │                     └── importar do aparelho
                    └──► Ajustes
```

Quatro telas, cada uma com razão de existir:

| Tela | Razão | Ação principal |
| ---- | ----- | -------------- |
| **Primeira vez** | Explicar o conceito sem texto longo e pedir a permissão | Dar forma |
| **Estúdio** | Capturar | Obturador |
| **Atlas** | Encontrar e sair com a forma (compartilhar/excluir) | Abrir uma forma |
| **Ajustes** | Dosar matéria, som, tátil e guarda | Interruptor |

Não existe tela de “perfil”, “histórico de versões” nem “onboarding de três
passos”: para este produto, seriam telas sem propósito.

## 6. Telas

### Estúdio
- **Hierarquia:** viewfinder em tela cheia → controles boiando (porcelana) →
  obturador único ponto quente (esmalte).
- **Elementos:** miniatura do Atlas com contador, timer de gravação, marca,
  grade 3×3 opcional, anel de foco, indicador de zoom, toast.
- **Gestos:** toque = foco + exposição; pinça = zoom; toque longo em forma do
  Atlas = seleção.
- **Transições:** sem cortes — o toast sobe e assenta, o anel de foco nasce
  grande e assenta, a onda da captura sai da peça.
- **Erros:** câmera indisponível, permissão negada, captura falha. Todos com
  “Tentar de novo” e, quando aplicável, “Abrir ajustes”.
- **Telas grandes (≥ 700 px):** o visor vira um palco central de 620 px com
  cantos contínuos; a barra continua ancorada embaixo, limitada a 600 px.

### Atlas
- **Grade responsiva:** 3 colunas (< 600 px), 4 (< 900), 5 (< 1200), 6 acima.
- **Seleção:** toque longo entra no modo de seleção; a peça selecionada infla
  (elevação maior) e ganha selo — nunca só cor.
- **Destrutivo:** sempre com diálogo que escreve a consequência
  (“Não dá para desfazer”).
- **Vazio:** massa interativa + frase + ação que leva ao Estúdio.

### Ajustes
Agrupado em **Matéria / Captura / Sobre** + um **Laboratório** com a massa em
estado puro, para o usuário sentir o que o ajuste de movimento faz antes de
decidir. Cada interruptor é uma peça de porcelana que é empurrada — e muda de
cor porque “foi queimada”.

### Primeira vez
Uma decisão só. A massa é a explicação: quem nunca leu uma linha sobre o app
já entendeu do que ele trata depois de empurrá-la.

## 7. Sistema visual

### Materiais
| Material | Onde | Luz |
| -------- | ---- | --- |
| **Obsidian** | corpo, cards, sheets | realce interno fraco (16 %) + sombra interna forte (40 %) |
| **Porcelain** | barra, controles, toast | realce interno forte (62 %) + sombra interna fraca (16 %) |
| **Glaze** | obturador, ações primárias | esmalte queimado, brasa externa |

### Paleta
Abyss `#08090D` · Bedrock `#101219` · Clay low `#171A23` · Clay mid `#1E222E` ·
Clay high `#272C3A` · Chalk `#F4F1EC` · Ash `#A7A29B` · Smoke `#8A867F` ·
Porcelain `#F2EDE6` · Ink `#2A2521` · Kiln `#E9642F` · Ember `#FF4D6D` ·
Celadon `#4FD1B0` · Ochre `#E9B44C`.

Todos os pares de texto usados passam **AA**: Chalk/Abyss 16.6:1, Ash/Abyss
7.4:1, Smoke/Abyss 5.2:1, Ink/Porcelain 12.1:1, InkSoft/Porcelain 5.3:1.

### Tipografia
Família padrão da plataforma (Roboto no Android, SF no iOS), escala
34/40 · 24/30 · 18/24 · 15/22 · 13/16 · 11/14, com tracking negativo nos
tamanhos grandes (−0.7 a −0.2) e positivo nas etiquetas (+0.8).
Numéricos usam `tabularFigures` para o timer não dançar.
**Limitação conhecida:** o sistema foi desenhado para receber uma display font
licenciada trocando `ClayType.family` + o asset no `pubspec.yaml`; sem rede no
ambiente de desenvolvimento, optou-se por não embutir uma fonte de terceiros.

### Geometria
Espaçamento em base 4 (2·4·8·16·24·32·48). Raios 12·18·24·32·40·999.
Toda superfície é **superelipse aproximada por cúbicas** com alça em 0.62 do
raio — o ponto em que o canto deixa de ser círculo e passa a parecer matéria
tensionada (`lib/shape/clay_squircle.dart`).

### Elevação
Quatro níveis; cada um combina sombra projetada + realce interno no topo +
sombra interna embaixo + brilho especular. Nível 0 é raso (só rim) e nível 3 é
suspenso (usado no obturador).

### Componentes
`ClaySurface` · `ClayPressable` · `ClayIconButton` · `ClayVein` · `ClaySwitch` ·
`ClayShutter` · `ClayChip` · `ClayField` · `ClayToastOverlay` · `ClayEmptyState`
· `ClayErrorState` · `ClayConfirmDialog` · `ClayFocusRing` · `ClayActionPill`.

Estados cobertos em todos: repouso, hover (desktop), foco (teclado), premido,
selecionado e desabilitado.

## 8. Interações e microinterações

| Ação | Comportamento | Duração / curva |
| ---- | ------------- | --------------- |
| Pressionar | afunda 4,5 % e alarga 6 % | 90 ms · `easeOut` |
| Soltar | volta com sobrecurso (passa do ponto) | 340 ms · `squish` |
| Trocar modo | veio escorre pelo sulco | 340 ms · `melt` |
| Capturar | onda sai da peça + háptica + som opcional | 620 ms · `softOut` |
| Gravar | peça encolhe e vira “stop”; brasa respira | 340 ms + 1600 ms |
| Foco por toque | anel nasce 1,35× e assenta no ponto | 260 ms · `softOut` |
| Zoom por pinça | indicador aparece e infla | 180 ms |
| Troca de glifo | o glifo novo se **desenha** de 0 → 100 % | 340 ms |
| Navegar | nova tela sobe 6 % e assenta; a anterior recua 2 % | 420 ms |

**Sobre a troca de glifos:** não é interpolação ponto a ponto. Manter paridade
topológica entre dois caminhos custa caro e quebra a qualquer mudança de desenho;
em 22 px o ganho é imperceptível. A solução adotada — desenho progressivo por
`PathMetrics` + escala — lê como “a matéria se reorganizando” e é robusta.

**Movimento reduzido:** `ClayMotionScope` combina a preferência do sistema
(`MediaQuery.disableAnimations`) com o ajuste do app. Quando reduzido, as
durações encolhem para 25 % (mínimo 60 ms), as curvas ficam lineares, a háptica
desliga, a respiração da brasa para — e a massa **continua** deformando sob o
dedo, porque aí quem move é o usuário.

## 9. Estados de erro, vazio e carregamento

| Estado | Onde | Conteúdo |
| ------ | ---- | -------- |
| Carregando | boot do Estúdio, leitura do Atlas | massa se movendo + frase + barra fina (não há spinner genérico) |
| Vazio | Atlas | massa interativa, título, explicação, ação |
| Câmera ausente | Estúdio | “Nenhuma câmera por aqui” + tentar de novo |
| Câmera bloqueada | Estúdio | “A câmera não abriu” + tentar de novo + **abrir ajustes do sistema** |
| Permissão negada permanentemente | Primeira vez | instrução escrita + abrir ajustes |
| Falha ao guardar | captura | toast com o motivo e o que fazer |
| Mídia corrompida | Atlas/Estúdio | peça cinza com glifo de câmera cortada |
| Armazenamento cheio | captura | toast “não foi possível guardar” |
| Destrutivo | Atlas/Ajustes | diálogo com consequência explícita |

Nenhum erro mostra texto cru de exceção para o usuário.

## 10. Responsividade

| Faixa | Decisão |
| ----- | ------- |
| < 360 px | rótulos da barra encolhem para 10 px; nada é cortado |
| 360–599 px | barra com veio (2) + três ações (3), alvos de toque ≥ 48 px |
| 600–899 px | Atlas com 4 colunas; barras centralizadas com largura máxima |
| ≥ 700 px (Estúdio) | visor vira palco central com cantos contínuos |
| ≥ 1200 px | Atlas com 6 colunas; palco limitado a 620 px |
| Paisagem | o Estúdio mantém visor + barra ancorada; nada é escondido |

Nada foi “encolhido do desktop”: em tela grande o conteúdo é **recomposto**
(palco central), não comprimido. Escala de texto limitada a 0,85×–1,6×, faixa
em que o layout foi testado.

## 11. Acessibilidade

- Contraste AA em todos os pares de texto usados; hierarquia nunca depende só
  de cor (volume + selo + texto acompanham a cor).
- Navegação por teclado em todos os controles (`ClayPressable`): Tab, Enter e
  Espaço; foco visível com anel Celadon de 2 px e 3 px de folga.
- Rótulos semânticos em todos os botões — inclusive os que só mostram glifo.
- A massa interativa é anunciada como “superfície de argila interativa, arraste
  para deformar” e seu `CustomPaint` fica fora da árvore semântica.
- `prefers-reduced-motion` respeitado em cascata.
- Alvos de toque ≥ 48 px; botões de ação ≥ 44 px de altura.
- Mensagens de erro em linguagem direta, sem jargão e sem código.

## 12. Riscos e falhas conhecidas

| Risco | Impacto | Mitigação / situação |
| ----- | ------- | --------------------- |
| `ClayField` roda ~14 mil avaliações de campo por quadro | em aparelhos muito fracos pode perder quadros | qualidade configurável (24–48 raios); o app usa 40–44 nas telas secundárias e 48 no laboratório |
| Vídeo sem áudio | gravação muda | o app pede o microfone **ao entrar no modo vídeo**; se negado, avisa que vai gravar sem áudio em vez de falhar |
| Fonte do sistema em vez de display font licenciada | acabamento tipográfico abaixo do ideal | troca isolada em `ClayType.family` + asset; documentado |
| Capturas ficam em diretório de documentos (não na galeria do sistema) | usuário não vê as fotos em outros apps | compartilhar/exportar cobre o caminho; levar para a MediaStore é o próximo passo |
| Permissão permanentemente negada | app sem função | tela explica e abre os ajustes do sistema |
| Sem `golden tests` visuais | regressão de desenho não é pega por teste | testes cobrem geometria (cúpula, contorno, glifos, caixa de 24) e comportamento |

## 13. Melhorias recomendadas (em ordem de valor)

1. **Golden tests** dos componentes de argila para travar o desenho.
2. **Publicar na galeria do sistema** via MediaStore/`gal`.
3. **Display font licenciada** (Inter/SF-like) + eixo óptico nos tamanhos
   pequenos.
4. **Controle de exposição por arrasto vertical** (segundo gesto do visor).
5. **Modo noturno claro** — o sistema já tem os dois materiais; falta o tema
   claro completo (alto contraste para ambientes externos).
6. **Telemetria das hipóteses H1–H10** para substituir suposição por dado.

## 14. Resultado esperado

Um app de câmera que não parece um app de câmera genérico: a interface tem peso,
o toque tem resposta, o estado se entende pela forma antes da cor, e cada
controle faz o que diz. Reconhecível em um frame de vídeo — e usável de olhos
fechados, porque o sistema inteiro se comporta do mesmo jeito em todo lugar.
