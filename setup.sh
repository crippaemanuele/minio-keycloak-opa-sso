#!/bin/bash

set -euo pipefail

### 📌 CONFIGURAZIONE ###
CERT_DIR="certs"
MINIO_ALIAS_ROOT="minio_root"
MINIO_ALIAS_OIDC="medico_oidc"
MINIO_URL="https://minio-api.local"
KEYCLOAK_TOKEN_ENDPOINT="https://keycloak.local/realms/MinIO/protocol/openid-connect/token"
CLIENT_ID="minio-client"
CLIENT_SECRET="UySDgZLFW9GSWjtwVMx4yxEnpMkqD4"
USERNAME="medico"
PASSWORD="medico_pass"
ROLE_ARN="arn:minio:iam:::role/1mAsqpUGox8eewepDQ1dmtwpdY8"
MC_BIN="$HOME/minio-binaries/mc"
PATH=$PATH:$HOME/minio-binaries/

### ▶️ ESECUZIONE PASSO-PASSO ###

echo "📥 Aggiorno certificati locali..."
sudo cp "$CERT_DIR"/*.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates

if ! command -v mc >/dev/null 2>&1; then
  echo "📦 Installo MinIO Client (mc)..."
  curl -sSL https://dl.min.io/client/mc/release/linux-amd64/mc \
    --create-dirs -o "$MC_BIN"
  chmod +x "$MC_BIN"
fi

echo "🐍 Avvio autenticazione OIDC tramite Python..."
python3 oidc_auth.py
