#!/usr/bin/env bash
# CMD-Wrapper für die twingate-Variante.
#
# Läuft NACH dem base /entrypoint.sh (das config + token + registration macht).
# Hier: Twingate-Daemon hochfahren, dann das eigentliche Runner.Listener
# Kommando exec'en — same args wie das base CMD wäre.
#
# ENV:
#   TWINGATE_SERVICE_KEY  – JSON service-account key (Inhalt, nicht Pfad)
#   TWINGATE_TIMEOUT      – Sekunden warten bis Tunnel up (default 30)
#
# Container braucht:
#   --cap-add NET_ADMIN
#   --device /dev/net/tun:/dev/net/tun
set -e

if [ -n "${TWINGATE_SERVICE_KEY:-}" ]; then
  echo "[twingate-launch] setting up Twingate..."
  KEY_FILE=$(mktemp /tmp/twingate-key.XXXXXX.json)
  echo "$TWINGATE_SERVICE_KEY" > "$KEY_FILE"
  chmod 600 "$KEY_FILE"

  twingate setup --headless="$KEY_FILE" \
    || { echo "[twingate-launch] WARN: twingate setup failed"; }

  echo "[twingate-launch] starting daemon (headless)..."
  twingate start || echo "[twingate-launch] WARN: twingate start exit non-zero"

  # Warten bis online
  TIMEOUT="${TWINGATE_TIMEOUT:-30}"
  for i in $(seq 1 "$TIMEOUT"); do
    if twingate status 2>/dev/null | grep -q -i online; then
      echo "[twingate-launch] tunnel online after ${i}s"
      break
    fi
    sleep 1
  done

  if ! twingate status 2>/dev/null | grep -q -i online; then
    echo "[twingate-launch] WARN: tunnel not online after ${TIMEOUT}s"
    twingate status 2>&1 | head -5 || true
  fi

  # KEY_FILE bewusst nicht gelöscht — Twingate-Daemon liest evtl. nochmal nach.
else
  echo "[twingate-launch] TWINGATE_SERVICE_KEY not set — skipping Twingate"
fi

# Eigentliches Runner-Kommando (entspricht dem base-Image CMD).
echo "[twingate-launch] launching Runner.Listener"
cd /actions-runner
exec ./bin/Runner.Listener run --startuptype service
