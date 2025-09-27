#!/bin/bash
# filepath: /home/schuh/Documentos/code2/post-instalation-debian/setup.sh

# Script para instalação inicial do Debian

set -euo pipefail  # Para em caso de erro

# ===== CONFIGURAÇÃO =====
GITHUB_CUSTOMIZE_URL="https://raw.githubusercontent.com/rafaelhschuh/debian-post-install/refs/heads/main/customize.sh"

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

# Função para verificar sucesso de comandos
check_command() {
    if [ $? -eq 0 ]; then
        log_success "$1 - Concluído"
        return 0
    else
        log_error "$1 - Falhou"
        return 1
    fi
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

# Verificar se o script está sendo executado como root
if [ "$EUID" -ne 0 ]; then
    log_error "Por favor, execute este script como root."
    exit 1
fi

# Detectar versão do Debian
DEBIAN_VERSION=$(lsb_release -cs 2>/dev/null || echo "unknown")
if [ "$DEBIAN_VERSION" = "unknown" ]; then
    log_warn "Não foi possível detectar a versão do Debian. Assumindo 'trixie'."
    DEBIAN_VERSION="trixie"
fi
log_info "Debian detectado: $DEBIAN_VERSION"

# Setup sudo user com validação
log_step "Configurando usuário sudo..."

# Função de validação de nome de usuário
validate_username() {
    local name="$1"
    # regras: começa com letra minúscula ou underscore, restante letras, números, underscore ou hífen, até 32 chars
    if [[ "$name" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] && [[ "$name" != "root" ]]; then
        return 0
    else
        return 1
    fi
}

# Parsing de argumentos para --user=nome
SUDO_USER_ARG=""
for arg in "$@"; do
  case $arg in
     --user=*) SUDO_USER_ARG="${arg#*=}" ;;
  esac
done

# Permitir SUDO_USER via variável de ambiente também
if [[ -n "${SUDO_USER:-}" && -z "$SUDO_USER_ARG" ]]; then
    SUDO_USER_ARG="$SUDO_USER"
fi

SUDO_USER=""
if [[ -n "$SUDO_USER_ARG" ]]; then
    if validate_username "$SUDO_USER_ARG"; then
        SUDO_USER="$SUDO_USER_ARG"
        log_info "Usuário fornecido: $SUDO_USER"
    else
        log_error "Nome de usuário inválido fornecido em --user: '$SUDO_USER_ARG'"
        if [[ "${AUTO_MODE:-false}" == true ]]; then
            log_error "Modo automático: abortando devido a usuário inválido."
            exit 1
        fi
    fi
fi

if [[ -z "$SUDO_USER" ]]; then
    # modo interativo
    while true; do
        read -p "Digite o nome do usuário que terá privilégios de sudo: " SUDO_USER
        if validate_username "$SUDO_USER"; then
            break
        else
            log_error "Nome inválido. Use apenas [a-z0-9_-], começar por letra ou _, máx 32 chars e não 'root'."
        fi
    done
fi

if id "$SUDO_USER" &>/dev/null; then
    log_info "Usuário $SUDO_USER já existe."
    if ! groups "$SUDO_USER" | grep -q sudo; then
        usermod -aG sudo "$SUDO_USER"
        log_success "Usuário $SUDO_USER adicionado ao grupo sudo."
    else
        log_info "Usuário $SUDO_USER já tem privilégios sudo."
    fi
else
    adduser "$SUDO_USER"
    usermod -aG sudo "$SUDO_USER"
    log_success "Usuário $SUDO_USER criado e adicionado ao grupo sudo."
fi

# ================= COLETA DE OPÇÕES (MODO AFK) =================
log_step "Coletando preferências de instalação"

# Se flag --auto foi passada, definir defaults (sim para essenciais, não para extras pesados)
AUTO_MODE=${AUTO_MODE:-false}
for arg in "$@"; do
    if [[ "$arg" == "--auto" ]]; then
         AUTO_MODE=true
    fi
done

ask_yes_no() {
    local prompt="$1"; local default="$2"; local var
    if $AUTO_MODE; then
         echo "$default"
         return 0
    fi
    while true; do
         read -p "$prompt (s/n) [default: $default]: " var
         if [[ -z "$var" ]]; then var="$default"; fi
         case $var in
             [SsYy]* ) echo "s"; return 0;;
             [Nn]* ) echo "n"; return 0;;
             * ) echo "Digite s ou n";;
         esac
    done
}

