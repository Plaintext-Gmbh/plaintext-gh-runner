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
        maven \
        postgresql-client \
        jq \
        rsync \
        openssh-client \
        nodejs \
        npm \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# USER bleibt root, weil das base entrypoint.sh als root starten muss
# (config + token + chown) und via gosu intern auf den runner-User wechselt.
# Setzen wir hier USER runner, scheitert entrypoint.sh mit
# "RUN_AS_ROOT env var is set to true but the user has been overridden".
