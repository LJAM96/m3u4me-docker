# m3u4me-docker

Downstream Docker wrapper for [m3u4me](https://github.com/andrei-savin/m3u4me) — a self-hosted, local-network M3U playlist manager.

This repo contains **only** Docker packaging. The app source is pulled from upstream at image build time, so this wrapper stays small and tracks the latest upstream automatically via a nightly rebuild.

Upstream license: **GPL-3.0** (see `LICENSE`). Docker image users receive the same rights — image labels point back to the upstream source.

Multi-arch: images are built for `linux/amd64` + `linux/arm64` (Intel/AMD servers, Raspberry Pi 4/5, Apple Silicon, ARM NAS).

## Quick start

```bash
docker compose up -d --build
```

Then open `http://<server-ip>:8080`.

Data persists in `./data/` (`db.json` + `auth.json`). Back that folder up.

## Pin to a version

By default we build upstream `main` (latest). To pin to a stable release, edit `docker-compose.yml`:

```yaml
build:
  args:
    UPSTREAM_REF: v2.0.0
```

and rebuild:

```bash
docker compose up -d --build
```

Available upstream tags: see https://github.com/andrei-savin/m3u4me/tags

## Use the prebuilt image (GHCR)

Once the GitHub Action has run at least once:

```bash
docker run -d \
  --name m3u4me \
  -p 8080:8080 \
  -v ./data:/app/data \
  -e PORT=8080 \
  --restart unless-stopped \
  ghcr.io/ljam96/m3u4me-docker:latest
```

## How auto-update works

`.github/workflows/build.yml` (once nightly at 3am, plus on wrapper pushes and manual runs):

- resolves upstream `main` to a commit SHA and skips the build if that commit was already built — idle nights finish in seconds
- on a new upstream commit, builds for `linux/amd64` + `linux/arm64` and pushes to `ghcr.io/ljam96/m3u4me-docker:latest` (+ wrapper SHA tag)
- manual run with custom `upstream_ref` via **Run workflow** (always builds, e.g. to pin a tag)

No fork maintenance — to pick up upstream fixes, just `docker compose pull && docker compose up -d` after the nightly build runs (or wait for Watchtower/auto-update if you use it).

## Configuration

| Setting | Where | Default |
|---|---|---|
| Port | `PORT` env / compose `ports` | `8080` |
| Data dir | volume `./data:/app/data` | `./data` |
| Prod mode | `NODE_ENV=production` | required (serves `dist/`) |

Playlist URLs keep the upstream format: `http://<ip>:8080/1`, `http://<ip>:8080/2`, EPG at `http://<ip>:8080/1/epg`.
