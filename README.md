# Kame.io

App de câmera em **Flutter** com barra de navegação inferior em **glassmorphism**
(translúcida, com blur, borda hairline e indicador deslizante animado).

## Estrutura

```
lib/
  main.dart                      # KameApp + HomeShell (IndexedStack de 3 abas)
  theme/kame_theme.dart          # tokens de cor/raio + ThemeData (Material 3, dark)
  widgets/glass_bottom_nav.dart  # a barra de navegação "de vidro"
  screens/camera_screen.dart     # viewfinder (plugin camera)
  screens/gallery_screen.dart    # grade de fotos (image_picker)
  screens/settings_screen.dart   # preferências
android/                         # projeto Android nativo (AGP 8.1.4 / Gradle 8.4)
.github/workflows/
  build-apk.yml                  # gera o APK instalável
  flutter-ci.yml                 # analyze + test em PRs
```

## Rodar localmente

```bash
flutter pub get
flutter run
```

Requisitos: Flutter estável 3.24+ e um device/emulador Android com câmera.

## Build do APK pelo GitHub Actions

O workflow **Build Android APK** (`.github/workflows/build-apk.yml`) roda em:

- push em `main`
- push de tag `v*` (o APK é anexado à Release do GitHub)
- disparo manual (**Actions → Build Android APK → Run workflow**), com a
  escolha `debug` / `release` / `both`

Ele usa `subosito/flutter-action@v2` (Flutter 3.24.5), `actions/setup-java@v4`
(Java 17) e `gradle/actions/setup-gradle@v4` (Gradle 8.4 — o wrapper jar não é
versionado no repo, então o Gradle é provisionado pela action).

Artefato gerado: **`kame-io-<tipo>-apk`**, contendo
`kame-io-1.0.0-<tipo>.apk`.

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
