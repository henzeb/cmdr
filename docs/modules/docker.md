# docker

Wraps `docker compose` commands. Only registered when a Docker Compose file is present in `$PWD`.

Alias: `d`

Override the detected compose filenames via `CMDR_DOCKER_COMPOSE_FILES` (space-separated, shell-exported).

---

## Commands

### `cmdr docker start [services...]`

Starts containers via `docker compose up -d`. Any arguments are forwarded to `docker compose`.

### `cmdr docker stop [services...]`

Stops containers via `docker compose stop`. Any arguments are forwarded.

### `cmdr docker down [args...]`

Brings down containers via `docker compose down`. Any arguments are forwarded.

### `cmdr docker exec [service] [cmd]`

Opens a shell in a running container.

| Argument | Default |
|----------|---------|
| `service` | `$CMDR_DOCKER_EXEC_SERVICE` |
| `cmd` | `$CMDR_DOCKER_SHELL` or `sh` |

---

## Hooks

| Hook | Arguments | When |
|------|-----------|------|
| `cmdr.docker.starting` | forwarded args | Before starting containers |
| `cmdr.docker.started` | forwarded args | After starting containers |
| `cmdr.docker.stopping` | forwarded args | Before stopping containers |
| `cmdr.docker.stopped` | forwarded args | After stopping containers |
| `cmdr.docker.taking_down` | forwarded args | Before bringing down containers |
| `cmdr.docker.took_down` | forwarded args | After bringing down containers |
| `cmdr.docker.executing` | `service`, `cmd` | Before exec |
| `cmdr.docker.executed` | `service`, `cmd` | After exec |
