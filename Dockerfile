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
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

USER runner
