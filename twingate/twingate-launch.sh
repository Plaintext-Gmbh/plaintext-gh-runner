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
#
# Karte 459 — warum hier eine Vorprüfung steht:
#
# Die Runner laufen mit `network_mode: host` und teilen sich damit den Netzwerk-Namespace des
# NAS-Hosts. Der Host betreibt selbst einen Twingate-Client (Interface `sdwan0`, Routen im
# Bereich 100.64/10). In DEMSELBEN Namespace kann kein zweiter Client einen eigenen Tunnel
# aufbauen: `twingate start` meldet zwar "Twingate has been started" und liefert Exit 0, der
# Daemon beendet sich aber sofort — `twingate status` bleibt auf `not-running`.
#
# Sichtbar war das als 2645 von 2645 Startversuchen mit "tunnel not online after 30s" und
# keiner einzigen Erfolgsmeldung in 30 Tagen. Gekostet hat es je Containerstart 30 s Wartezeit
# und ein weiteres `service_key.json.<ts>.backup` in /etc/twingate.
#
# Gebraucht wurde der Container-Client dabei nie: Über den geteilten Namespace benutzen die
# Jobs den Host-Tunnel bereits mit (im laufenden Runner nachgemessen:
# `ip route get 100.96.0.1` -> `dev sdwan0 src 100.96.0.2`).
#
# Ohne Host-Netz funktioniert derselbe Client übrigens einwandfrei — im isolierten Container
# mit denselben Rechten und demselben Key war der Tunnel nach 5 s `online`. Deshalb wird der
# Weg unten nicht entfernt, sondern nur übersprungen, wenn er nachweislich überflüssig ist.
set -e

# Ist im aktuellen Namespace schon ein Twingate-Tunnel aktiv? Twingate vergibt Adressen und
# Routen aus dem CGNAT-Bereich 100.64.0.0/10; das Interface heisst je nach Plattform sdwan0
# oder tun0. `ip` liegt im Twingate-Image vor (iproute2, siehe Dockerfile).
twingate_tunnel_im_namespace() {
  ip route show 2>/dev/null \
    | grep -qE 'dev (sdwan|tun)[0-9]+' \
    && return 0
  return 1
}

if twingate_tunnel_im_namespace; then
  # Der Normalfall auf dem NAS. Kein Fehler, keine Wartezeit, keine WARN.
  echo "[twingate-launch] Twingate-Tunnel im Namespace bereits aktiv (Host-Client) — Container-Client wird uebersprungen"
  ip route show 2>/dev/null | grep -E 'dev (sdwan|tun)[0-9]+' | head -3 | sed 's/^/[twingate-launch]   /'

elif [ -n "${TWINGATE_SERVICE_KEY:-}" ]; then
  echo "[twingate-launch] setting up Twingate..."
  KEY_FILE=$(mktemp /tmp/twingate-key.XXXXXX.json)
  # Karte 765: Der Key muss auch dann verschwinden, wenn dieser Zweig unterwegs abbricht
  # (`set -e`, oder der ERROR-Ausstieg unten). Ohne den trap blieb je Fehlversuch eine Kopie
  # liegen — auf dem NAS 3692 Stueck aus drei Monaten, alle mit demselben, bis 05/2027
  # gueltigen private_key, in einem /tmp das alle vier Runner teilen.
  trap 'rm -f "$KEY_FILE"' EXIT INT TERM
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

  # Karte 459, Punkt 3: Hier wurde bisher nur eine WARN geschrieben und der Runner trotzdem
  # gestartet. Ein Runner ohne Tunnel nimmt Jobs an, die den Tunnel brauchen — die scheitern
  # dann irgendwo an einem Timeout oder "connection refused", und niemand bringt das mit
  # Twingate in Verbindung. Lieber gar nicht erst starten: der Job bleibt in der Queue und
  # wartet auf einen Runner, der ihn wirklich ausführen kann.
  if ! twingate status 2>/dev/null | grep -q -i online; then
    echo "[twingate-launch] ERROR: Tunnel nach ${TIMEOUT}s nicht online — Runner wird NICHT gestartet." >&2
    echo "[twingate-launch] ERROR: Ein Runner ohne Tunnel nimmt Jobs an, die er nicht ausfuehren kann." >&2
    twingate status 2>&1 | head -5 | sed 's/^/[twingate-launch]   /' >&2 || true
    exit 1
  fi

  # Ab hier laeuft der Tunnel — der Key ist von `twingate setup` laengst nach /etc/twingate
  # uebernommen (dass setup dort schreibt, war in Karte 459 an den service_key.json.<ts>.backup
  # zu sehen, die jeder Fehlversuch hinterliess). Die tmp-Kopie wird nicht mehr gebraucht und
  # geht weg, bevor unten `exec` den trap gegenstandslos macht.
  rm -f "$KEY_FILE"
  trap - EXIT INT TERM
else
  echo "[twingate-launch] TWINGATE_SERVICE_KEY not set — skipping Twingate"
fi

# Eigentliches Runner-Kommando (entspricht dem base-Image CMD).
echo "[twingate-launch] launching Runner.Listener"
cd /actions-runner
exec ./bin/Runner.Listener run --startuptype service
