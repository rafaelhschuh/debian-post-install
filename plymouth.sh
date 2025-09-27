#!/bin/bash
# Script para instalar tema Plymouth personalizado do Debian
# Baixa tema do GNOME-Look e configura automaticamente

set -euo pipefail

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para log
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERRO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[ETAPA]${NC} $1"
}

# Verificar se está sendo executado como root
if [ "$EUID" -ne 0 ]; then
    log_error "Este script precisa ser executado como root (sudo)"
    exit 1
fi

# Verificar se Plymouth está instalado
if ! command -v plymouth-set-default-theme &> /dev/null; then
    log_info "Plymouth não está instalado. Instalando..."
    apt update && apt install -y plymouth plymouth-themes
fi

# Verificar e instalar dependências necessárias do Plymouth
log_info "Verificando dependências do Plymouth..."
PLYMOUTH_PACKAGES=(
    "plymouth"
    "plymouth-themes" 
    "libplymouth5"
    "plymouth-label"
)

for package in "${PLYMOUTH_PACKAGES[@]}"; do
    if ! dpkg -l | grep -q "^ii  $package "; then
        log_info "Instalando $package..."
        apt install -y "$package" || log_warn "Falha ao instalar $package"
    fi
done

# Verificar se o módulo two-step existe, se não, tentar reinstalar
if [[ ! -f "/usr/lib/x86_64-linux-gnu/plymouth/two-step.so" ]]; then
    log_warn "Módulo two-step.so não encontrado. Reinstalando Plymouth..."
    apt install --reinstall -y plymouth plymouth-themes libplymouth5
fi

# Configuração do tema
THEME_ZIP_URL="https://raw.githubusercontent.com/rafaelhschuh/debian-post-install/refs/heads/main/debian-logo.zip"
THEME_NAME="debian-logo"
PLYMOUTH_THEMES_DIR="/usr/share/plymouth/themes"
TMP_DIR="/tmp/plymouth_install_$$"

# Criar diretório temporário
mkdir -p "$TMP_DIR"
log_info "Diretório temporário criado: $TMP_DIR"

