#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

trap 'error "Failed at line $LINENO"' ERR

echo -e "${GREEN}=== VPN Node Agent Setup Script ===${NC}"

# ---------------------------
# 1. Root check
# ---------------------------
if [[ $EUID -ne 0 ]]; then
   error "Must be run as root"
   exit 1
fi

# ---------------------------
# 2. Env
# ---------------------------
ENV_FILE="/opt/agent/.env"

if [[ ! -f "$ENV_FILE" ]]; then
    error "$ENV_FILE not found"
    exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE"

: "${CONTROLPLANE_URL:?Missing CONTROLPLANE_URL}"
: "${NODE_ID:?Missing NODE_ID}"

PORT=${PORT:-9000}
WG_INTERFACE=${WG_INTERFACE:-wg0}
LOG_LEVEL=${LOG_LEVEL:-info}

# ---------------------------
# 3. System deps
# ---------------------------
log "Installing system dependencies..."

apt-get update -qq

apt-get install -y -qq \
    python3 python3-pip python3-venv \
    wireguard wireguard-tools \
    nginx jq curl git ufw

# ---------------------------
# 4. Runtime dirs
# ---------------------------
log "Preparing runtime directories..."

mkdir -p /opt/agent
mkdir -p /opt/agent/nginx

# ---------------------------
# 5. Copy ONLY agent runtime code
# ---------------------------
log "Copying agent source from repo..."

cp -r /opt/agent-repo/agent/* /opt/agent/

# nginx configs (optional)
cp -r /opt/agent-repo/infra/nginx/* /opt/agent/nginx/ 2>/dev/null || true

# IMPORTANT: requirements is in repo root
REQUIREMENTS_FILE="/opt/agent-repo/requirements.txt"

if [[ ! -f "$REQUIREMENTS_FILE" ]]; then
    error "requirements.txt not found in repo root"
    exit 1
fi

# ---------------------------
# 6. Python venv
# ---------------------------
log "Creating Python venv..."

cd /opt/agent

python3 -m venv venv
# shellcheck disable=SC1091
source venv/bin/activate

pip install --upgrade pip -q
pip install -r "$REQUIREMENTS_FILE" -q

# ---------------------------
# 7. Firewall (safe mode)
# ---------------------------
log "Configuring firewall..."

ufw allow 443/tcp || true
ufw allow 51820/udp || true
ufw allow "$PORT"/tcp || true

ufw --force enable || true

# ---------------------------
# 8. Nginx
# ---------------------------
log "Configuring Nginx..."

mkdir -p /etc/nginx/certs
mkdir -p /etc/nginx/conf.d

cp /opt/agent-repo/infra/nginx/nginx.conf /etc/nginx/nginx.conf
cp /opt/agent-repo/infra/nginx/agent.conf /etc/nginx/conf.d/agent.conf

# ---------------------------
# 9. Systemd service
# ---------------------------
log "Creating systemd service..."

cat > /etc/systemd/system/vpn-agent.service <<EOF
[Unit]
Description=VPN Node Agent
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/agent
EnvironmentFile=/opt/agent/.env
Restart=always
ExecStart=/opt/agent/venv/bin/uvicorn main:app --host 127.0.0.1 --port 9000 --workers 1 --log-level info
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

log "Setup complete. Run bootstrap_node.sh next."

# -------------------------
# 10. IP Forwarding + NAT 
# -------------------------
log "Enabling IP forwarding and NAT..."

echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

MAIN_IFACE=$(ip route | grep default | awk '{print $5}' | head -1)
iptables -t nat -A POSTROUTING -o "$MAIN_IFACE" -j MASQUERADE

apt-get install -y -qq iptables-persistent netfilter-persistent
netfilter-persistent save

log "NAT configured on interface $MAIN_IFACE"