# Perguntas agrupadas
OPT_DEB_MULTIMEDIA=$(ask_yes_no "Adicionar repositório deb-multimedia? (pode causar conflitos)" n)
OPT_REMOVE_GAMES=$(ask_yes_no "Remover LibreOffice e jogos do GNOME?" s)
OPT_REMOVE_FIREFOX=$(ask_yes_no "Remover Firefox ESR (firefox-esr)?" n)
OPT_INSTALL_FLATPAK_APPS=$(ask_yes_no "Instalar aplicativos Flatpak recomendados?" s)
OPT_LINUX_TOYS=$(ask_yes_no "Instalar Linux Toys?" n)
OPT_DRIVERS_INTEL=$(ask_yes_no "Instalar drivers Intel?" s)
OPT_DRIVERS_AMD=$(ask_yes_no "Instalar drivers AMD?" n)
OPT_DRIVERS_NVIDIA=$(ask_yes_no "Instalar drivers NVIDIA?" n)
OPT_NVIDIA_CUDA=n
if [[ "$OPT_DRIVERS_NVIDIA" == "s" ]]; then
    OPT_NVIDIA_CUDA=$(ask_yes_no "Adicionar suporte CUDA?" n)
fi
OPT_RUN_CUSTOMIZE=$(ask_yes_no "Executar script de customização do GNOME ao final?" s)

echo ""; log_step "Resumo das escolhas"
echo "  deb-multimedia:        $OPT_DEB_MULTIMEDIA"
echo "  Remover LibreOffice:   $OPT_REMOVE_GAMES"
echo "  Flatpak apps:          $OPT_INSTALL_FLATPAK_APPS"
echo "  Remover Firefox ESR:   $OPT_REMOVE_FIREFOX"
echo "  Linux Toys:            $OPT_LINUX_TOYS"
echo "  Drivers Intel:         $OPT_DRIVERS_INTEL"
echo "  Drivers AMD:           $OPT_DRIVERS_AMD"
echo "  Drivers NVIDIA:        $OPT_DRIVERS_NVIDIA (CUDA: $OPT_NVIDIA_CUDA)"
echo "  Customização GNOME:    $OPT_RUN_CUSTOMIZE"
echo ""
if ! $AUTO_MODE; then
    read -p "Pressione ENTER para iniciar ou Ctrl+C para cancelar..." _
fi

# Backup do sources.list
log_step "Fazendo backup das configurações..."
cp /etc/apt/sources.list /etc/apt/sources.list.backup.$(date +%Y%m%d_%H%M%S)
log_success "Backup do sources.list criado."

# Modificar sources.list apenas se necessário
log_step "Configurando repositórios..."
if ! grep -q "contrib non-free" /etc/apt/sources.list; then
    sed -i 's/main$/main contrib non-free non-free-firmware/' /etc/apt/sources.list
    log_success "Repositórios contrib, non-free e non-free-firmware adicionados."
else
    log_info "Repositórios contrib e non-free já configurados."
fi

# Repositório backports
BACKPORTS_FILE="/etc/apt/sources.list.d/backports.list"
if [ ! -f "$BACKPORTS_FILE" ]; then
    echo "deb http://deb.debian.org/debian $DEBIAN_VERSION-backports main contrib non-free non-free-firmware" > "$BACKPORTS_FILE"
    log_success "Repositório backports adicionado."
else
    log_info "Repositório backports já configurado."
fi

# Atualizar repositórios
log_step "Atualizando repositórios..."
apt update && check_command "Atualização de repositórios"

