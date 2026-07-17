FROM myoung34/github-runner:latest

USER root

# Tools die GitHub-hosted Runner-VMs vorinstalliert haben, in unserem
# schlanken Container aber fehlen. Hauptfälle aus den plaintext-* Workflows:
#   - maven   : Build & Test, Sonar Analysis (Tarball unten, apt liefert nur 3.6.3)
#   - psql    : "Ensure test database exists" steps
#   - jq      : häufig in shell-Skripten
#   - rsync   : einige Deploy-Steps
#   - openssh-client : ssh zu NAS/Hosts
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg \
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

# Maven >= 3.9 statt apt-Paket (3.6.3): noetig fuer die maven-build-cache-extension
# der plaintext-Repos (.mvn/extensions.xml) — unveraenderte Module kommen aus dem
# persistenten ~/.m2/build-cache statt neu gebaut/getestet zu werden.
ARG MAVEN_VERSION=3.9.11
RUN curl -fsSL "https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz" \
        | tar -xz -C /opt \
    && ln -sf "/opt/apache-maven-${MAVEN_VERSION}/bin/mvn" /usr/local/bin/mvn \
    && test -x "/opt/apache-maven-${MAVEN_VERSION}/bin/mvn"
    # kein `mvn --version` hier: das Image hat kein Java (setup-java kommt erst im Job)

# USER bleibt root, weil das base entrypoint.sh als root starten muss
# (config + token + chown) und via gosu intern auf den runner-User wechselt.
# Setzen wir hier USER runner, scheitert entrypoint.sh mit
# "RUN_AS_ROOT env var is set to true but the user has been overridden".
