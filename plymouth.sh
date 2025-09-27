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

# Verificar se Plymouth está instalado e instalar dependências completas
log_info "Verificando e instalando Plymouth com todas as dependências..."
apt update

PLYMOUTH_PACKAGES=(
    "plymouth"
    "plymouth-themes" 
    "libplymouth5"
    "plymouth-label"
    "plymouth-x11"
)

# Instalar/reinstalar todos os pacotes necessários
for package in "${PLYMOUTH_PACKAGES[@]}"; do
    log_info "Instalando/reinstalando $package..."
    apt install --reinstall -y "$package" 2>/dev/null || apt install -y "$package" 2>/dev/null || log_warn "Falha ao instalar $package"
done

# Verificar se o módulo two-step existe após instalação
if [[ ! -f "/usr/lib/x86_64-linux-gnu/plymouth/two-step.so" ]]; then
    log_warn "Módulo two-step.so ainda não encontrado. Tentando reconstruir..."
    # Tentar reconstruir módulos plymouth
    dpkg-reconfigure plymouth 2>/dev/null || true
    update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth /usr/share/plymouth/themes/spinner/spinner.plymouth 100 2>/dev/null || true
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

# Diagnóstico antes de aplicar tema
log_info "Executando diagnósticos Plymouth..."
log_info "Módulos Plymouth disponíveis:"
find /usr/lib/x86_64-linux-gnu/plymouth/ -name "*.so" 2>/dev/null | head -5 || log_warn "Diretório de módulos não encontrado"

# Verificar se o tema específico tem problemas
log_info "Testando configuração do tema..."
if plymouth-set-default-theme --list | grep -q "^$THEME_NAME$"; then
    log_success "Tema $THEME_NAME encontrado na lista"
else
    log_warn "Tema $THEME_NAME não aparece na lista oficial"
fi

# Aplicar tema com múltiplas tentativas
log_info "Configurando tema $THEME_NAME como padrão..."

# Primeira tentativa: tema personalizado
if plymouth-set-default-theme "$THEME_NAME" 2>/dev/null; then
    log_success "Tema $THEME_NAME definido como padrão"
    THEME_SUCCESS=true
else
    log_warn "Falha ao definir tema personalizado. Erro detectado:"
    plymouth-set-default-theme "$THEME_NAME" 2>&1 | head -3 || true
    THEME_SUCCESS=false
    
    # Segunda tentativa: temas padrão funcionais
    log_warn "Tentando temas padrão como fallback..."
    for fallback_theme in "spinner" "text" "details"; do
        if plymouth-set-default-theme "$fallback_theme" 2>/dev/null; then
            log_info "Tema fallback '$fallback_theme' configurado"
            THEME_SUCCESS=true
            break
        fi
    done
    
    if [[ "$THEME_SUCCESS" == false ]]; then
        log_error "Erro crítico: não foi possível configurar nenhum tema Plymouth"
        log_info "Listando conteúdo de $DEST_DIR:"
        ls -la "$DEST_DIR" 2>/dev/null || true
        log_info "Conteúdo do arquivo .plymouth:"
        head -10 "$PLYMOUTH_CONFIG" 2>/dev/null || true
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

