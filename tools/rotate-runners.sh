#!/usr/bin/env bash
# Rotiert die GitHub-Runner auf dem NAS auf das neue Image (Maven 3.9.11 → Build-Cache aktiv).
# Sicher: prüft zuerst, dass org-weit kein Build läuft.
set -e
echo "=== Runner-Rotation/Reparatur ==="
echo "⚠️  WICHTIG: Dieses Fenster OFFEN LASSEN, bis '✅ fertig' erscheint!"
echo "1/3 Warte auf Build-Lücke (prüfe alle 30 s, max. 45 min)…"
for versuch in $(seq 1 90); do
  ONLINE=$(gh api /orgs/Plaintext-Gmbh/actions/runners --jq '[.runners[] | select(.status=="online")] | length' 2>/dev/null || echo "?")
  if [ "$ONLINE" = "0" ]; then
    echo "  ⚠️  0 Runner online — nichts kann laufen, Rotation/Reparatur sofort safe"
    BUSY=""; break
  fi
  BUSY=""
  for r in plaintext-app plaintext-root plaintext-guild plaintext-iot plaintext-fwtool plaintext-schuetu plaintext-scripts plaintext-gh-runner; do
    N=$(gh api "repos/Plaintext-Gmbh/$r/actions/runs?status=in_progress&per_page=1" --jq '.workflow_runs | length' 2>/dev/null || echo 0)
    Q=$(gh api "repos/Plaintext-Gmbh/$r/actions/runs?status=queued&per_page=1" --jq '.workflow_runs | length' 2>/dev/null || echo 0)
    [ "$N$Q" != "00" ] && BUSY="$BUSY $r"
  done
  if [ -z "$BUSY" ]; then
    echo "  ✅ keine laufenden Builds — rotiere jetzt"
    break
  fi
  echo "  $(date +%H:%M:%S) läuft noch:$BUSY — warte 30 s…"
  sleep 30
done
if [ -n "$BUSY" ]; then
  echo "ABBRUCH: Nach 45 min immer noch Builds aktiv — bitte Claude fragen."
  read -r -p "Enter zum Schliessen…"; exit 1
fi
echo "2/3 Compose syncen + Stack sauber neu aufsetzen (down → pull → up)…"
scp -q /home/mad/codeplain/plaintext-dockercompose/tri/github-runners/docker-compose.yaml trimstein:/volume1/docker/github-runners/docker-compose.yaml
ssh trimstein "cd /volume1/docker/github-runners && sudo docker compose down --remove-orphans && sudo docker compose pull -q && sudo docker compose up -d"
echo "3/3 Status:"
ssh trimstein "sudo docker ps --format '{{.Names}}\t{{.Status}}' | grep runner"
echo ""
echo "Warte auf GitHub-Registrierung der Runner…"
for i in $(seq 1 24); do
  ONLINE=$(gh api /orgs/Plaintext-Gmbh/actions/runners --jq '[.runners[] | select(.status=="online")] | length' 2>/dev/null || echo 0)
  echo "  $ONLINE/8 Runner online"
  [ "$ONLINE" = "8" ] && break
  sleep 10
done
echo ""
echo "✅ fertig — Claude macht weiter."
read -r -p "Enter zum Schliessen…"
