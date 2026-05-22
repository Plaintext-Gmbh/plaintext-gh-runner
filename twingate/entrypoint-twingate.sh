#!/usr/bin/env bash
# Custom entrypoint wrapper: bringt Twingate Daemon vor dem GH-Runner hoch.
#
# Erwartet ENV:
#   TWINGATE_SERVICE_KEY  – JSON service-account key (Inhalt)
#   TWINGATE_TIMEOUT      – Sekunden warten bis Tunnel up (default 30)
#
# Voraussetzungen am Container:
#   --cap-add NET_ADMIN
#   --device /dev/net/tun:/dev/net/tun
#
# Wenn TWINGATE_SERVICE_KEY leer ist, wird Twingate übersprungen
# (Container verhält sich dann wie das normale plaintext-gh-runner).
set -e

if [ -n "${TWINGATE_SERVICE_KEY:-}" ]; then
  echo "[entrypoint-twingate] setting up Twingate..."
  KEY_FILE=$(mktemp /tmp/twingate-key.XXXXXX.json)
  trap 'rm -f "$KEY_FILE"' EXIT
  echo "$TWINGATE_SERVICE_KEY" > "$KEY_FILE"

  # twingate setup schreibt /etc/twingate/access.conf, braucht kein systemd.
  twingate setup --headless="$KEY_FILE" || {
    echo "[entrypoint-twingate] WARN: twingate setup failed"; exit 1;
  }

  # twingate start ruft systemctl. Im Container fail → daemon manuell.
  # /usr/bin/twingate-service ist das daemon binary.
  if [ -x /usr/bin/twingate-service ]; then
    echo "[entrypoint-twingate] launching daemon..."
    /usr/bin/twingate-service --headless &
    DAEMON_PID=$!
  else
    echo "[entrypoint-twingate] WARN: /usr/bin/twingate-service nicht da, versuche twingate start"
    twingate start || echo "[entrypoint-twingate] WARN: twingate start failed"
  fi

  # Warten bis online
  TIMEOUT="${TWINGATE_TIMEOUT:-30}"
  for i in $(seq 1 "$TIMEOUT"); do
    if twingate status 2>/dev/null | grep -q online; then
      echo "[entrypoint-twingate] tunnel up after ${i}s"
      break
    fi
    sleep 1
  done

  if ! twingate status 2>/dev/null | grep -q online; then
    echo "[entrypoint-twingate] WARN: tunnel not online after ${TIMEOUT}s — continuing anyway"
    twingate status 2>&1 | head -5
  fi
else
  echo "[entrypoint-twingate] TWINGATE_SERVICE_KEY not set — skipping Twingate setup"
fi

# Original entrypoint des myoung34/github-runner Images aufrufen.
exec /entrypoint.sh "$@"
