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

## Modo Automático (AFK)

### setup.sh
Use a flag `--auto` para evitar perguntas após a coleta inicial (ou exporte `AUTO_MODE=true`). Os defaults são:
- Remover LibreOffice/jogos: s
- Remover Firefox ESR: n
- Flatpak apps: s
- Linux Toys: n
- Drivers Intel: s / AMD: n / NVIDIA: n / CUDA: n
- Customização GNOME: s

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
	OPT_RUN_CUSTOMIZE=s \
	AUTO_MODE=true bash setup.sh --auto --user=seuusuario
```

### customize.sh
Também suporta modo automático:
- Flag: `--auto`
- Variáveis:
	- `AUTO_INSTALL_EXT=s|n` (default s)
	- `AUTO_APPLY_SETTINGS=s|n` (default s)
	- `AUTO_FORCE_OUTSIDE_GNOME=s` para rodar fora do GNOME

Exemplos:
```bash
# Tudo automático
bash customize.sh --auto

# Apenas aplicar configurações, sem instalar extensões
AUTO_MODE=true AUTO_INSTALL_EXT=n bash customize.sh --auto

# Forçar execução fora do GNOME
AUTO_MODE=true AUTO_FORCE_OUTSIDE_GNOME=s bash customize.sh --auto
```


## Extensões GNOME

Instala e ativa automaticamente todas as extensões pré-definidas exceto:
- dash-to-dock@micxgx.gmail.com (instalada mas não ativada)

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
| Flatpak prompt versão ffmpeg-full | Runtime antigo fixado | Atualizar script (já inclui detecção nas versões recentes) |

## Aviso

Revise os scripts antes de usar em produção.

## Licença
Este projeto é distribuído sob a licença MIT.
