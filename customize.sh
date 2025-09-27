#!/bin/bash
# filepath: /home/schuh/Documentos/code2/post-instalation-debian/customize.sh
# Script para restaurar extensões e configs do GNOME

set -euo pipefail  # Para em caso de erro

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

# Função para confirmar ação
confirm() {
    while true; do
        read -p "$1 (s/n): " yn
        case $yn in
            [Ss]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Por favor, responda s (sim) ou n (não).";;
        esac
    done
}

# ===== CONFIGURAÇÃO =====
GITHUB_USERDATA_ZIP="https://github.com/usuario/repositorio/releases/download/v1.0/gnome-userdata.zip"

# Caminhos locais
EXT_DIR="$HOME/.local/share/gnome-shell/extensions"
CONF_DIR="$HOME/.config"
TMP_DIR="/tmp/gnome_restore_$$"

# Site oficial para extensões
GNOME_EXT_SITE="https://extensions.gnome.org/extension-data"

# Arquivos locais
USER_DATA_ZIP="gnome-userdata.zip"

# Função de limpeza
cleanup() {
    log_info "Limpando arquivos temporários..."
    rm -rf "$TMP_DIR"
    rm -f "$USER_DATA_ZIP"
}

trap cleanup EXIT

# Verificar se está executando no GNOME
if [ "$XDG_CURRENT_DESKTOP" != "GNOME" ] && [ "$GDMSESSION" != "gnome" ]; then
    log_warn "Este script foi projetado para GNOME. Ambiente atual: ${XDG_CURRENT_DESKTOP:-unknown}"
    if ! confirm "Deseja continuar mesmo assim?"; then
        exit 0
    fi
fi

# Criar diretórios necessários
mkdir -p "$TMP_DIR"
mkdir -p "$EXT_DIR"

log_info "Instalando dependências..."
sudo apt update
sudo apt install -y gnome-shell-extensions gnome-shell-extension-prefs unzip wget jq curl

# Detectar versão do GNOME
GNOME_VERSION=$(gnome-shell --version 2>/dev/null | grep -oP '\d+\.\d+' | head -n1 || echo "unknown")
log_info "Versão do GNOME detectada: $GNOME_VERSION"

# Lista de extensões integrada ao script
log_info "Preparando lista de extensões..."
EXTENSIONS_LIST=(
    "blur-my-shell@aunetx"
    "dash-to-dock@micxgx.gmail.com"
    "dash2dock-lite@icedman.github.com"
    "compiz-alike-magic-lamp-effect@hermes83.github.com"
    "trayIconsReloaded@selfmade.pl"
    "tilingshell@ferrarodomenico.com"
    "grand-theft-focus@zalckos.github.com"
    "clipboard-indicator@tudmotu.com"
)
log_success "Lista de extensões preparada (${#EXTENSIONS_LIST[@]} extensões)"

# Baixar backup de extensões configuradas
log_info "Baixando backup de extensões configuradas do GitHub..."
if wget -q --timeout=30 -O "$USER_DATA_ZIP" "$GITHUB_USERDATA_ZIP"; then
    log_success "Backup de extensões baixado"
else
    log_warn "Falha ao baixar backup de extensões"
fi

