#!/usr/bin/env bash
# =============================================================================
# Fortify SSC Docker Setup - Interaktives Setup-Script
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SECRETS_DIR="${SCRIPT_DIR}/ssc-webapp/secrets"
DATA_DIR_SSC="${SCRIPT_DIR}/ssc-webapp/data"
DATA_DIR_MYSQL="${SCRIPT_DIR}/ssc-mysql/data"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC}  $1"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo ""
echo "=============================================="
echo "  Fortify SSC - Docker Setup"
echo "=============================================="
echo ""

# -------------------------------------------------------
# 1. Voraussetzungen prüfen
# -------------------------------------------------------
info "Prüfe Voraussetzungen..."

if ! command -v docker &>/dev/null; then
    error "Docker ist nicht installiert. Bitte installiere Docker Desktop: https://docs.docker.com/get-docker/"
    exit 1
fi
ok "Docker gefunden: $(docker --version)"

if ! docker compose version &>/dev/null 2>&1; then
    error "Docker Compose ist nicht verfügbar. Bitte stelle sicher, dass Docker Desktop aktuell ist."
    exit 1
fi
ok "Docker Compose gefunden: $(docker compose version --short)"

if ! command -v keytool &>/dev/null; then
    error "keytool nicht gefunden. Bitte installiere ein JDK (z.B. OpenJDK 17)."
    exit 1
fi
ok "keytool gefunden"

# -------------------------------------------------------
# 2. .env erstellen
# -------------------------------------------------------
if [ ! -f "${SCRIPT_DIR}/.env" ]; then
    info "Erstelle .env aus .env.example..."
    cp "${SCRIPT_DIR}/.env.example" "${SCRIPT_DIR}/.env"
    ok ".env erstellt"
else
    ok ".env existiert bereits"
fi

# -------------------------------------------------------
# 3. Lizenz prüfen
# -------------------------------------------------------
echo ""
if [ ! -f "${SECRETS_DIR}/fortify.license" ]; then
    warn "Keine Lizenz-Datei gefunden!"
    echo ""
    echo "  Bitte kopiere deine Fortify-Lizenz nach:"
    echo "  ${SECRETS_DIR}/fortify.license"
    echo ""
    read -rp "  Drücke ENTER wenn die Datei bereitliegt..."

    if [ ! -f "${SECRETS_DIR}/fortify.license" ]; then
        error "fortify.license nicht gefunden. Abbruch."
        exit 1
    fi
fi
ok "Lizenz-Datei vorhanden"

# -------------------------------------------------------
# 4. SSL-Zertifikat generieren
# -------------------------------------------------------
echo ""
if [ ! -f "${SECRETS_DIR}/ssc-keystore.pfx" ]; then
    info "Generiere selbstsigniertes SSL-Zertifikat..."

    # Zufälliges Keystore-Passwort erzeugen
    KEYSTORE_PW=$(openssl rand -base64 16)
    echo -n "${KEYSTORE_PW}" > "${SECRETS_DIR}/keystore_password"

    keytool -genkeypair \
        -alias ssc \
        -keyalg RSA \
        -keysize 2048 \
        -validity 365 \
        -storetype PKCS12 \
        -keystore "${SECRETS_DIR}/ssc-keystore.pfx" \
        -storepass "${KEYSTORE_PW}" \
        -keypass "${KEYSTORE_PW}" \
        -dname "CN=localhost, OU=Fortify, O=Demo, L=Berlin, ST=Berlin, C=DE" \
        -ext "SAN=dns:localhost,ip:127.0.0.1" \
        2>/dev/null

    ok "SSL-Zertifikat erstellt (gültig für 365 Tage)"
else
    ok "SSL-Zertifikat existiert bereits"
fi

# -------------------------------------------------------
# 5. SSC Autoconfig erstellen
# -------------------------------------------------------
if [ ! -f "${SECRETS_DIR}/ssc.autoconfig" ]; then
    info "Erstelle SSC Autoconfig (MySQL)..."
    cp "${SECRETS_DIR}/ssc.autoconfig.example" "${SECRETS_DIR}/ssc.autoconfig"

    # host.url anpassen
    source "${SCRIPT_DIR}/.env"
    PORT="${SSC_HTTPS_PORT:-8443}"
    sed -i.bak "s|host.url: .*|host.url: 'https://localhost:${PORT}'|" "${SECRETS_DIR}/ssc.autoconfig"
    rm -f "${SECRETS_DIR}/ssc.autoconfig.bak"

    ok "Autoconfig erstellt"
else
    ok "Autoconfig existiert bereits"
fi

# -------------------------------------------------------
# 6. Daten-Verzeichnisse erstellen
# -------------------------------------------------------
mkdir -p "${DATA_DIR_SSC}" "${DATA_DIR_MYSQL}"
ok "Daten-Verzeichnisse erstellt"

# -------------------------------------------------------
# 7. Docker Hub Login prüfen
# -------------------------------------------------------
echo ""
info "Prüfe Docker Hub Zugang..."
if docker pull --quiet "${SSC_IMAGE:-fortifydocker/ssc-webapp:25.4.0.0137}" &>/dev/null 2>&1; then
    ok "SSC Image verfügbar"
else
    warn "SSC Image konnte nicht gepullt werden."
    echo ""
    echo "  Das SSC Image ist nicht öffentlich verfügbar."
    echo "  Stelle sicher, dass du bei Docker Hub angemeldet bist"
    echo "  und Zugang zum fortifydocker-Repository hast."
    echo ""
    echo "  Führe aus: docker login"
    echo ""
    read -rp "  Drücke ENTER um fortzufahren (oder Ctrl+C zum Abbrechen)..."
fi

# -------------------------------------------------------
# 8. Container starten
# -------------------------------------------------------
echo ""
read -rp "Sollen die Container jetzt gestartet werden? (j/N) " START
if [[ "${START}" =~ ^[jJyY]$ ]]; then
    info "Starte Container..."
    cd "${SCRIPT_DIR}"
    docker compose up -d

    echo ""
    ok "Container gestartet!"
    echo ""
    echo "  SSC ist erreichbar unter:  https://localhost:${SSC_HTTPS_PORT:-8443}"
    echo "  (Der erste Start kann 2-5 Minuten dauern)"
    echo ""
    echo "  Standard-Login:  admin / admin"
    echo "  (Muss beim ersten Login geändert werden)"
    echo ""
    echo "  Logs anzeigen:   docker compose logs -f"
    echo "  Stoppen:         docker compose down"
    echo ""
else
    echo ""
    ok "Setup abgeschlossen!"
    echo ""
    echo "  Starte die Container später mit:"
    echo "    cd ${SCRIPT_DIR}"
    echo "    docker compose up -d"
    echo ""
fi
