# TastyWSL

WIP - Simple web project + sh files, that wants to add easy flavoring to wsl distro supporting initially ubuntu images

## Execution

Dev:

```cmd
cd scripts
python -m http.server 8080
```

```cmd
irm https://localhost:8080/bootstrap.ps1 | iex
```

## Roadmap

## MVP

- Web: Simples - Puxar uma lista basica de coisas - Pagina web com passo a passo para selecionar e criar arquivos com base nos samples e deixar tudo em um s3

  -- Usar supabase para guardar arquivos

  -- hardcodar por enquanto as opções

- Arquivos .sh/bat e execução.

  -- 00_bootstrap.sh/bat - Checa deps basicas e inicializa o processo - Save in a temp the chosen info

  -- 01_wsl_checking.sh/bat - Checa se WSL/Hyper-V está instalado ou instala

  -- 02_alpine_install.sh/bat - Puxa do repositorio, uma imagem minha alterada para fazer a inicialização (REPO Externo)

  -- 03_alpine_utils.sh - Puxa e baixa todos os outros *.sh com os programas escolhidos e prepara pacotes de utilidades necessario. Baixa imagem tar oficial e checa assinatura

  -- 04_image_package.sh - Faz o processo de empacotar e implantar o .sh final que ira rodar no postinstall da imagem - implanta /etc/wsl.conf a escolha do usuario

  -- 05_Hijacy_and_run.sh - Sequestra credencias, cria um usuario novo e usa ele direto na instalação
  -- 06_postinstall.sh - Termina os processo e faz todos os health checks - Prompt para alterar usuario e senha a escolha do usuario

  -- 07_postinstalluser.sh - Se necessario o usuario terminar a configuração, rodar o necessario auto ou pedir ao usuario - Fazer changelog das mudanças. Oque deu e oque não deu - post anonymous metrics to web system supabase to control

## POCS

[ ] POC 1: Script sample para instalar python

[ ] POC 2: Implementar sistema de arquivos com curl|wget|Outro