# Função para baixar e instalar extensão
install_extension() {
    local uuid="$1"
    local ext_zip="$TMP_DIR/$uuid.zip"
    
    # Pular linhas vazias e comentários
    if [[ -z "$uuid" || "$uuid" =~ ^[[:space:]]*# ]]; then
        return 0
    fi
    
    # Validar UUID
    if [[ ! "$uuid" =~ ^[a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+$ ]]; then
        log_warn "UUID inválido: $uuid"
        return 1
    fi
    
    # Verificar se já está instalada
    if [ -d "$EXT_DIR/$uuid" ]; then
        log_info "$uuid já está instalada"
        return 0
    fi
    
    log_info "Baixando extensão: $uuid"
    
    # Tentar diferentes URLs de download
    local urls=(
        "$GNOME_EXT_SITE/$uuid.shell-extension.zip"
        "https://extensions.gnome.org/download-extension/$uuid.shell-extension.zip"
    )
    
    local downloaded=false
    for url in "${urls[@]}"; do
        if wget -q --timeout=30 --tries=1 "$url" -O "$ext_zip"; then
            downloaded=true
            break
        fi
    done
    
    if [ "$downloaded" = true ] && [ -f "$ext_zip" ]; then
        # Verificar se o ZIP é válido
        if unzip -t "$ext_zip" >/dev/null 2>&1; then
            unzip -q -o "$ext_zip" -d "$EXT_DIR/$uuid"
            log_success "$uuid instalada"
            
            # Ativar extensão (exceto dash-to-dock)
            if [ "$uuid" != "dash-to-dock@micxgx.gmail.com" ]; then
                log_info "Ativando $uuid..."
                if gnome-extensions enable "$uuid" 2>/dev/null; then
                    log_success "$uuid ativada"
                else
                    log_warn "Não foi possível ativar $uuid automaticamente"
                fi
            else
                log_info "$uuid instalada mas não ativada (conforme solicitado)"
            fi
        else
            log_error "Arquivo ZIP corrompido para $uuid"
        fi
        rm -f "$ext_zip"
    else
        log_error "Falha ao baixar $uuid"
    fi
}

# Restaurar extensões do GitHub (se disponível)
if [ -f "$USER_DATA_ZIP" ]; then
    log_info "Restaurando extensões pré-configuradas..."
    if unzip -t "$USER_DATA_ZIP" >/dev/null 2>&1; then
        unzip -q -o "$USER_DATA_ZIP" -d "$EXT_DIR/"
        log_success "Extensões pré-configuradas restauradas"
        
        # Ativar extensões restauradas
        log_info "Ativando extensões restauradas..."
        for ext_folder in "$EXT_DIR"/*; do
            if [ -d "$ext_folder" ]; then
                UUID=$(basename "$ext_folder")
                if [[ "$UUID" =~ ^[a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+$ ]]; then
                    # Não ativar dash-to-dock automaticamente
                    if [ "$UUID" != "dash-to-dock@micxgx.gmail.com" ]; then
                        log_info "Ativando $UUID..."
                        gnome-extensions enable "$UUID" 2>/dev/null || log_warn "Não foi possível ativar $UUID"
                    else
                        log_info "$UUID restaurada mas não ativada (conforme solicitado)"
                    fi
                fi
            fi
        done
    else
        log_error "Arquivo ZIP de extensões corrompido"
    fi
else
    log_warn "Arquivo de extensões pré-configuradas não encontrado"
fi

# Instalar extensões da lista integrada
if confirm "Deseja instalar as extensões GNOME selecionadas?"; then
    log_info "Instalando extensões GNOME..."
    
    total_extensions=${#EXTENSIONS_LIST[@]}
    current=0
    
    for uuid in "${EXTENSIONS_LIST[@]}"; do
        current=$((current + 1))
        
        log_info "($current/$total_extensions) Processando: $uuid"
        install_extension "$uuid"
        
        # Pausa para não sobrecarregar o servidor
        sleep 1
    done
    
    log_success "Processamento de extensões concluído"
fi

# Aplicar configurações otimizadas do GNOME
if confirm "Deseja aplicar configurações otimizadas do GNOME?"; then
    log_info "Aplicando configurações do GNOME baseadas no seu perfil atual..."
    
    # Configurações da interface
    gsettings set org.gnome.desktop.interface show-battery-percentage true 2>/dev/null || true
    gsettings set org.gnome.desktop.interface clock-show-weekday true 2>/dev/null || true
    gsettings set org.gnome.desktop.interface clock-show-seconds false 2>/dev/null || true
    # Botões de janela (adiciona minimizar e maximizar)
    # Formatos comuns: 'appmenu:minimize,maximize,close' ou 'close,minimize,maximize'
    if gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,maximize,close' 2>/dev/null; then
    else
        # fallback sem appmenu (GNOME removendo appmenu em versões recentes)
        gsettings set org.gnome.desktop.wm.preferences button-layout 'close,minimize,maximize' 2>/dev/null || true
    fi
    
    # Configurações do Nautilus 
    gsettings set org.gnome.nautilus.preferences default-folder-viewer 'list-view' 2>/dev/null || true
    gsettings set org.gnome.nautilus.preferences show-hidden-files true 2>/dev/null || true
    
    # Configurações de privacidade
    gsettings set org.gnome.desktop.privacy report-technical-problems false 2>/dev/null || true
    
    # Configurações do sistema
    gsettings set org.gnome.SessionManager logout-prompt true 2>/dev/null || true
    gsettings set org.gnome.Settings show-development-warning true 2>/dev/null || true
    
    # Configurações de energia (otimizadas)
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 3600 2>/dev/null || true
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 1800 2>/dev/null || true
    
    log_success "Configurações personalizadas aplicadas"
fi

# Finalizar
log_info "Script finalizado com sucesso!"
log_info "Para aplicar todas as mudanças:"

if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
    log_warn "Sessão Wayland detectada - Faça logout/login ou reinicie o sistema"
    if confirm "Deseja fazer logout agora?"; then
        gnome-session-quit --logout --no-prompt
    fi
else
    log_info "Reinicie o GNOME Shell: Alt+F2, digite 'r' e pressione Enter"
    log_info "Ou reinicie o sistema completamente"
fi

log_success "Customização do GNOME concluída!"