# Repositório multimedia (decisão prévia)
if [[ "$OPT_DEB_MULTIMEDIA" == "s" ]]; then
    MULTIMEDIA_FILE="/etc/apt/sources.list.d/deb-multimedia.list"
    if [ ! -f "$MULTIMEDIA_FILE" ]; then
        echo "deb https://www.deb-multimedia.org $DEBIAN_VERSION main non-free" > "$MULTIMEDIA_FILE"
        log_info "Adicionando chave do deb-multimedia..."
        
        # Tentar instalar a chave de forma mais segura
        if wget -q -O- https://www.deb-multimedia.org/pool/main/d/deb-multimedia-keyring/deb-multimedia-keyring_2016.8.1_all.deb -O /tmp/deb-multimedia-keyring.deb; then
            dpkg -i /tmp/deb-multimedia-keyring.deb || true
            rm -f /tmp/deb-multimedia-keyring.deb
            apt update
            log_success "Repositório deb-multimedia configurado."
        else
            log_warn "Falha ao configurar deb-multimedia. Removendo repositório."
            rm -f "$MULTIMEDIA_FILE"
        fi
    else
        log_info "Repositório deb-multimedia já configurado."
    fi
fi

# Instalação de pacotes essenciais
log_step "Instalando pacotes essenciais..."
ESSENTIAL_PACKAGES=(
    "build-essential"
    "curl"
    "wget"
    "git"
    "vim"
    "btop"
    "htop"
    "fastfetch"
    "unzip"
    "gnome-tweaks"
    "gnome-shell-extensions"
    "gnome-shell-extension-prefs"
    "gnome-software"
    "flatpak"
    "gnome-software-plugin-flatpak"
    "apt-transport-https"
    "ca-certificates"
    "gnupg"
    "lsb-release"
)

for package in "${ESSENTIAL_PACKAGES[@]}"; do
    if ! dpkg -l | grep -q "^ii  $package "; then
        log_info "Instalando $package..."
        apt install -y "$package" && log_success "$package instalado" || log_warn "Falha ao instalar $package"
    else
        log_info "$package já está instalado."
    fi
done

# Remover LibreOffice e jogos
if [[ "$OPT_REMOVE_GAMES" == "s" ]]; then
    log_step "Removendo LibreOffice e jogos GNOME (modo simples)..."
    REMOVE_PKGS=(
        libreoffice-common gnome-games
    )
    if apt purge -y "${REMOVE_PKGS[@]}" --autoremove 2>/dev/null; then
        log_success "Pacotes solicitados purgados (os ausentes foram ignorados)."
    else
        log_warn "Alguns pacotes podem já não estar instalados ou falhou parte da remoção."
    fi
    apt autoremove -y --purge || true
    apt autoclean || true
    log_success "Limpeza concluída."
fi

# Remoção do Firefox ESR (decisão prévia)
if [[ "$OPT_REMOVE_FIREFOX" == "s" ]]; then
    log_step "Removendo Firefox ESR..."
    log_info "Removendo Firefox ESR..."
    if apt purge -y firefox-esr; then
        log_success "Firefox ESR removido."
    else
        log_warn "Falha ao remover o Firefox ESR. Verifique manualmente."
    fi
    apt autoremove -y && apt autoclean
fi

# Setup de Flatpak
log_step "Configurando Flatpak..."
if ! flatpak remote-list | grep -q flathub; then
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    log_success "Repositório Flathub adicionado."
else
    log_info "Repositório Flathub já configurado."
fi

log_info "Atualizando Flatpak..."
flatpak update -y && check_command "Atualização do Flatpak"

