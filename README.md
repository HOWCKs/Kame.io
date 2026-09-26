# Kame.io

App de câmera em **Flutter** com a linguagem visual **CLAY MORPHIST**: matéria,
luz e movimento. Estado é volume, não cor — o modo ativo é o lugar para onde a
massa escorreu, o botão pressionado afunda, a captura manda uma onda pela peça.

> A especificação completa do sistema — decisão, motivo e limite de cada escolha
> — está em [`docs/CLAY_MORPHIST.md`](docs/CLAY_MORPHIST.md).
> Uma vitrine interativa (HTML, sem dependências) está em
> [`preview/index.html`](preview/index.html): dá para empurrar a massa, trocar o
> modo, gravar e ver os estados de erro e vazio.

## Estrutura

```
lib/
  main.dart                         # boot: ajustes + cofre -> KameApp
  theme/
    clay_tokens.dart                # paleta, tipografia, espaço, raios, elevação
    clay_theme.dart                 # ThemeData (Material 3 escuro)
  motion/clay_motion.dart           # durações, curvas, escopo de movimento, háptica
  shape/clay_squircle.dart          # superelipse + ShapeBorder
  icons/clay_glyphs.dart            # 23 glifos vetoriais desenhados à mão + cache
  widgets/
    clay_surface.dart               # material, luz interna, pressável (foco/hover/semântica)
    clay_glyph_view.dart            # glifo que se desenha (PathMetrics)
    clay_controls.dart              # botão, veio, chave de forno, obturador, chip
    clay_control_bar.dart           # barra com cúpula + cúpula do obturador
    clay_field.dart                 # massa de metaballs interativa (o "3D")
    clay_states.dart                # boot, vazio, erro, ação, foco, confirmação
    clay_toast.dart                 # feedback com massa
  screens/
    studio_screen.dart              # câmera: visor, gestos, gravação
    atlas_screen.dart               # biblioteca: grade, seleção, compartilhar, excluir
    settings_screen.dart            # ajustes + laboratório de matéria
    onboarding_screen.dart          # primeira vez: uma decisão
  services/
    clay_settings.dart              # preferências persistidas (JSON)
    morph_vault.dart                # acervo de formas (documentos ou sessão)
  navigation/clay_route.dart        # transição entre telas
android/                            # projeto Android nativo (AGP 8.1.4 / Gradle 8.4)
.github/workflows/
  flutter-ci.yml                    # analyze + test (+ formatação automática)
  build-apk.yml                     # gera o APK instalável
docs/CLAY_MORPHIST.md               # especificação do design system
preview/index.html                  # vitrine interativa no navegador
```

## Decisões que valem saber

- **A barra não é recortada, é crescida.** A cúpula de porcelana sobe para
  receber o obturador; antes, a massa era cortada para abrir espaço.
- **Glifos próprios.** Nenhum ícone de biblioteca pronta: 23 desenhos vetoriais
  em caixa de 24, traço 1.9, que se *desenham* quando o estado muda.
- **A massa é resolvida por amostragem radial**, não por marching squares: cada
  bloco preserva seu contorno, ilhas não desaparecem e o custo é previsível
  (~14 mil avaliações de campo por quadro, qualidade configurável).
- **Movimento reduzido em cascata.** Preferência do sistema + ajuste do app:
  durações encolhem, curvas linearizam, háptica desliga — e a massa continua
  deformando sob o dedo, porque aí quem move é o usuário.
- **Nenhum controle sem função.** Cada interruptor dos Ajustes muda
  comportamento verificável do app.

## Rodar localmente

```bash
flutter pub get
flutter run
```

Requisitos: Flutter estável 3.24+ e um device/emulador Android com câmera.

```bash
flutter analyze      # estático
flutter test         # unidade + widget
dart format lib test # formatação (o CI também aplica)
```

## Cobertura de testes

| Arquivo | O que garante |
| ------- | ------------- |
| `test/clay_control_bar_test.dart` | geometria da cúpula, rótulos, modo, obturador, controles frios |
| `test/clay_field_test.dart` | contorno do metaball, fusão, ilhas, determinismo, limites |
| `test/clay_system_test.dart` | glifos dentro da caixa, tema, movimento reduzido, superfície, chave, veio |

## Build do APK pelo GitHub Actions

O workflow **Build Android APK** (`.github/workflows/build-apk.yml`) roda em:

- push em `main`
- push de tag `v*` (o APK é anexado à Release do GitHub)
- disparo manual (**Actions → Build Android APK → Run workflow**), com a
  escolha `debug` / `release` / `both`

Ele usa `subosito/flutter-action@v2` (Flutter 3.24.5), `actions/setup-java@v4`
(Java 17) e `gradle/actions/setup-gradle@v4`.

Artefato gerado: **`kame-io-<tipo>-apk`**, contendo `kame-io-1.0.0-<tipo>.apk`.

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

Sem os secrets, o build **não falha**: ele apenas emite um aviso e assina com a
keystore de debug.

## Limitações conhecidas

- **Fonte do sistema** (Roboto/SF) em vez de uma display font licenciada — a
  troca é isolada em `ClayType.family` + um asset no `pubspec.yaml`.
- **Capturas ficam no diretório de documentos do app**, não na galeria do
  sistema. Compartilhar/exportar cobre a saída; publicar via MediaStore é o
  próximo passo.
- **Vídeo sem áudio** quando o microfone é negado: o app avisa em vez de falhar.
- **Sem golden tests** ainda: a geometria é coberta por testes, o desenho não.
