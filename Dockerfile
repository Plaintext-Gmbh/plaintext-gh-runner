FROM myoung34/github-runner:latest

USER root

# Tools die GitHub-hosted Runner-VMs vorinstalliert haben, in unserem
# schlanken Container aber fehlen. Hauptfälle aus den plaintext-* Workflows:
#   - maven   : Build & Test, Sonar Analysis
#   - psql    : "Ensure test database exists" steps
#   - jq      : häufig in shell-Skripten
#   - rsync   : einige Deploy-Steps
#   - openssh-client : ssh zu NAS/Hosts
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg \
        maven \
        postgresql-client \
        jq \
        rsync \
        openssh-client \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
        | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" \
        > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# USER bleibt root, weil das base entrypoint.sh als root starten muss
# (config + token + chown) und via gosu intern auf den runner-User wechselt.
# Setzen wir hier USER runner, scheitert entrypoint.sh mit
# "RUN_AS_ROOT env var is set to true but the user has been overridden".
