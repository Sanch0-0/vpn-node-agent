#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== VPN Node Agent Setup Script ===${NC}"

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Must be run as root${NC}"
   exit 1
fi

ENV_FILE="/opt/agent/.env"

if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}ERROR: $ENV_FILE not found${NC}"
    echo "Create it with: AGENT_TOKEN, CONTROL_PLANE_IP, NODE_ID"
    exit 1
fi

source "$ENV_FILE"

: "${AGENT_TOKEN:?Missing AGENT_TOKEN in $ENV_FILE}"
: "${CONTROL_PLANE_IP:?Missing CONTROL_PLANE_IP in $ENV_FILE}"
: "${NODE_ID:?Missing NODE_ID in $ENV_FILE}"

PORT=${PORT:-9000}
WG_INTERFACE=${WG_INTERFACE:-wg0}
LOG_LEVEL=${LOG_LEVEL:-info}

echo -e "${GREEN}Installing system dependencies...${NC}"
apt-get update -qq
apt-get install -y -qq \
    python3 python3-pip python3-venv \
    wireguard wireguard-tools \
    nginx jq curl git

# Repo already had cloned to /opt/agent-repo via cloud-init
mkdir -p /opt/agent
cp -r /opt/agent-repo/agent/* /opt/agent/
cp -r /opt/agent-repo/infra/nginx/* /opt/agent/nginx/ 2>/dev/null || true

cd /opt/agent
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip -q
pip install -r requirements.txt -q

# UFW
echo -e "${GREEN}Configuring firewall...${NC}"
ufw allow 443/tcp
ufw allow 51820/udp   # WireGuard
ufw deny "$PORT"/tcp
ufw --force enable

# Nginx
echo -e "${GREEN}Configuring Nginx...${NC}"
mkdir -p /etc/nginx/certs
mkdir -p /etc/nginx/conf.d

cp /opt/agent-repo/infra/nginx/nginx.conf /etc/nginx/nginx.conf
cp /opt/agent-repo/infra/nginx/agent.conf /etc/nginx/conf.d/agent.conf

nginx -t || { echo "ERROR: nginx config invalid"; exit 1; }
systemctl enable nginx
# will run after bootstrap_node.sh

# Systemd service
echo -e "${GREEN}Creating systemd service...${NC}"
cat > /etc/systemd/system/vpn-agent.service <<EOF
[Unit]
Description=VPN Node Agent
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/agent
EnvironmentFile=/opt/agent/.env
Restart=always
ExecStart=/opt/agent-repo/scripts/run.sh
RestartSec=10
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable vpn-agent.service
# will start after nginx starts up with certificates 
echo -e "${GREEN}Setup complete. Run bootstrap_node.sh next.${NC}"
