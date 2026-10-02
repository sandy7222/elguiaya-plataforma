#!/usr/bin/env bash
# Idempotent setup for the Capitán YA / El Guía YA Flutter app.
# Installs the Flutter SDK (if missing) and resolves Dart/Flutter dependencies.
# Safe to re-run: it converges instead of re-downloading when already present.
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.47.4}"
FLUTTER_HOME="${FLUTTER_HOME:-$HOME/flutter}"
FLUTTER_BIN="$FLUTTER_HOME/bin"

log() { echo "[install] $*"; }

install_flutter() {
  if [ -x "$FLUTTER_BIN/flutter" ]; then
    log "Flutter already present at $FLUTTER_HOME"
    return
  fi
  log "Installing Flutter $FLUTTER_VERSION into $FLUTTER_HOME ..."
  local archive="flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  local url="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/${archive}"
  local tmp
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/$archive" "$url"
  mkdir -p "$(dirname "$FLUTTER_HOME")"
  tar -xf "$tmp/$archive" -C "$(dirname "$FLUTTER_HOME")"
  rm -rf "$tmp"
}

install_flutter

export PATH="$FLUTTER_BIN:$PATH"

# Make flutter available in future interactive/login shells (idempotent).
BASHRC="$HOME/.bashrc"
LINE="export PATH=\"$FLUTTER_BIN:\$PATH\""
if [ -f "$BASHRC" ] && ! grep -qF "$FLUTTER_BIN" "$BASHRC"; then
  printf '\n# Flutter SDK (added by .cursor/install.sh)\n%s\n' "$LINE" >> "$BASHRC"
fi

# git >= 2.35 refuses to operate on repos owned by another user without this.
git config --global --add safe.directory "$FLUTTER_HOME" 2>/dev/null || true
git config --global --add safe.directory "$(pwd)" 2>/dev/null || true

flutter --disable-analytics >/dev/null 2>&1 || true
flutter config --enable-web >/dev/null 2>&1 || true

log "Flutter toolchain:"
flutter --version

log "Resolving project dependencies (flutter pub get) ..."
flutter pub get

log "Setup complete."