# Instalação de aplicativos Flatpak (decisão prévia)
if [[ "$OPT_INSTALL_FLATPAK_APPS" == "s" ]]; then
    log_step "Instalando aplicativos Flatpak..."
    
    FLATPAK_APPS=(
        "org.gnome.gedit"
        "org.onlyoffice.desktopeditors"
        "org.gnome.NetworkDisplays"
        "org.angryip.ipscan"
        "com.notesnook.Notesnook"
        "com.anydesk.Anydesk"
        "org.localsend.localsend_app"
        "io.missioncenter.MissionCenter"
        "com.google.Chrome"
        "com.rtosta.zapzap"
        "it.mijorus.gearlever"
        "com.termius.Termius"
        "com.spotify.Client"
        "com.mattjakeman.ExtensionManager"
    )
    
    for app in "${FLATPAK_APPS[@]}"; do
        if ! flatpak list | grep -Fq "$app"; then
            log_info "Instalando $app..."
            if flatpak install --noninteractive -y flathub "$app" >/dev/null 2>&1; then
                log_success "$app instalado"
            else
                log_warn "Falha ao instalar $app (pode não estar disponível)"
            fi
        else
            log_info "$app já está instalado."
        fi
    done
fi


# Instalação do Linux Toys (decisão prévia)


if [[ "$OPT_LINUX_TOYS" == "s" ]]; then
    log_step "Instalando Linux Toys..."
    log_info "Baixando e executando instalador do Linux Toys..."
    if yes | sh -c "$(curl -fsSL https://raw.githubusercontent.com/psygreg/linuxtoys/master/install.sh)"; then
        log_success "Linux Toys instalado com sucesso"
    else
        log_info "Não foi possivel determinar se o Linux Toys foi instalado corretamente, verifique manualmente."
    fi
fi

# Setup drivers com validação
log_step "Configurando drivers..."

# Drivers Intel (decisão prévia)
if [[ "$OPT_DRIVERS_INTEL" == "s" ]]; then
    log_info "Instalando drivers Intel..."
    INTEL_PACKAGES=(
        "intel-media-va-driver"
        "i965-va-driver"
        "intel-microcode"
        "mesa-va-drivers"
    )
    
    for package in "${INTEL_PACKAGES[@]}"; do
        apt install -y "$package" 2>/dev/null && log_success "$package instalado" || log_warn "Falha ao instalar $package"
    done
fi

# Drivers AMD (decisão prévia)
if [[ "$OPT_DRIVERS_AMD" == "s" ]]; then
    log_info "Instalando drivers AMD..."
    AMD_PACKAGES=(
        "firmware-linux"
        "firmware-linux-nonfree"
        "libdrm-amdgpu1"
        "mesa-va-drivers"
        "mesa-vdpau-drivers"
    )
    
    for package in "${AMD_PACKAGES[@]}"; do
        apt install -y "$package" 2>/dev/null && log_success "$package instalado" || log_warn "Falha ao instalar $package"
    done
fi

# Drivers NVIDIA (decisão prévia)
if [[ "$OPT_DRIVERS_NVIDIA" == "s" ]]; then
    log_info "Instalando drivers NVIDIA..."
    
    # Verificar se há placa NVIDIA
    if lspci | grep -i nvidia > /dev/null; then
        NVIDIA_PACKAGES=(
            "nvidia-driver"
            "nvidia-settings"
            "firmware-misc-nonfree"
        )
        
        # CUDA decisão prévia
        if [[ "$OPT_NVIDIA_CUDA" == "s" ]]; then
            NVIDIA_PACKAGES+=( "nvidia-cuda-dev" "nvidia-cuda-toolkit" )
        fi
        
        for package in "${NVIDIA_PACKAGES[@]}"; do
            apt install -y "$package" 2>/dev/null && log_success "$package instalado" || log_warn "Falha ao instalar $package"
        done
        
        log_warn "REINICIALIZAÇÃO NECESSÁRIA para ativar os drivers NVIDIA!"
    else
        log_warn "Nenhuma placa NVIDIA detectada. Pulando instalação."
    fi
fi

# Atualização final do sistema
log_step "Realizando atualização final do sistema..."
apt update && apt upgrade -y && check_command "Atualização do sistema"

# Limpeza final
log_step "Realizando limpeza final..."
apt autoremove -y && apt autoclean
log_success "Limpeza concluída."

