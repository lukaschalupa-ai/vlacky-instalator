#!/usr/bin/env bash
# Vláčky – instalační průvodce pro Linux a Synology (SSH). Bez argumentů: nainstaluje nebo aktualizuje.
set -e
cd "$(dirname "$0")"

say() { printf '%s\n' "$*"; }
ask() { # ask "otázka" "výchozí" -> odpověď v $REPLY
  read -r -p "$1 [$2]: " REPLY || true
  REPLY="${REPLY:-$2}"
}

say "=== Vláčky – instalace ==="

# --- Docker
if ! command -v docker >/dev/null 2>&1; then
  say "Docker nebyl nalezen. Na Synology nainstaluj v Centru balíčků „Container Manager“ (DSM 7.2) nebo „Docker“ (starší DSM)."
  say "Na ostatních Linuxech viz https://docs.docker.com/engine/install/"
  exit 1
fi
if docker compose version >/dev/null 2>&1; then DC="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then DC="docker-compose"
else say "Chybí docker compose (ani „docker compose“, ani „docker-compose“)."; exit 1; fi
DOCKER="docker"
if ! docker info >/dev/null 2>&1; then
  if sudo -n true 2>/dev/null || [ -t 0 ]; then
    say "Docker vyžaduje práva správce, zkouším přes sudo."
    DOCKER="sudo docker"; DC="sudo $DC"
  fi
fi

# --- nastavení
if [ -f .env ]; then
  say "Nalezeno stávající nastavení (.env). Zachovávám ho a aplikaci jen znovu sestavím (aktualizace)."
  say "Chceš nastavení vytvořit znovu? Smaž soubor instalator/.env a spusť průvodce znovu. Data se tím nesmažou."
else
  ask "Port, na kterém aplikace poběží" "8090"; PORT="$REPLY"
  case "$PORT" in ''|*[!0-9]*) say "Port musí být číslo."; exit 1;; esac
  ask "Název aplikace (zobrazí se u ikony v telefonu)" "Vláčky"; NAME="$REPLY"
  case "$NAME" in *[\$\"\'\#\\\`]*) say "Název nesmí obsahovat znaky \$ \" ' # \\ ani zpětný apostrof."; exit 1;; esac
  if [ -d /volume1 ]; then DEF_DATA="/volume1/docker/vlacky/data"; else DEF_DATA="$(pwd)/data"; fi
  ask "Složka pro data (databáze, fotky, zálohy)" "$DEF_DATA"; DATA="$REPLY"
  say "Úvodní heslo (aspoň 8 znaků, nejlépe dlouhá věta; znaky \$ \" ' # \\ nepoužívej)."
  read -r -s -p "Heslo (prázdné = vygenerovat náhodné): " PW || true; echo
  if [ -z "$PW" ]; then
    PW="$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16)"
    say "Vygenerované heslo: $PW   (zapiš si ho; po přihlášení si ho můžeš změnit v Nastavení)"
  fi
  [ "${#PW}" -ge 8 ] || { say "Heslo musí mít aspoň 8 znaků."; exit 1; }
  case "$PW" in *[\$\"\'\#\\\`]*) say "Heslo nesmí obsahovat znaky \$ \" ' # \\ ani zpětný apostrof."; exit 1;; esac
  ask "Chceš zapnout HTTPS (máš soubory fullchain.pem a privkey.pem)? a/n" "n"
  CERT=""
  case "$REPLY" in a|A|y|Y) read -r -p "Složka s certifikátem: " CERT;
    [ -f "$CERT/fullchain.pem" ] && [ -f "$CERT/privkey.pem" ] || { say "V té složce chybí fullchain.pem nebo privkey.pem."; exit 1; };; esac
  mkdir -p "$DATA"
  umask 077
  { echo "APP_PASSWORD=$PW"; echo "VLACKY_PORT=$PORT"; echo "APP_NAME=$NAME"; echo "VLACKY_DATA=$DATA"; echo "VLACKY_TZ=Europe/Prague"
    [ -n "$CERT" ] && echo "VLACKY_CERT_DIR=$CERT"; true; } > .env
  umask 022
  say "Nastavení uloženo do instalator/.env (heslo je v něm čitelně – nikomu tento soubor neposílej)."
fi

FILES="-f docker-compose.yml"
if grep -q '^VLACKY_CERT_DIR=' .env; then FILES="$FILES -f docker-compose.https.yml"; fi
DATA_DIR="$(grep '^VLACKY_DATA=' .env | cut -d= -f2-)"; [ -n "$DATA_DIR" ] && mkdir -p "$DATA_DIR" 2>/dev/null || true

say "Sestavuji a spouštím aplikaci (první sestavení může trvat několik minut)…"
$DC $FILES up -d --build

PORT="$(grep '^VLACKY_PORT=' .env | cut -d= -f2-)"
SCHEME=http; grep -q '^VLACKY_CERT_DIR=' .env && SCHEME=https
IP="$(hostname -I 2>/dev/null | awk '{print $1}')"; IP="${IP:-IP-adresa-zařízení}"
say ""
say "Hotovo. Otevři v prohlížeči:  $SCHEME://$IP:$PORT"
say "Přihlas se úvodním heslem z instalator/.env a nastav si svoji centrálu v aplikaci."
say "Logy: $DC $FILES logs -f      Zastavení: $DC $FILES down"
