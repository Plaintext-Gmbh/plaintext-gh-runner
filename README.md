# plaintext-gh-runner

Custom GitHub Actions Self-Hosted Runner Images.

Aufbauend auf [`myoung34/github-runner`](https://github.com/myoung34/docker-github-actions-runner)
mit zusätzlichen Tools, die in den `plaintext-*` Pipelines benötigt werden
und in dem schlanken Base-Image fehlen.

## Zwei Varianten

| Tag | Inhalt | Container-Anforderungen |
|-----|--------|-------------------------|
| `:latest` | + `maven`, `postgresql-client`, `jq`, `rsync`, `openssh-client` | Standard, keine extra Capabilities |
| `:twingate` | obiges + `twingate` Client + Wrapper-Entrypoint | `cap_add: NET_ADMIN` + `devices: /dev/net/tun` + `TWINGATE_SERVICE_KEY` |

### Twingate-Variante

Startet beim Container-Boot den Twingate-Daemon bevor der Runner registriert wird.
Service-Key wird via ENV `TWINGATE_SERVICE_KEY` erwartet (JSON-Content, nicht Datei-Pfad).
Ohne den Key verhält sich der Container wie das `:latest` (skip Twingate-Setup).

## Usage

```yaml
services:
  runner:
    image: ghcr.io/plaintext-gmbh/plaintext-gh-runner:latest
    environment:
      RUNNER_SCOPE: repo
      REPO_URL: https://github.com/owner/repo
      ACCESS_TOKEN: ${GH_PAT}
      LABELS: self-hosted,linux,nas
      EPHEMERAL: "true"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
```

Eingesetzt im plaintext-dockercompose Stack `tri/github-runners/` auf dem NAS.

## Builds

- Trigger: push to master, weekly cron (Mon 05:00 UTC), manual dispatch
- Registry: `ghcr.io/plaintext-gmbh/plaintext-gh-runner`
- Tags: `latest`, `<commit-sha>`
- Platform: linux/amd64

## Updaten

`Dockerfile` editieren, push to master → Build-Workflow → neues Image
unter `:latest`. Im Runner-Stack auf NAS reicht ein `docker compose pull
&& docker compose up -d --force-recreate` um die neue Version zu ziehen.
