FROM myoung34/github-runner:latest

USER root

# Selbe Tools wie das default-Image (maven, psql, ...) plus Twingate.
# Twingate-Install: APT-Repo + Binary. Postinst-Script versucht systemd,
# das schlägt im Container fehl — wir umgehen mit "|| true" und starten
# den Daemon später manuell aus dem CMD-Wrapper.
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        curl ca-certificates gnupg \
        maven postgresql-client jq rsync openssh-client \
        nodejs npm \
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

# CMD-Wrapper: läuft NACH dem base /entrypoint.sh (das die Runner-
# Registration macht). Wir starten Twingate hier und chainen dann das
# eigentliche Runner.Listener Kommando. So bleiben die config/registration
# flows des base-Images intakt.
COPY twingate-launch.sh /usr/local/bin/twingate-launch.sh
RUN chmod +x /usr/local/bin/twingate-launch.sh

# ENTRYPOINT bleibt unverändert (base: /entrypoint.sh — macht config etc.)
CMD ["/usr/local/bin/twingate-launch.sh"]
