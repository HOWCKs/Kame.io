#!/usr/bin/env bash
# Dispara a build do APK do Kame.io pelo GitHub Actions e baixa o artefato.
# Feito para rodar no Termux (Android), mas serve em qualquer shell com git+gh.
#
# Uso:
#   ./scripts/disparar-apk.sh                 # build debug + release
#   TIPO=debug ./scripts/disparar-apk.sh      # só debug (mais rápido)
#   BRANCH=main ./scripts/disparar-apk.sh     # outra branch
#
# Variáveis: BRANCH, TIPO (debug|release|both), REPO, DIR, SEM_INSTALAR=1
set -euo pipefail

BRANCH="${BRANCH:-arena/01a0dad7-kame-io}"
TIPO="${TIPO:-both}"
REPO="${REPO:-HOWCKs/Kame.io}"
DIR="${DIR:-$HOME/Kame.io}"

need() { command -v "$1" >/dev/null 2>&1; }

# ── 1. dependências ─────────────────────────────────────────────────────────
if ! need gh; then
  echo "▸ instalando gh…"
  if need pkg; then pkg install -y gh; else echo "instale o GitHub CLI: https://cli.github.com"; exit 1; fi
fi
if ! need git; then
  if need pkg; then pkg install -y git; else echo "instale o git"; exit 1; fi
fi

# ── 2. autenticação ─────────────────────────────────────────────────────────
gh auth status >/dev/null 2>&1 || gh auth login

# ── 3. código ───────────────────────────────────────────────────────────────
if [ -d "$DIR/.git" ]; then
  echo "▸ atualizando $DIR"
  cd "$DIR"
  git fetch --all --prune
  git checkout "$BRANCH"
  git pull --ff-only
else
  echo "▸ clonando em $DIR"
  git clone "https://github.com/$REPO.git" "$DIR"
  cd "$DIR"
  git checkout "$BRANCH"
fi

# ── 4. disparar ─────────────────────────────────────────────────────────────
echo "▸ disparando build ($TIPO) em $BRANCH…"
gh workflow run build-apk.yml --ref "$BRANCH" -f build_type="$TIPO"
sleep 15

RUN="$(gh run list --workflow=build-apk.yml --limit 1 --json databaseId --jq '.[0].databaseId')"
echo "▸ run: https://github.com/$REPO/actions/runs/$RUN"
gh run watch "$RUN" || true

# ── 5. baixar ───────────────────────────────────────────────────────────────
rm -rf apks && mkdir -p apks && cd apks
echo "▸ baixando artefatos…"
gh run download "$RUN" || true

APK="$(find . -name '*.apk' | head -n 1 || true)"
if [ -z "$APK" ]; then
  echo "✗ nenhum APK baixado. Veja os logs:"
  echo "  gh run view $RUN --log-failed"
  exit 1
fi

echo
echo "✓ APKs:"
find . -name '*.apk' -exec ls -lh {} \;

# ── 6. instalar (Termux) ────────────────────────────────────────────────────
if [ -z "${SEM_INSTALAR:-}" ] && need termux-open; then
  echo
  echo "▸ abrindo instalador do Android…"
  termux-open "$APK"
else
  echo
  echo "Instale com:  termux-open $(pwd)/$APK"
fi
