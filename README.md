# Debian Pos-instalação Script

Scripts para padronizar a instalação inicial do Debian e aplicar customizações no GNOME de acordo com o meu uso pessoal.

## Arquivos

- `setup.sh` – Instala pacotes essenciais, repositórios, Flatpak, drivers e (opcional) executa customização.
- `customize.sh` – Restaura extensões do GNOME, aplica configurações e preferências opcionais. (Pode ser executado junto ao setup, será questionado durante o processo)

## Uso Rápido

Durante a execução você poderá:
- Criar/atribuir usuário sudo
- Instalar pacotes essenciais
- Configurar Flatpak
- Instalar drivers (Intel/AMD/NVIDIA)
- Executar customização do GNOME a partir da variável `GITHUB_CUSTOMIZE_URL`

Para rodar o script:

```bash
sudo bash -c "$(wget -qLO - https://raw.githubusercontent.com/rafaelhschuh/debian-post-install/refs/heads/main/setup.sh)"
```

## Modo AFK (Instalação sem interação)

Você pode deixar tudo automatizado respondendo às perguntas iniciais ou usando `--auto` com variáveis de ambiente.

Modo totalmente automático com defaults:

```bash
sudo AUTO_MODE=true bash setup.sh --auto
```

Personalizando escolhas (exemplo):

```bash
sudo \
	OPT_DEB_MULTIMEDIA=n \
	OPT_REMOVE_GAMES=s \
	OPT_INSTALL_FLATPAK_APPS=s \
	OPT_LINUX_TOYS=n \
	OPT_DRIVERS_INTEL=s \
	OPT_DRIVERS_AMD=n \
	OPT_DRIVERS_NVIDIA=s \
	OPT_NVIDIA_CUDA=n \
	OPT_RUN_CUSTOMIZE=s \
	AUTO_MODE=true bash setup.sh --auto
```

Sem `AUTO_MODE=true` o script ainda mostrará o resumo e aguardará ENTER.


## Extensões GNOME

Instala e ativa automaticamente todas as extensões pré-definidas exceto:
- dash-to-dock@micxgx.gmail.com (instalada mas não ativada)

## Requisitos

- Debian 12+ (ou compatível)
- Ambiente GNOME para `customize.sh`
- Conexão com a internet

## Aviso

Revise os scripts antes de usar em produção.

## Licença
Este projeto é distribuído sob a licença MIT.
