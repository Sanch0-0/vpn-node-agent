#!/bin/bash
set -e

CONTROLPLANE_URL=$1
NODE_ID=$2
BOOTSTRAP_TOKEN=$3
CERT_DIR="/etc/nginx/certs"

mkdir -p "$CERT_DIR"

# Donwload CA from ControlPlane
echo "Fetching CA certificate..."
curl -sf "$CONTROLPLANE_URL/internal/ca" \
  -o "$CERT_DIR/ca.crt" \
  || { echo "ERROR: Failed to fetch CA cert"; exit 1; }

echo "Requesting node certificate..."
NODE_IP=$(curl -sf https://api.ipify.org || curl -sf https://ifconfig.me)

response=$(curl -s \
  --cacert "$CERT_DIR/ca.crt" \
  -X POST "$CONTROLPLANE_URL/internal/nodes/enroll" \
  -H "Content-Type: application/json" \
  -d "{\"node_id\":\"$NODE_ID\",\"token\":\"$BOOTSTRAP_TOKEN\",\"public_ip\":\"$NODE_IP\"}")

if echo "$response" | jq -e '.cert' > /dev/null 2>&1; then
    echo "$response" | jq -r '.cert' > "$CERT_DIR/node.crt"
    echo "$response" | jq -r '.key'  > "$CERT_DIR/node.key"
    echo "$response" | jq -r '.ca'   > "$CERT_DIR/ca.crt" 
    chmod 600 "$CERT_DIR/node.key"
    chmod 644 "$CERT_DIR/node.crt"
    chmod 644 "$CERT_DIR/ca.crt"
    echo "Node certificate installed successfully"
else
    echo "ERROR: Enroll failed. Response: $response"
    exit 1
fi

# === Nginx configuration ===
echo "Validating nginx config..."
nginx -t || { echo "ERROR: nginx config invalid"; exit 1; }

systemctl enable nginx
systemctl restart nginx

# start agent service
systemctl daemon-reload
systemctl enable vpn-agent.service
systemctl restart vpn-agent.service
