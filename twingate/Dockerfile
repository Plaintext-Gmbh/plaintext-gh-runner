FROM myoung34/github-runner:latest

USER root

# Selbe Tools wie das default-Image (maven, psql, ...) plus Twingate.
# Twingate-Install: APT-Repo + Binary. Postinst-Script versucht systemd,
# das schlägt im Container fehl — wir ignorieren das und starten den
# Daemon manuell aus dem entrypoint-Wrapper.
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        curl ca-certificates gnupg \
        maven postgresql-client jq rsync openssh-client \
        iproute2 iptables \
    && install -d -m 0755 /etc/apt/keyrings \
    && curl -fsSL https://packages.twingate.com/apt/gpg.key \
        | gpg --dearmor -o /etc/apt/keyrings/twingate.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/twingate.gpg] https://packages.twingate.com/apt/ /" \
        > /etc/apt/sources.list.d/twingate.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends twingate \
        || true \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Custom entrypoint: Twingate Daemon hochfahren bevor der GH-Runner startet.
COPY entrypoint-twingate.sh /entrypoint-twingate.sh
RUN chmod +x /entrypoint-twingate.sh
ENTRYPOINT ["/entrypoint-twingate.sh"]
