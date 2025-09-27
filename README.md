# Debian Pos-instalação Script

Scripts para padronizar a instalação inicial do Debian e aplicar customizações no GNOME de acordo com o meu uso pessoal.

## Arquivos

- `setup.sh` – Instala pacotes essenciais, repositórios, Flatpak, drivers. Fornece link para customização manual.
- `customize.sh` – Baixa ZIP de extensões, extrai no diretório correto e aplica configurações básicas do GNOME.

## Uso Rápido

Durante a execução você poderá:
- Criar/atribuir usuário sudo
- Instalar pacotes essenciais
- Configurar Flatpak
- Instalar drivers (Intel/AMD/NVIDIA)
- Obter link para customização manual do GNOME

Para rodar o script:

```bash
sudo bash -c "$(wget -qLO - https://raw.githubusercontent.com/rafaelhschuh/debian-post-install/refs/heads/main/setup.sh)"
```

## Modo Automático (AFK)

### setup.sh
Use a flag `--auto` para evitar perguntas após a coleta inicial (ou exporte `AUTO_MODE=true`). Os defaults são:
- Remover LibreOffice/jogos: s
- Remover Firefox ESR: n
- Flatpak apps: s
- Linux Toys: n
- Drivers Intel: s / AMD: n / NVIDIA: n / CUDA: n

Execução direta (defaults):
```bash
sudo AUTO_MODE=true bash setup.sh --auto --user=seuusuario
```

Personalizando (exemplo):
```bash
sudo \
	OPT_DEB_MULTIMEDIA=n \
	OPT_REMOVE_GAMES=s \
	OPT_REMOVE_FIREFOX=s \
	OPT_INSTALL_FLATPAK_APPS=s \
	OPT_LINUX_TOYS=n \
	OPT_DRIVERS_INTEL=s \
	OPT_DRIVERS_AMD=n \
	OPT_DRIVERS_NVIDIA=s \
	OPT_NVIDIA_CUDA=n \
	AUTO_MODE=true bash setup.sh --auto --user=seuusuario
```

### customize.sh
Script simples e automático (sem perguntas):
- Baixa ZIP fixo de extensões
- Extrai diretamente em `~/.local/share/gnome-shell/extensions`
- Aplica configurações básicas do GNOME (bateria, relógio, botões, Nautilus, etc.)

Execução:
```bash
# Execução direta
curl -fsSL https://raw.githubusercontent.com/rafaelhschuh/debian-post-install/refs/heads/main/customize.sh | bash

# Ou baixar e executar
wget https://raw.githubusercontent.com/rafaelhschuh/debian-post-install/refs/heads/main/customize.sh
bash customize.sh
```


## Extensões GNOME

O `customize.sh` extrai todas as extensões do ZIP diretamente para o diretório correto. Para ativar:
```bash
# Listar extensões disponíveis
gnome-extensions list

# Ativar uma extensão específica
gnome-extensions enable nome@dominio.extensao

# Ou usar o Extension Manager (instalado via Flatpak)
```

## Remoções Opcionais

As opções de remoção dentro do `setup.sh` quando escolhidas:
- LibreOffice + jogos GNOME: faz `apt purge` em pacote base e executa `autoremove`.
- Firefox ESR: remove `firefox-esr` se presente.

Para adicionar substitutos (ex: Firefox Flatpak) faça depois:
```bash
flatpak install flathub org.mozilla.firefox
```

## Requisitos

- Debian 12+ (ou compatível)
- Ambiente GNOME para `customize.sh`
- Conexão com a internet

## Troubleshooting

| Problema | Causa provável | Solução |
|----------|----------------|---------|
| Repositório deb-multimedia removido | Falha download keyring | Verifique conexão e rode novamente só essa parte manualmente |
| Caracteres quebrados (acentos) | Locale não UTF-8 ativo | Exportar `LANG=pt_BR.UTF-8` antes de rodar |
| Extensão não instala | UUID mudou/versão GNOME nova | Instale manual via loja de extensões e depois adapte a lista |
| Customize 404 | URL `GITHUB_CUSTOMIZE_URL` incorreta | Ajustar variável no topo do `setup.sh` |

## Aviso

Revise os scripts antes de usar em produção.

## Licença
Este projeto é distribuído sob a licença MIT.