# Perguntar sobre configuração do GRUB
echo ""
log_step "Configuração opcional do GRUB"
echo ""
log_info "Deseja configurar o GRUB para boot silencioso e rápido?"
echo "  • Remove espera de 5 segundos no menu"
echo "  • Boot automático direto para o sistema"
echo "  • Menu acessível segurando SHIFT durante boot"
echo ""
read -p "Configurar GRUB silencioso? (s/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[SsYy]$ ]]; then
    log_step "Configurando GRUB para boot silencioso..."

    GRUB_CONFIG="/etc/default/grub"
    GRUB_BACKUP="/etc/default/grub.backup.$(date +%Y%m%d_%H%M%S)"

    # Fazer backup do arquivo original
    if [[ -f "$GRUB_CONFIG" ]]; then
        cp "$GRUB_CONFIG" "$GRUB_BACKUP"
        log_info "Backup do GRUB criado: $GRUB_BACKUP"
    fi

    # Configurações do GRUB para boot silencioso
    log_info "Aplicando configurações de boot silencioso..."

    # Remover ou comentar configurações conflitantes e adicionar novas
    {
        grep -v "^GRUB_TIMEOUT\|^GRUB_TIMEOUT_STYLE\|^GRUB_HIDDEN_TIMEOUT\|^GRUB_RECORDFAIL_TIMEOUT\|^GRUB_CMDLINE_LINUX_DEFAULT" "$GRUB_CONFIG" 2>/dev/null || true
        echo ""
        echo "# Configurações para boot silencioso e rápido"
        echo "GRUB_TIMEOUT=0"
        echo "GRUB_TIMEOUT_STYLE=hidden"
        echo "GRUB_RECORDFAIL_TIMEOUT=2"
        echo 'GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"'
        echo ""
        echo "# Para acessar menu GRUB: segure SHIFT durante boot"
    } > "${GRUB_CONFIG}.tmp"

    # Substituir arquivo original
    mv "${GRUB_CONFIG}.tmp" "$GRUB_CONFIG"
    log_success "Configurações GRUB aplicadas"

    # Atualizar configuração do GRUB
    log_info "Atualizando configuração do GRUB..."
    if update-grub 2>/dev/null; then
        log_success "GRUB atualizado com sucesso"
        GRUB_CONFIGURED=true
    else
        log_warn "Falha ao atualizar GRUB. Tentando comando alternativo..."
        if grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null; then
            log_success "GRUB atualizado com comando alternativo"
            GRUB_CONFIGURED=true
        else
            log_error "Falha ao atualizar GRUB. Configuração pode não ter efeito."
            GRUB_CONFIGURED=false
        fi
    fi
else
    log_info "Configuração do GRUB mantida como estava"
    GRUB_CONFIGURED=false
fi

log_step "Instalação concluída!"
echo ""
if [[ "${GRUB_CONFIGURED:-false}" == true ]]; then
    log_info "🎉 Tema Plymouth e GRUB configurados!"
    echo "  ✓ Tema Plymouth: $THEME_NAME"
    echo "  ✓ Localização: $DEST_DIR"
    echo "  ✓ GRUB configurado para boot silencioso"
    echo "  ✓ Timeout GRUB: 0 segundos"
    echo "  ✓ Initramfs atualizado"
    echo ""
    log_warn "📋 Para ver as mudanças:"
    echo "  1. REINICIE o sistema"
    echo "  2. Boot será automático e silencioso"
    echo "  3. Tema Plymouth aparecerá durante boot"
    echo ""
    log_info "🔧 Acesso ao menu GRUB:"
    echo "  • Segure SHIFT durante o boot para acessar menu"
    echo "  • Ou segure ESC logo após ligar o computador"
    echo ""
    log_info "💡 Comandos úteis:"
    echo "  • Restaurar GRUB: sudo cp $GRUB_BACKUP /etc/default/grub && sudo update-grub"
else
    log_info "🎉 Tema Plymouth instalado!"
    echo "  ✓ Tema Plymouth: $THEME_NAME"
    echo "  ✓ Localização: $DEST_DIR"
    echo "  ✓ Initramfs atualizado"
    echo "  ⚪ GRUB mantido com configurações originais"
    echo ""
    log_warn "📋 Para ver o tema Plymouth:"
    echo "  1. REINICIE o sistema"
    echo "  2. Tema aparecerá durante boot/shutdown"
    echo ""
    log_info "💡 Para configurar GRUB silencioso manualmente:"
    echo "  • Execute novamente o script e escolha 's'"
    echo "  • Ou edite /etc/default/grub manualmente"
fi
echo ""
log_info "💡 Comandos Plymouth:"
echo "  • Listar temas: plymouth-set-default-theme --list"
echo "  • Testar tema: sudo plymouthd; sudo plymouth --show-splash; sleep 3; sudo plymouth quit"
echo ""
log_success "🚀 Sistema configurado com sucesso!"
