# torrent-stack

[🇺🇸 English](README.md) | [🇧🇷 Português (BR)](README.pt-BR.md)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Docker Compose](https://img.shields.io/badge/Docker%20Compose-v2-2496ED?logo=docker&logoColor=white)](https://docs.docker.com/compose/)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux-lightgrey)](#pré-requisitos)

A self-hosted torrent search and download stack: **qBittorrent** for downloading, **Jackett** as an indexer proxy, **FlareSolverr** to get past Cloudflare-protected indexers, and **Bazarr+** for subtitles — all orchestrated with Docker Compose.

## Overview

This repository packages a small, reproducible torrent setup:

- **qBittorrent** — torrent client with a web UI, where you search and download.
- **Jackett** — translates queries to many indexers and exposes a single search API.
- **FlareSolverr** — proxy that solves Cloudflare challenges for indexers that require it.
- **Bazarr+** — subtitle manager for movies, shows and sports. It works on its own, with no media library attached.

Once configured, you search from qBittorrent's **Search** tab and the results come from Jackett. Bazarr+ runs independently of that search flow: its **Discover** page searches for any title and downloads subtitles for it.

## Prerequisites

- **Docker Engine** with the **Compose v2** plugin (`docker compose version`). Your user must be able to run Docker (for example, be in the `docker` group on Linux).
- **Git** to clone the repository.
- **GNU Make** (`make --version`).
- **Bash** — `make jackett` runs a bash script.
- Free host ports: `8080`, `6881` TCP, `6881` UDP, `6767`, and `9117`.
- On **Windows**, use **WSL2** (with Docker Desktop WSL integration) and clone the repository inside the WSL filesystem.

> **WSL2 tip:** running the stack from `/mnt/c/...` works, but file I/O and bind mounts are slower. Prefer a path inside WSL such as `~/torrent-stack`, and make sure `PUID`/`PGID` match your WSL user (`id -u`, `id -g`).

## Quick Start

### 1. Clone and configure

```bash
git clone <repository-url> torrent-stack
cd torrent-stack
cp .env.example .env
```

Edit `.env`:

- `PUID` / `PGID` — run `id -u` and `id -g`.
- `TZ` — your timezone, e.g. `America/Sao_Paulo`.
- `DOWNLOADS_PATH` — an absolute path is recommended for real libraries.
- `QBITTORRENT_WEBUI_PORT` / `QBITTORRENT_TORRENTING_PORT` — change them if the defaults are taken.

### 2. Start the stack

```bash
make up
```

The first run pulls the images and creates the configured `CONFIG_PATH` and `DOWNLOADS_PATH` directories. qBittorrent only starts after Jackett passes its healthcheck.

Check that all services are running:

```bash
docker compose ps
```

### 3. Set the qBittorrent password

```bash
docker compose logs qbittorrent --tail 50 | grep -i "temporary password"
```

Open <http://localhost:8080> (or the `QBITTORRENT_WEBUI_PORT` you configured), log in as `admin` with the temporary password, then change it under **Settings → WebUI**.

If the command prints nothing, run `docker compose logs qbittorrent` and search for `temporary password`. It is only printed on the first start, before a password is set; if your `CONFIG_PATH` directory already exists from a previous run, use the password you already configured.

### 4. Install the Jackett search plugin

In qBittorrent, open the **Search** tab, click **Search plugins...**, then **Install new plugin**, and paste:

```text
https://raw.githubusercontent.com/qbittorrent/search-plugins/master/nova3/engines/jackett.py
```

### 5. Configure Jackett

Open <http://localhost:9117> and:

1. Set **FlareSolverr API URL** to `http://flaresolverr:8191` and save. This is configured in Jackett's UI, not in `.env`. FlareSolverr is optional: it is only used by Cloudflare-protected indexers, but configuring it now avoids surprises later.
2. Add your preferred indexers with the **Add indexer** button. Some indexers require an account or API key; Jackett shows the required fields. Use **Test** on each indexer to confirm it works.

### 6. Connect qBittorrent to Jackett

```bash
make jackett
make restart
```

Run this after installing the plugin in step 4 and after Jackett has started for the first time. `make jackett` reads the API key and internal URL (`http://jackett:<port>`, usually `http://jackett:9117`) from `$CONFIG_PATH/Jackett/ServerConfig.json` (default: `./config`) and writes them to qBittorrent's Jackett plugin config. The script prints the masked API key and the URL it wrote. `make restart` reloads qBittorrent with the new plugin configuration.

### 7. Search

In qBittorrent, open **Search**, type a query, and pick an indexer. Results should appear.

### 8. Find subtitles with Bazarr+

Open <http://localhost:6767>. Bazarr+ works with no library attached: **Discover** is the home page, and you can search any movie or show by title or IMDb ID, preview the available subtitles, and download one. Metadata comes from TMDB through a built-in key, so there is nothing to configure first.

If you already run Sonarr, Radarr, or Sportarr elsewhere, connect it under **Settings → Connections** to automate subtitles for that library. Those applications are not part of this stack, so Bazarr+ only manages media they already track.

Bazarr+ stores its data in `$CONFIG_PATH/bazarr` (default: `./config/bazarr`), separate from the Jackett and qBittorrent folders.

## Configuration

All variables live in `.env`:

| Variable                      | Default       | Description                                                                                     |
| ----------------------------- | ------------- | ----------------------------------------------------------------------------------------------- |
| `PUID`                        | `1000`        | UID that owns the files created by the containers.                                              |
| `PGID`                        | `1000`        | GID that owns the files created by the containers.                                              |
| `TZ`                          | `Etc/UTC`     | Container timezone. Use your local timezone.                                                    |
| `CONFIG_PATH`                 | `./config`    | Host path bind-mounted to `/config`.                                                            |
| `DOWNLOADS_PATH`              | `./downloads` | Host path bind-mounted to `/downloads`. Shared by qBittorrent and Jackett.                      |
| `AUTO_UPDATE`                 | `true`        | Jackett auto-update.                                                                            |
| `RUN_OPTS`                    | _(empty)_     | Extra Jackett runtime options.                                                                  |
| `LOG_LEVEL`                   | `info`        | FlareSolverr log level.                                                                         |
| `LOG_FILE`                    | `none`        | FlareSolverr log file.                                                                          |
| `LOG_HTML`                    | `false`       | Whether FlareSolverr logs HTML.                                                                 |
| `CAPTCHA_SOLVER`              | `none`        | FlareSolverr CAPTCHA solver.                                                                    |
| `QBITTORRENT_WEBUI_PORT`      | `8080`        | qBittorrent WebUI port, used for both the host mapping and the container port.                  |
| `QBITTORRENT_TORRENTING_PORT` | `6881`        | qBittorrent torrenting port (TCP + UDP), used for both the host mapping and the container port. |

After editing `.env`, run `make up` again so Compose recreates the containers with the new values. `make restart` only restarts the existing containers and does **not** apply `.env` changes.

Bazarr+ needs no variables of its own: it reuses `PUID`, `PGID`, `TZ`, and `CONFIG_PATH`, and keeps its files under `$CONFIG_PATH/bazarr` so they do not mix with the other services' data.

`make jackett` resolves `CONFIG_PATH` the same way Compose does, so it works with both the default and a custom config directory.

`DOWNLOADS_PATH` is a **host path**, not a Docker volume. For real libraries, prefer an absolute path on a fast disk, for example `/mnt/d/downloads` or a WSL-native path such as `/home/<user>/downloads`. Keeping large downloads inside the repository bloats the project folder, and on WSL2 the `/mnt/c` mount is noticeably slower than the Linux filesystem. Changing this value does not move existing files; because the container path stays `/downloads`, qBittorrent's internal save path does not need to change.

## Security Notes

- **Do not expose FlareSolverr.** It has no published port and should stay internal to the Compose network. Publishing it to the internet can be abused by third parties.
- **Change the temporary qBittorrent password immediately.** The default temporary credentials are printed in the container logs.
- **Keep `.env` out of Git.** It is already ignored by `.gitignore`; do not commit secrets or personal paths.
- **Protect the qBittorrent WebUI.** Do not expose the WebUI port directly to the internet without authentication, TLS, and a reverse proxy.
- **Do not expose Jackett's port `9117` directly to the internet.** If you need remote access, put it behind a reverse proxy with authentication.
- **Treat the Jackett API key as a secret.** It grants access to your indexer searches.
- **Only expose the torrenting port `6881` if you understand the implications.** It is used for incoming peer connections and may need to be forwarded on your router for good connectivity, but it also reveals your IP to peers.
- **Protect Bazarr+ if you expose it.** Port `6767` is published for convenience; keep it behind a reverse proxy with authentication and TLS before making it reachable from the internet.
- **Only download and share content you have the rights to.** You are responsible for how you use this stack and for the laws in your jurisdiction.

## Disclaimer

This project is an independent, unofficial setup. It is **not affiliated with, endorsed by, or sponsored by** qBittorrent, Jackett, FlareSolverr, Bazarr+, or any indexer or tracker.

The software is provided **"as is"**, without warranty of any kind, as stated in the [MIT License](LICENSE). You use this stack **at your own risk** and are solely responsible for how you configure and use it.

This project does not host, provide, or distribute any copyrighted content, and it does not encourage or condone copyright infringement. Only search for, download, or share content you have the legal right to access. You are responsible for complying with the laws of your jurisdiction and with the terms of service of any indexer or tracker you use.

The authors and contributors are not responsible for any misuse, data loss, legal consequences, or damages resulting from the use of this project.

## Make Commands

| Command        | What it does                                                                                                     |
| -------------- | ---------------------------------------------------------------------------------------------------------------- |
| `make up`      | Creates and starts the containers. Recreates them when `.env` changes.                                           |
| `make stop`    | Stops the containers but keeps them.                                                                             |
| `make start`   | Starts previously stopped containers.                                                                            |
| `make down`    | Stops and removes containers and the network. Keeps the configured `CONFIG_PATH` and `DOWNLOADS_PATH`.           |
| `make restart` | Restarts the existing containers. Does not apply `.env` changes; use `make up` for that.                         |
| `make logs`    | Follows the logs of all services.                                                                                |
| `make jackett` | Writes Jackett's API key and internal URL into the qBittorrent plugin config.                                    |
| `make clean`   | Runs `down -v --remove-orphans`, removing volumes. The bind-mounted `CONFIG_PATH` and `DOWNLOADS_PATH` are kept. |
| `make help`    | Lists every available target.                                                                                    |

`make clean` does **not** delete your downloaded files or configuration, because both are bind mounts (`CONFIG_PATH` and `DOWNLOADS_PATH`) rather than named volumes. Delete those folders manually if you want a full reset; the next start will generate a new qBittorrent temporary password.

## References

- <https://hub.docker.com/r/linuxserver/jackett#application-setup>
- <https://hub.docker.com/r/linuxserver/qbittorrent#application-setup>
- <https://github.com/qbittorrent/search-plugins/wiki/How-to-configure-Jackett-plugin>
- <https://github.com/jackett/jackett#configuring-flaresolverr>
- <https://github.com/LavX/bazarr#what-is-bazarr>
- <https://lavx.github.io/bazarr/guides/getting-started.html>
