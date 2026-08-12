#!/usr/bin/env bash
# Testharnisch fuer twingate-launch.sh (Karte 459).
#
# Prueft die vier Faelle mit gemockten Kommandos (ip / twingate / Runner.Listener).
# Belegt insbesondere die Gegenprobe: Fall C MUSS abbrechen, ohne den Runner zu starten.
#
# Karte 765: dazu die Kontrolle, dass die Key-Datei nach dem Lauf weg ist — im Erfolgsfall (B)
# wie im Abbruchfall (C). Damit der Test dabei nicht selbst Key-Dateien im echten /tmp
# hinterlaesst, wird der mktemp-Pfad ins Arbeitsverzeichnis umgebogen; greift das Muster nicht,
# bricht der Harnisch ab, statt eine leere Verzeichnisliste als Erfolg zu melden.
# Absolut aufloesen: der Harnisch wechselt fuer jeden Lauf das Arbeitsverzeichnis, ein
# relativ uebergebener Pfad waere danach ins Leere gelaufen (und der Test still gruen-blind).
SKRIPT="$(readlink -f "${1:-}" 2>/dev/null)"
[ -n "$SKRIPT" ] && [ -f "$SKRIPT" ] || { echo "Skript nicht gefunden: ${1:-<kein Argument>}"; exit 2; }

ARBEIT=$(mktemp -d)
trap 'rm -rf "$ARBEIT"' EXIT
MOCK="$ARBEIT/bin"; mkdir -p "$MOCK" "$ARBEIT/actions-runner/bin"

# Positivkontrolle mit Abbruch: ohne diese Zeile im Skript testet die Key-Pruefung unten nichts.
grep -q 'mktemp /tmp/twingate-key' "$SKRIPT" \
  || { echo "ABBRUCH: '$SKRIPT' enthaelt kein 'mktemp /tmp/twingate-key' — die Key-Pruefung waere gruen-blind."; exit 2; }

# Der Runner selbst: protokolliert nur, dass er gestartet wurde.
cat > "$ARBEIT/actions-runner/bin/Runner.Listener" <<'EOF'
#!/usr/bin/env bash
echo "RUNNER-GESTARTET"
EOF
chmod +x "$ARBEIT/actions-runner/bin/Runner.Listener"

mock_ip() {   # $1 = "tunnel" | "kein-tunnel"
  if [ "$1" = tunnel ]; then
    cat > "$MOCK/ip" <<'EOF'
#!/usr/bin/env bash
echo "100.96.0.0/12 dev sdwan0 proto static scope host metric 25"
echo "default via 192.168.1.1 dev eth0"
EOF
  else
    cat > "$MOCK/ip" <<'EOF'
#!/usr/bin/env bash
echo "default via 192.168.1.1 dev eth0"
EOF
  fi
  chmod +x "$MOCK/ip"
}

mock_twingate() {   # $1 = "online" | "tot"
  cat > "$MOCK/twingate" <<EOF
#!/usr/bin/env bash
case "\$1" in
  setup) echo "Twingate Setup 2026.160.6555" ;;
  start) echo "Twingate has been started" ;;
  status) [ "$1" = online ] && echo online || echo not-running ;;
esac
exit 0
EOF
  chmod +x "$MOCK/twingate"
}

lauf() {   # $1=Titel  $2=ip-Modus  $3=twingate-Modus  $4=Key ("" = nicht gesetzt)
  mock_ip "$2"; mock_twingate "$3"
  local aus rc
  rm -f "$ARBEIT"/twingate-key.*.json
  aus=$(cd "$ARBEIT" && PATH="$MOCK:$PATH" TWINGATE_SERVICE_KEY="$4" TWINGATE_TIMEOUT=2 \
        bash -c "cd '$ARBEIT' && sed -e 's#cd /actions-runner#cd $ARBEIT/actions-runner#' \
                                    -e 's#mktemp /tmp/twingate-key#mktemp $ARBEIT/twingate-key#' \
                                    '$SKRIPT' > lauf.sh && bash lauf.sh" 2>&1)
  rc=$?
  ls -1 "$ARBEIT"/twingate-key.*.json 2>/dev/null | wc -l > "$ARBEIT/key-reste.txt"
  echo "$aus" > "$ARBEIT/letzte-ausgabe.txt"
  echo "$rc"  > "$ARBEIT/letzter-rc.txt"
}

pruefe() {  # $1=Beschreibung $2=erwartet-im-text ("!" davor = darf NICHT vorkommen) $3=erwarteter rc
  local aus rc ok=ja
  aus=$(cat "$ARBEIT/letzte-ausgabe.txt"); rc=$(cat "$ARBEIT/letzter-rc.txt")
  if [ "${2:0:1}" = "!" ]; then
    grep -q -- "${2:1}" <<<"$aus" && ok=nein
  else
    grep -q -- "$2" <<<"$aus" || ok=nein
  fi
  [ "$rc" = "$3" ] || ok=nein
  if [ "$ok" = ja ]; then echo "  ok   $1 (rc=$rc)"; else
    echo "  FEHL $1 (rc=$rc, erwartet $3)"; echo "$aus" | sed 's/^/       | /'; FEHLER=$((FEHLER+1)); fi
}

pruefe_key_weg() {  # $1 = Beschreibung
  local n; n=$(cat "$ARBEIT/key-reste.txt")
  if [ "$n" = 0 ]; then echo "  ok   $1 (0 Key-Dateien uebrig)"; else
    echo "  FEHL $1 ($n Key-Datei(en) liegen geblieben)"; FEHLER=$((FEHLER+1)); fi
}

FEHLER=0
echo "== A: Host-Tunnel vorhanden (der NAS-Fall) =================================="
lauf A tunnel tot "{\"key\":\"egal\"}"
pruefe "Container-Client wird uebersprungen" "wird uebersprungen" 0
pruefe "kein 30s-Warten, keine WARN"          "!WARN"             0
pruefe "Runner startet"                       "RUNNER-GESTARTET"  0

echo "== B: kein Host-Tunnel, eigener Tunnel kommt hoch ==========================="
lauf B kein-tunnel online "{\"key\":\"egal\"}"
pruefe "Tunnel wird aufgebaut"  "tunnel online after" 0
pruefe "Runner startet"         "RUNNER-GESTARTET"    0
pruefe_key_weg "Key-Datei nach erfolgreichem Start entfernt"

echo "== C: GEGENPROBE — kein Host-Tunnel, eigener kommt NICHT hoch ==============="
lauf C kein-tunnel tot "{\"key\":\"egal\"}"
pruefe "ERROR statt WARN"                    "ERROR: Tunnel nach" 1
pruefe "Runner startet NICHT"                "!RUNNER-GESTARTET"  1
pruefe_key_weg "Key-Datei auch beim Abbruch entfernt"

echo "== D: kein Host-Tunnel, kein Key ==========================================="
lauf D kein-tunnel tot ""
pruefe "sauber uebersprungen" "skipping Twingate" 0
pruefe "Runner startet"       "RUNNER-GESTARTET"  0

echo
[ "$FEHLER" = 0 ] && echo "ERGEBNIS: alle Faelle wie erwartet" || echo "ERGEBNIS: $FEHLER Abweichung(en)"
exit "$FEHLER"
