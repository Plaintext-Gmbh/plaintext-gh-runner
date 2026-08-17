FROM myoung34/github-runner:latest

USER root

# Selbe Tools wie das default-Image (maven, psql, ...) plus Twingate.
# Karte 918: "selbe Tools" stimmte nicht — dieses Image zog `maven` aus apt (3.6.3),
# waehrend das default-Image es bewusst durch den 3.9.11-Tarball ersetzt hat, und
# fontconfig/fonts fehlten hier ganz. Beides unten angeglichen.
# Twingate-Install: APT-Repo + Binary. Postinst-Script versucht systemd,
# das schlägt im Container fehl — wir umgehen mit "|| true" und starten
# den Daemon später manuell aus dem CMD-Wrapper.
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        curl ca-certificates gnupg \
        postgresql-client jq rsync openssh-client \
        fontconfig fonts-dejavu-core \
        iproute2 iptables \
    && install -d -m 0755 /etc/apt/keyrings \
    && curl -fsSL https://packages.twingate.com/apt/gpg.key \
        | gpg --dearmor -o /etc/apt/keyrings/twingate.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/twingate.gpg] https://packages.twingate.com/apt/ /" \
        > /etc/apt/sources.list.d/twingate.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends twingate \
        || true \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
        | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" \
        > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Maven >= 3.9 statt apt-Paket (3.6.3): noetig fuer die maven-build-cache-extension
# der plaintext-Repos (.mvn/extensions.xml) — unveraenderte Module kommen aus dem
# persistenten ~/.m2/build-cache statt neu gebaut/getestet zu werden.
# Wortgleich zum default-Dockerfile: beide Images muessen dieselbe Version liefern,
# sonst haengt es vom freien Runner ab, womit ein Commit gebaut wird (Karte 918).
ARG MAVEN_VERSION=3.9.11
RUN curl -fsSL "https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz" \
        | tar -xz -C /opt \
    && ln -sf "/opt/apache-maven-${MAVEN_VERSION}/bin/mvn" /usr/local/bin/mvn \
    && test -x "/opt/apache-maven-${MAVEN_VERSION}/bin/mvn"
    # kein `mvn --version` hier: das Image hat kein Java (setup-java kommt erst im Job)

# CMD-Wrapper: läuft NACH dem base /entrypoint.sh (das die Runner-
# Registration macht). Wir starten Twingate hier und chainen dann das
# eigentliche Runner.Listener Kommando. So bleiben die config/registration
# flows des base-Images intakt.
COPY twingate-launch.sh /usr/local/bin/twingate-launch.sh
RUN chmod +x /usr/local/bin/twingate-launch.sh

# ENTRYPOINT bleibt unverändert (base: /entrypoint.sh — macht config etc.)
CMD ["/usr/local/bin/twingate-launch.sh"]
