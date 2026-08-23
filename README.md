# Kame Camera

Aplicativo Android nativo em Kotlin para evoluir uma câmera alternativa focada em qualidade automática máxima, controles profissionais e melhorias graduais de imagem/vídeo.

## Primeira versão implementada

- Android nativo Kotlin.
- CameraX + Camera2 Interop.
- Preview em tela cheia.
- Foto JPEG com `CAPTURE_MODE_MAXIMIZE_QUALITY` e qualidade JPEG 100%.
- Tentativa de ativar modos Camera2 de alta qualidade: redução de ruído, bordas/nitidez, correção de cor e tonemap.
- Vídeo com seleção automática de qualidade, priorizando UHD/4K quando suportado e caindo para FHD/HD/SD quando necessário.
- Controles iniciais de modo profissional:
  - Zoom.
  - Compensação de exposição quando suportada pelo sensor.
  - Flash/lanterna.
  - Alternância entre câmera traseira e frontal.
- Salvamento na galeria:
  - Fotos em `Pictures/Kame Camera`.
  - Vídeos em `Movies/Kame Camera`.
- Intents para aparecer como opção de câmera em ações de foto/vídeo do Android.
- GitHub Actions para compilar APK debug e publicar como artifact.

## Limite importante

Nenhum app consegue garantir qualidade superior à câmera padrão da Samsung em todos os cenários, porque o app nativo da fabricante costuma usar processamento privado do fornecedor, ISP e algoritmos proprietários. O objetivo do Kame Camera é extrair o máximo permitido pelas APIs públicas do Android e evoluir com HDR, filtros, efeitos, selfies, pós-processamento e IA local conforme o aparelho suportar.

## Build no GitHub Actions

O workflow `.github/workflows/android-debug-apk.yml` gera o APK debug automaticamente em pushes para a branch da Arena ou manualmente via `workflow_dispatch`.

Artifact esperado:

```text
kame-camera-debug-apk/app-debug.apk
```

## Próximos passos planejados

1. Filtros em tempo real com OpenGL/CameraX Effects.
2. Modo selfie com suavização controlável e tons de pele naturais.
3. Pós-processamento de foto: contraste, saturação, nitidez e redução de ruído.
4. Modos HDR/Ultra HDR quando suportados pelo dispositivo.
5. Controles manuais avançados: ISO, velocidade do obturador, foco manual, WB e RAW/DNG quando suportado.
6. Presets de vídeo: qualidade máxima, redes sociais, FPS alto e economia de espaço.
