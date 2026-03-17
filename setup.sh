#!/usr/bin/env bash
# =============================================================================
# Fortify SSC Docker Setup
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SECRETS_DIR="${SCRIPT_DIR}/ssc-webapp/secrets"

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
# 1. Check prerequisites
# -------------------------------------------------------
info "Checking prerequisites..."

if ! command -v docker &>/dev/null; then
    error "Docker is not installed. Please install Docker Desktop: https://docs.docker.com/get-docker/"
    exit 1
fi
ok "Docker found: $(docker --version)"

if ! docker compose version &>/dev/null 2>&1; then
    error "Docker Compose is not available. Please make sure Docker Desktop is up to date."
    exit 1
fi
ok "Docker Compose found: $(docker compose version --short)"

if ! command -v keytool &>/dev/null; then
    error "keytool not found. Please install a JDK (e.g. OpenJDK 17)."
    exit 1
fi
ok "keytool found"

# -------------------------------------------------------
# 2. Create .env
# -------------------------------------------------------
if [ ! -f "${SCRIPT_DIR}/.env" ]; then
    info "Creating .env from .env.example..."
    cp "${SCRIPT_DIR}/.env.example" "${SCRIPT_DIR}/.env"
    ok ".env created"
else
    ok ".env already exists"
fi

source "${SCRIPT_DIR}/.env"

# -------------------------------------------------------
# 3. Check license file
# -------------------------------------------------------
echo ""
if [ ! -f "${SECRETS_DIR}/fortify.license" ]; then
    warn "No license file found!"
    echo ""
    echo "  Please copy your Fortify license to:"
    echo "  ${SECRETS_DIR}/fortify.license"
    echo ""
    read -rp "  Press ENTER when the file is in place..."

    if [ ! -f "${SECRETS_DIR}/fortify.license" ]; then
        error "fortify.license not found. Aborting."
        exit 1
    fi
fi
ok "License file found"

# -------------------------------------------------------
# 4. Generate SSL certificate
# -------------------------------------------------------
echo ""
if [ ! -f "${SECRETS_DIR}/ssc-keystore.pfx" ]; then
    info "Generating self-signed SSL certificate..."

    KEYSTORE_PW="$(openssl rand -base64 32)"
    echo -n "${KEYSTORE_PW}" > "${SECRETS_DIR}/keystore_password"

    keytool -genkeypair -keyalg RSA -keysize 2048 \
        -storetype PKCS12 \
        -keystore "${SECRETS_DIR}/ssc-keystore.pfx" \
        -alias ssc-server \
        -validity 365 \
        -storepass "${KEYSTORE_PW}" \
        -keypass "${KEYSTORE_PW}" \
        -dname "CN=localhost, OU=Fortify, O=Demo, C=DE" \
        -ext "SAN=dns:localhost,ip:127.0.0.1" \
        2>/dev/null

    ok "SSL certificate created (valid for 365 days)"
else
    ok "SSL certificate already exists"
fi

# -------------------------------------------------------
# 5. Create SSC autoconfig
# -------------------------------------------------------
if [ ! -f "${SECRETS_DIR}/ssc.autoconfig" ]; then
    info "Creating SSC autoconfig (MySQL)..."
    cp "${SECRETS_DIR}/ssc.autoconfig.example" "${SECRETS_DIR}/ssc.autoconfig"

    PORT="${SSC_HTTPS_PORT:-8443}"
    sed -i.bak "s|host.url: .*|host.url: 'https://localhost:${PORT}'|" "${SECRETS_DIR}/ssc.autoconfig"
    rm -f "${SECRETS_DIR}/ssc.autoconfig.bak"

    ok "Autoconfig created"
else
    ok "Autoconfig already exists"
fi

# -------------------------------------------------------
# 6. Create data directories and set permissions
# -------------------------------------------------------
mkdir -p "${SCRIPT_DIR}/ssc-webapp/data" "${SCRIPT_DIR}/ssc-mysql/data"

# SSC container runs as UID 1111
if [[ "$(uname)" == "Linux" ]]; then
    info "Setting volume permissions (UID 1111)..."
    chown -R 1111 "${SCRIPT_DIR}/ssc-webapp/data" "${SCRIPT_DIR}/ssc-webapp/secrets" 2>/dev/null || \
        warn "Could not set permissions. You may need to run: sudo chown -R 1111 ssc-webapp/data ssc-webapp/secrets"
fi
ok "Data directories ready"

# -------------------------------------------------------
# 7. Check Docker Hub access
# -------------------------------------------------------
echo ""
info "Checking Docker Hub access..."
if docker pull --quiet "${SSC_IMAGE:-fortifydocker/ssc-webapp:25.4.0.0137}" &>/dev/null 2>&1; then
    ok "SSC image available"
else
    warn "Could not pull SSC image."
    echo ""
    echo "  The SSC image is not publicly available."
    echo "  Make sure you are logged in to Docker Hub and have"
    echo "  access to the fortifydocker repository."
    echo ""
    echo "  Run: docker login"
    echo ""
    read -rp "  Press ENTER to continue (or Ctrl+C to abort)..."
fi

# -------------------------------------------------------
# 8. Start containers
# -------------------------------------------------------
echo ""
read -rp "Start containers now? (y/N) " START
if [[ "${START}" =~ ^[yYjJ]$ ]]; then
    info "Starting containers..."
    cd "${SCRIPT_DIR}"
    docker compose up -d

    echo ""
    ok "Containers started!"
    echo ""
    echo "  SSC URL:    https://localhost:${SSC_HTTPS_PORT:-8443}"
    echo "  Login:      admin / admin (must be changed on first login)"
    echo "  First startup may take 2-5 minutes."
    echo ""
    echo "  View logs:  docker compose logs -f"
    echo "  Stop:       docker compose down"
    echo ""
    echo "  IMPORTANT: After SSC is up, extract the secret key:"
    echo "    docker cp ssc-webapp:/fortify/ssc/conf/secret.key ssc-webapp/secrets/secret.key"
    echo "  Then uncomment COM_FORTIFY_SSC_SECRETKEY in .env"
    echo ""
else
    echo ""
    ok "Setup complete!"
    echo ""
    echo "  Start containers with:"
    echo "    cd ${SCRIPT_DIR} && docker compose up -d"
    echo ""
fi