# Função de limpeza
cleanup() {
    log_info "Limpando arquivos temporários..."
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

log_step "Instalando tema Plymouth personalizado do Debian..."

# Baixar tema
log_info "Baixando tema Plymouth..."
if curl -fsSL "$THEME_ZIP_URL" -o "$TMP_DIR/theme.zip"; then
    log_success "Tema baixado com sucesso"
else
    log_error "Falha ao baixar tema. Verifique a URL ou conectividade."
    exit 1
fi

# Verificar se o ZIP é válido
if ! unzip -t "$TMP_DIR/theme.zip" >/dev/null 2>&1; then
    log_error "Arquivo ZIP inválido ou corrompido"
    exit 1
fi

# Extrair tema
log_info "Extraindo tema..."
unzip -q -o "$TMP_DIR/theme.zip" -d "$TMP_DIR/extracted"

# Procurar diretório do tema
THEME_DIR=""
shopt -s nullglob
for dir in "$TMP_DIR/extracted"/*/ "$TMP_DIR/extracted"/*/*/; do
    if [[ -f "$dir/$THEME_NAME.plymouth" ]] || [[ -f "$dir/theme.plymouth" ]]; then
        THEME_DIR="$dir"
        break
    fi
done
shopt -u nullglob

if [[ -z "$THEME_DIR" ]]; then
    log_warn "Estrutura de tema não encontrada automaticamente. Listando conteúdo:"
    find "$TMP_DIR/extracted" -name "*.plymouth" -type f
    
    # Tentar localizar qualquer arquivo .plymouth
    PLYMOUTH_FILE=$(find "$TMP_DIR/extracted" -name "*.plymouth" -type f | head -n1)
    if [[ -n "$PLYMOUTH_FILE" ]]; then
        THEME_DIR=$(dirname "$PLYMOUTH_FILE")
        THEME_NAME=$(basename "$PLYMOUTH_FILE" .plymouth)
        log_info "Encontrado tema: $THEME_NAME em $THEME_DIR"
    else
        log_error "Nenhum arquivo .plymouth encontrado no ZIP"
        exit 1
    fi
fi

# Criar diretório de destino
DEST_DIR="$PLYMOUTH_THEMES_DIR/$THEME_NAME"
log_info "Instalando tema em: $DEST_DIR"

# Remover tema existente se houver
if [[ -d "$DEST_DIR" ]]; then
    log_warn "Tema $THEME_NAME já existe. Substituindo..."
    rm -rf "$DEST_DIR"
fi

# Copiar arquivos do tema
mkdir -p "$DEST_DIR"
cp -r "$THEME_DIR"/* "$DEST_DIR/"
log_success "Arquivos do tema copiados"

# Definir permissões corretas
chmod -R 644 "$DEST_DIR"/*
find "$DEST_DIR" -type d -exec chmod 755 {} \;
log_success "Permissões configuradas"

# Listar temas disponíveis
log_info "Temas Plymouth disponíveis:"
plymouth-set-default-theme --list

# Verificar se o arquivo .plymouth está válido
PLYMOUTH_CONFIG="$DEST_DIR/$THEME_NAME.plymouth"
if [[ ! -f "$PLYMOUTH_CONFIG" ]]; then
    # Procurar por qualquer arquivo .plymouth no diretório
    PLYMOUTH_CONFIG=$(find "$DEST_DIR" -name "*.plymouth" -type f | head -n1)
    if [[ -z "$PLYMOUTH_CONFIG" ]]; then
        log_error "Arquivo de configuração .plymouth não encontrado"
        exit 1
    fi
fi

# Verificar se o conteúdo do arquivo .plymouth está correto
log_info "Validando arquivo de configuração: $PLYMOUTH_CONFIG"
if ! grep -q "\[Plymouth Theme\]" "$PLYMOUTH_CONFIG"; then
    log_warn "Arquivo .plymouth pode estar malformado"
fi

# Aplicar tema
log_info "Configurando tema $THEME_NAME como padrão..."
if plymouth-set-default-theme "$THEME_NAME" 2>/dev/null; then
    log_success "Tema $THEME_NAME definido como padrão"
else
    log_warn "Falha ao definir tema personalizado. Tentando tema padrão..."
    # Fallback para um tema que sabemos que funciona
    if plymouth-set-default-theme bgrt 2>/dev/null || plymouth-set-default-theme spinner 2>/dev/null; then
        log_info "Tema padrão configurado como fallback"
    else
        log_error "Erro crítico: não foi possível configurar nenhum tema Plymouth"
        log_info "Listando arquivos em $DEST_DIR:"
        ls -la "$DEST_DIR"
        exit 1
    fi
fi

# Atualizar initramfs
log_info "Atualizando initramfs..."
if update-initramfs -u; then
    log_success "Initramfs atualizado"
else
    log_warn "Falha ao atualizar initramfs. O tema pode não aparecer no boot."
fi

# Verificar configuração atual
CURRENT_THEME=$(plymouth-set-default-theme)
log_success "Tema Plymouth atual: $CURRENT_THEME"

log_step "Instalação concluída!"
echo ""
log_info "🎉 Tema Plymouth instalado com sucesso!"
echo "  ✓ Tema: $THEME_NAME"
echo "  ✓ Localização: $DEST_DIR"
echo "  ✓ Initramfs atualizado"
echo ""
log_warn "📋 Para ver o tema funcionando:"
echo "  1. REINICIE o sistema"
echo "  2. O tema aparecerá durante o boot/shutdown"
echo ""
log_info "💡 Comandos úteis:"
echo "  • Listar temas: plymouth-set-default-theme --list"
echo "  • Mudar tema: sudo plymouth-set-default-theme NOME_DO_TEMA"
echo "  • Testar tema: sudo plymouthd; sudo plymouth --show-splash; sleep 3; sudo plymouth quit"
echo ""
log_success "🚀 Pronto para o próximo reinício!"
