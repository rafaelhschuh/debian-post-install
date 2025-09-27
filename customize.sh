#!/bin/bash

set -euo pipefail

ZIP_URL="https://raw.githubusercontent.com/rafaelhschuh/debian-post-install/refs/heads/main/extension-data.zip"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions"
TMP_DIR="/tmp/gnome_ext_unpack"
ZIP_FILE="$TMP_DIR/extension-data.zip"

mkdir -p "$EXT_DIR" "$TMP_DIR"

echo "[1/3] Baixando pacote de extensões..."
curl -fsSL "$ZIP_URL" -o "$ZIP_FILE"

echo "[2/3] Extraindo diretamente para: $EXT_DIR"
unzip -q -o "$ZIP_FILE" -d "$EXT_DIR"

echo "[3/3] Aplicando ajustes GNOME básicos..."
gsettings set org.gnome.desktop.interface show-battery-percentage true 2>/dev/null || true
gsettings set org.gnome.desktop.interface clock-show-weekday true 2>/dev/null || true
gsettings set org.gnome.desktop.interface clock-show-seconds false 2>/dev/null || true
gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,maximize,close' 2>/dev/null || \
  gsettings set org.gnome.desktop.wm.preferences button-layout 'close,minimize,maximize' 2>/dev/null || true
gsettings set org.gnome.nautilus.preferences default-folder-viewer 'list-view' 2>/dev/null || true
gsettings set org.gnome.nautilus.preferences show-hidden-files true 2>/dev/null || true
gsettings set org.gnome.desktop.privacy report-technical-problems false 2>/dev/null || true
gsettings set org.gnome.SessionManager logout-prompt true 2>/dev/null || true
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 3600 2>/dev/null || true
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 1800 2>/dev/null || true

echo "Pronto. Pastas extraídas e ajustes aplicados. Ative manualmente extensões após reiniciar a sessão do GNOME (logout/login)."