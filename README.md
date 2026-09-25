# Kame.io

Duas peças, um mesmo sistema visual — **CLAY MORPHIST**: matéria moldável,
volume por extrusão, vidro translúcido e movimento com peso.

| Peça | O que é | Onde |
| --- | --- | --- |
| **Cardápio MORPHIS** | Web app de lanchonete: cardápio vivo, combos, montagem do pedido e envio por WhatsApp | [`cardapio/`](cardapio/) |
| **Kame.io (Android)** | App de câmera em Flutter com a barra "notch" | `lib/` |

---

## 1. Cardápio MORPHIS (web)

App estático — **HTML + CSS + JS puro, sem build e sem dependência de
runtime**. Abra `cardapio/index.html` ou sirva a pasta:

```bash
python3 -m http.server 8080 -d cardapio
# http://localhost:8080
```

O que ele faz:

- **Núcleo ClayMorphist** no hero: uma forma de argila que morfa sem parar e
  responde ao cursor/toque (arrasta = puxa a matéria, clique = amassa). A
  volumetria é extrusão real — 13 cópias do mesmo contorno, deslocadas e
  escurecidas, com a face iluminada por último. Sem WebGL.
- **15 itens** desenhados em SVG ("argila" procedural: gradiente radial com
  luz no alto à esquerda, sombra projetada colorida e brilho difuso). Nenhuma
  imagem externa, nenhum request.
- Fluxo completo: buscar → filtrar por categoria → ordenar → abrir o item e
  escolher ponto/molho/extras → carrinho → retirada ou entrega → revisão →
  mensagem pronta no WhatsApp.
- Estados de vazio, erro e validação com a mesma linguagem visual.
- Tema claro/escuro, `prefers-reduced-motion`, foco visível, `aria-live`,
  foco preso em diálogos, alvos de toque ≥ 44 px.

### Editar o cardápio

Tudo mora em `cardapio/assets/js/data.js` (`ITEMS`, `COMBOS`, `STORE`,
`CATEGORIES`). Trocar preço, nome, descrição ou opções não exige tocar em
HTML ou CSS.

### Testes

```bash
cd cardapio && npm install && npm test
```

Sobe o `index.html` num DOM simulado e percorre o fluxo inteiro
(38 verificações: render, busca, filtros, carrinho, checkout, validação,
teclado, acessibilidade).

---

## 2. App Android (Flutter)

App de câmera com a barra de controle inferior no estilo **"notch"**: cartão
de argila clara com recorte côncavo circular onde o obturador (anel claro +
núcleo de matéria) fica encaixado metade para fora.

### Estrutura

```
lib/
  main.dart                       # KameApp -> CameraScreen
  theme/kame_theme.dart           # ClayTokens (cor/matéria/luz) + KameTheme.dark()
  widgets/clay.dart               # ClaySurface, GlassPanel, ClayButton, ClayIconButton, ClayPill
  widgets/clay_morph.dart         # ClayMorph: blob 3D interativo (CustomPainter)
  widgets/notched_camera_bar.dart # NotchedCameraBar + NotchedBarShape (recorte côncavo)
  screens/camera_screen.dart      # viewfinder + modos foto/vídeo + overlays
  screens/gallery_screen.dart     # grade de mídias (overlay)
  screens/settings_screen.dart    # preferências (sheet de Config.)
cardapio/                         # web app do cardápio (estático)
preview/index.html                # réplica da barra no navegador
.github/workflows/
  build-apk.yml                   # gera o APK instalável
  flutter-ci.yml                  # analyze + test + smoke do cardápio
```

### Sistema visual (CLAY MORPHIST)

- **Matéria**: `ClaySurface` empilha uma face com gradiente sobre uma lateral
  escura deslocada para baixo (`depth`). O volume vem da pilha, não de borda.
- **Vidro**: `GlassPanel` desfoca o fundo (`BackdropFilter`) para o que
  flutua — sheets, cards de ajustes.
- **Movimento**: `ClayTokens.spring` (overshoot curto) em pressões,
  `ClayMorph` para estados de espera. Respeita
  `MediaQuery.of(context).disableAnimations`.
- **Paleta**: terracota `#FF8355`, violeta `#9A87FF`, âmbar `#FFCE63`,
  menta `#35DDB0`, framboesa `#FF87B6`, céu `#6FCCFA` sobre noite morna
  `#100C14`. Tokens em `ClayTokens`; nada de cor chumbada em widget.

### Rodar localmente

```bash
flutter pub get
flutter run          # precisa de device/emulador com câmera
flutter test         # 12 testes: tema, barra, componentes de matéria
```

Requisitos: Flutter estável 3.24+.

---

## 3. Build do APK pelo GitHub Actions

O workflow **Build Android APK** (`.github/workflows/build-apk.yml`) roda em:

- push em `main` e em branches `arena/**`
- push de tag `v*` (o APK é anexado à Release do GitHub)
- disparo manual (**Actions → Build Android APK → Run workflow**), com a
  escolha `debug` / `release` / `both`

Ele usa `subosito/flutter-action@v2` (Flutter 3.24.5), `actions/setup-java@v4`
(Java 17) e `gradle/actions/setup-gradle@v4` (Gradle 8.4 — o wrapper jar não é
versionado no repo, então o Gradle é provisionado pela action).

Antes de compilar ele roda `flutter analyze` e `flutter test`; se algum
falhar, nenhum APK é gerado.

Artefato gerado: **`kame-io-<tipo>-apk`**, contendo
`kame-io-1.0.0-<tipo>.apk` (retention de 30 dias).

### Qual APK instalar?

| Build     | Assinatura                          | Instalável direto? |
| --------- | ----------------------------------- | ------------------ |
| `debug`   | keystore de debug (automática)      | ✅ sim             |
| `release` | keystore de release, **se** os secrets existirem; senão cai para debug | ✅ sim |

Para assinar o release de verdade, cadastre estes secrets no repositório:

| Secret                      | Conteúdo                                        |
| --------------------------- | ----------------------------------------------- |
| `ANDROID_KEYSTORE_BASE64`   | `base64 -w0 upload-keystore.jks`                |
| `ANDROID_KEYSTORE_PASSWORD` | senha da keystore                               |
| `ANDROID_KEY_ALIAS`         | alias da chave                                  |
| `ANDROID_KEY_PASSWORD`      | senha da chave                                  |

Gerar uma keystore:

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias kame
```

Sem os secrets, o build **não falha**: ele apenas emite um aviso e assina com
a keystore de debug.

## 4. Publicar o cardápio (GitHub Pages)

```bash
git push origin main   # ou rode o workflow manualmente
```

O workflow **Deploy cardápio (Pages)** publica `cardapio/` no GitHub Pages
(disparo manual ou push em `main`). Na primeira vez, habilite em
**Settings → Pages → Build and deployment → Source: GitHub Actions**.