# Executar customização do GNOME (decisão prévia)
if [[ "$OPT_RUN_CUSTOMIZE" == "s" ]]; then
    log_step "Executando customização do GNOME (como usuário $SUDO_USER)..."
    USER_HOME=$(eval echo ~"$SUDO_USER" 2>/dev/null || echo "/home/$SUDO_USER")
    if [[ ! -d "$USER_HOME" ]]; then
        log_warn "Home $USER_HOME não encontrada; pulando customização."
    else
        CUSTOMIZE_CMD="curl -fsSL $GITHUB_CUSTOMIZE_URL | bash"
        # Exportar HOME explicitamente para evitar herdar /root
        if sudo -u "$SUDO_USER" HOME="$USER_HOME" bash -c "$CUSTOMIZE_CMD"; then
            log_success "Customização do GNOME executada com sucesso (usuário $SUDO_USER)"
        else
            log_warn "Falha na customização do GNOME. Execute manualmente como $SUDO_USER se necessário:"
            echo "  sudo -u $SUDO_USER HOME=$USER_HOME bash -c 'curl -fsSL $GITHUB_CUSTOMIZE_URL | bash'"
        fi
    fi
fi

# Resumo final dinâmico
echo ""
log_step "INSTALAÇÃO CONCLUÍDA!"
echo ""
log_info "🎉 Resumo do que foi configurado:"
echo "  ✓ Sistema base Debian $DEBIAN_VERSION atualizado"
echo "  ✓ Usuário sudo: $SUDO_USER"
echo "  ✓ Repositórios: contrib, non-free, non-free-firmware, backports"
echo "  ✓ Pacotes essenciais"

if [[ "$OPT_DEB_MULTIMEDIA" == "s" ]]; then
    echo "  ✓ Repositório deb-multimedia adicionado"
fi
if [[ "$OPT_REMOVE_GAMES" == "s" ]]; then
    echo "  ✓ LibreOffice e jogos GNOME removidos"
fi
if [[ "$OPT_REMOVE_FIREFOX" == "s" ]]; then
    echo "  ✓ Firefox ESR removido"
fi
if flatpak remote-list | grep -q flathub; then
    echo "  ✓ Flatpak + Flathub configurados"
fi
if [[ "$OPT_INSTALL_FLATPAK_APPS" == "s" ]]; then
    echo "  ✓ Aplicativos Flatpak instalados"
fi
if [[ "$OPT_LINUX_TOYS" == "s" ]]; then
    echo "  ✓ Linux Toys instalado"
fi
if [[ "$OPT_DRIVERS_INTEL" == "s" ]]; then
    echo "  ✓ Drivers Intel instalados"
fi
if [[ "$OPT_DRIVERS_AMD" == "s" ]]; then
    echo "  ✓ Drivers AMD instalados"
fi
if [[ "$OPT_DRIVERS_NVIDIA" == "s" ]]; then
    if lspci | grep -i nvidia >/dev/null; then
        echo "  ✓ Drivers NVIDIA instalados${OPT_NVIDIA_CUDA:+ (CUDA)}"
    else
        echo "  ⚠ Selecionado NVIDIA mas nenhuma GPU detectada"
    fi
fi
if [[ "$OPT_RUN_CUSTOMIZE" == "s" ]]; then
    echo "  ✓ Customização GNOME executada"
fi
echo ""
log_warn "📋 PRÓXIMOS PASSOS RECOMENDADOS:"
echo "  1. REINICIE o sistema para ativar todos os drivers"
echo "  2. Faça logout/login para aplicar as configurações do usuário"
echo "  3. Configure suas extensões GNOME em 'Extensões'"
echo "  4. Personalize temas e configurações em 'Ajustes'"
echo "  5. Execute 'flatpak update' periodicamente para atualizações"
echo ""
log_info "💡 COMANDOS ÚTEIS:"
echo "  • Atualizar sistema: sudo apt update && sudo apt upgrade"
echo "  • Atualizar Flatpak: flatpak update"
echo "  • Gerenciar extensões: gnome-extensions list"
echo ""
log_success "🚀 Sistema Debian pronto para uso! Aproveite!"