# torrent-stack

[🇺🇸 English](README.md) | [🇧🇷 Português (BR)](README.pt-BR.md)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Docker Compose](https://img.shields.io/badge/Docker%20Compose-v2-2496ED?logo=docker&logoColor=white)](https://docs.docker.com/compose/)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux-lightgrey)](#pré-requisitos)

Uma stack auto-hospedada de busca e download de torrents: **qBittorrent** para baixar, **Jackett** como proxy de indexers e **FlareSolverr** para passar por indexers protegidos pelo Cloudflare — tudo orquestrado com Docker Compose.

## Visão geral

Este repositório empacota um setup pequeno e reproduzível:

- **qBittorrent** — cliente de torrent com interface web, onde você busca e baixa.
- **Jackett** — traduz consultas para diversos indexers e expõe uma única API de busca.
- **FlareSolverr** — proxy que resolve desafios do Cloudflare para os indexers que precisam.

Depois de configurado, você busca na aba **Search** do qBittorrent e os resultados vêm do Jackett.

## Pré-requisitos

- **Docker Engine** com o plugin **Compose v2** (`docker compose version`). Seu usuário precisa poder executar Docker (por exemplo, estar no grupo `docker` no Linux).
- **Git** para clonar o repositório.
- **GNU Make** (`make --version`).
- **Bash** — o `make jackett` executa um script bash.
- Portas livres no host: `8080`, `6881` TCP, `6881` UDP e `9117`.
- No **Windows**, use **WSL2** (com a integração do Docker Desktop) e clone o repositório dentro do filesystem do WSL.

> **Dica WSL2:** rodar a stack a partir de `/mnt/c/...` funciona, mas o I/O de arquivos e os bind mounts ficam mais lentos. Prefira um caminho dentro do WSL, como `~/torrent-stack`, e garanta que `PUID`/`PGID` correspondam ao seu usuário do WSL (`id -u`, `id -g`).

## Início rápido

### 1. Clone e configure

```bash
git clone <repository-url> torrent-stack
cd torrent-stack
cp .env.example .env
```

Edite o `.env`:

- `PUID` / `PGID` — rode `id -u` e `id -g`.
- `TZ` — seu fuso horário, por exemplo `America/Sao_Paulo`.
- `DOWNLOADS_PATH` — para bibliotecas grandes, recomenda-se um caminho absoluto.
- `QBITTORRENT_WEBUI_PORT` / `QBITTORRENT_TORRENTING_PORT` — altere se as portas padrão estiverem ocupadas.

### 2. Suba a stack

```bash
make up
```

Na primeira execução, as imagens são baixadas e as pastas configuradas em `CONFIG_PATH` e `DOWNLOADS_PATH` são criadas. O qBittorrent só inicia depois que o Jackett passa no healthcheck.

Confira se todos os serviços estão rodando:

```bash
docker compose ps
```

### 3. Defina a senha do qBittorrent

```bash
docker compose logs qbittorrent --tail 50 | grep -i "temporary password"
```

Abra <http://localhost:8080> (ou a `QBITTORRENT_WEBUI_PORT` que você configurou), entre como `admin` com a senha temporária e troque a senha em **Settings → WebUI**.

Se o comando não mostrar nada, rode `docker compose logs qbittorrent` e procure por `temporary password`. Ela só é exibida na primeira inicialização, antes de uma senha ser definida; se o diretório `CONFIG_PATH` já existe de uma execução anterior, use a senha que você já configurou.

### 4. Instale o plugin de busca do Jackett

No qBittorrent, abra a aba **Search**, clique em **Search plugins...**, depois em **Install new plugin**, e cole:

```text
https://raw.githubusercontent.com/qbittorrent/search-plugins/master/nova3/engines/jackett.py
```

### 5. Configure o Jackett

Abra <http://localhost:9117> e:

1. Defina **FlareSolverr API URL** como `http://flaresolverr:8191` e salve. Isso é configurado na UI do Jackett, não no `.env`. O FlareSolverr é opcional: só é usado por indexers protegidos pelo Cloudflare, mas configurá-lo agora evita surpresas depois.
2. Adicione os indexers que você prefere com o botão **Add indexer**. Alguns indexers exigem conta ou API key; o Jackett mostra os campos necessários. Use **Test** em cada indexer para confirmar que funciona.

### 6. Conecte o qBittorrent ao Jackett

```bash
make jackett
make restart
```

Rode isso depois de instalar o plugin do passo 4 e depois que o Jackett tiver subido pela primeira vez. O `make jackett` lê a API key e a URL interna (`http://jackett:<porta>`, normalmente `http://jackett:9117`) de `$CONFIG_PATH/Jackett/ServerConfig.json` (padrão: `./config`) e grava essas informações na configuração do plugin Jackett do qBittorrent. O script mostra a API key mascarada e a URL gravada. O `make restart` recarrega o qBittorrent com a nova configuração do plugin.

### 7. Busque

No qBittorrent, abra **Search**, digite uma consulta e escolha um indexer. Os resultados devem aparecer.

## Configuração

Todas as variáveis ficam no `.env`:

| Variável | Padrão | Descrição |
| --- | --- | --- |
| `PUID` | `1000` | UID dono dos arquivos criados pelos containers. |
| `PGID` | `1000` | GID dono dos arquivos criados pelos containers. |
| `TZ` | `Etc/UTC` | Fuso horário dos containers. Use o seu fuso local. |
| `CONFIG_PATH` | `./config` | Caminho no host montado em `/config`. |
| `DOWNLOADS_PATH` | `./downloads` | Caminho no host montado em `/downloads`. Compartilhado por qBittorrent e Jackett. |
| `AUTO_UPDATE` | `true` | Atualização automática do Jackett. |
| `RUN_OPTS` | *(vazio)* | Opções extras de execução do Jackett. |
| `LOG_LEVEL` | `info` | Nível de log do FlareSolverr. |
| `LOG_FILE` | `none` | Arquivo de log do FlareSolverr. |
| `LOG_HTML` | `false` | Define se o FlareSolverr registra HTML. |
| `CAPTCHA_SOLVER` | `none` | Solucionador de CAPTCHA do FlareSolverr. |
| `QBITTORRENT_WEBUI_PORT` | `8080` | Porta da WebUI do qBittorrent, usada tanto no mapeamento do host quanto na porta do container. |
| `QBITTORRENT_TORRENTING_PORT` | `6881` | Porta de torrenting do qBittorrent (TCP + UDP), usada tanto no mapeamento do host quanto na porta do container. |

Depois de editar o `.env`, rode `make up` novamente para que o Compose recrie os containers com os novos valores. O `make restart` apenas reinicia os containers existentes e **não** aplica mudanças do `.env`.

O `make jackett` resolve o `CONFIG_PATH` da mesma forma que o Compose, então funciona tanto com o diretório padrão quanto com um diretório personalizado.

`DOWNLOADS_PATH` é um **caminho do host**, não um volume Docker. Para bibliotecas reais, prefira um caminho absoluto em disco rápido, como `/mnt/d/downloads` ou um caminho nativo do WSL como `/home/<usuario>/downloads`. Manter downloads grandes dentro do repositório infla a pasta do projeto, e no WSL2 o mount `/mnt/c` é bem mais lento que o filesystem Linux. Alterar esse valor não move os arquivos existentes; como o caminho no container continua sendo `/downloads`, o caminho de salvamento interno do qBittorrent não precisa mudar.

## Segurança

- **Não exponha o FlareSolverr.** Ele não publica porta e deve permanecer interno à rede do Compose. Publicá-lo na internet pode ser abusado por terceiros.
- **Troque a senha temporária do qBittorrent imediatamente.** As credenciais temporárias padrão aparecem nos logs do container.
- **Mantenha o `.env` fora do Git.** Ele já é ignorado pelo `.gitignore`; não faça commit de segredos ou caminhos pessoais.
- **Proteja a WebUI do qBittorrent.** Não exponha a porta da WebUI diretamente à internet sem autenticação, TLS e um reverse proxy.
- **Não exponha a porta `9117` do Jackett diretamente à internet.** Se precisar de acesso remoto, coloque-o atrás de um reverse proxy com autenticação.
- **Trate a API key do Jackett como segredo.** Ela dá acesso às suas buscas nos indexers.
- **Só exponha a porta de torrenting `6881` se entender as implicações.** Ela é usada para conexões de entrada de peers e pode precisar de port forwarding no roteador para uma boa conectividade, mas também revela seu IP a outros peers.
- **Baixe e compartilhe apenas conteúdo que você tem o direito de usar.** Você é responsável pelo uso desta stack e pelas leis da sua jurisdição.

## Aviso legal

Este projeto é um setup independente e não oficial. Ele **não é afiliado, endossado ou patrocinado** pelo qBittorrent, Jackett, FlareSolverr ou por qualquer indexer ou tracker.

O software é fornecido **"como está"**, sem garantia de qualquer tipo, conforme a [Licença MIT](LICENSE). Você usa esta stack **por sua conta e risco** e é o único responsável por como a configura e a utiliza.

Este projeto não hospeda, fornece ou distribui conteúdo protegido por direitos autorais, e não incentiva nem compactua com violação de direitos autorais. Busque, baixe ou compartilhe apenas conteúdo que você tem o direito legal de acessar. Você é responsável por cumprir as leis da sua jurisdição e os termos de serviço de qualquer indexer ou tracker que utilizar.

Os autores e contribuidores não se responsabilizam por qualquer uso indevido, perda de dados, consequências legais ou danos decorrentes do uso deste projeto.

## Comandos do Make

| Comando | O que faz |
| --- | --- |
| `make up` | Cria e sobe os containers. Recria quando o `.env` muda. |
| `make stop` | Para os containers, mas os mantém. |
| `make start` | Inicia containers que foram parados. |
| `make down` | Para e remove containers e a rede. Mantém `CONFIG_PATH` e `DOWNLOADS_PATH` configurados. |
| `make restart` | Reinicia os containers existentes. Não aplica mudanças do `.env`; use `make up` para isso. |
| `make logs` | Acompanha os logs de todos os serviços. |
| `make jackett` | Grava a API key e a URL interna do Jackett na configuração do plugin do qBittorrent. |
| `make clean` | Executa `down -v --remove-orphans`, removendo volumes. Os bind mounts `CONFIG_PATH` e `DOWNLOADS_PATH` são mantidos. |
| `make help` | Lista todos os alvos disponíveis. |

O `make clean` **não** apaga seus arquivos baixados nem a configuração, porque ambos são bind mounts (`CONFIG_PATH` e `DOWNLOADS_PATH`) e não volumes nomeados. Apague essas pastas manualmente se quiser um reset completo; a próxima inicialização vai gerar uma nova senha temporária para o qBittorrent.

## Referências

- <https://hub.docker.com/r/linuxserver/jackett#application-setup>
- <https://hub.docker.com/r/linuxserver/qbittorrent#application-setup>
- <https://github.com/qbittorrent/search-plugins/wiki/How-to-configure-Jackett-plugin>
- <https://github.com/jackett/jackett#configuring-flaresolverr>
