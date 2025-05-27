#!/bin/bash

# 🔒 Aggiunge certificati self-signed al sistema (Keycloak + MinIO)
echo "📥 Aggiorno certificati locali..."
sudo cp Projects/minio-keycloak-sso/certs/*.crt /usr/local/share/ca-certificates/ && sudo update-ca-certificates

# 📦 Installa mc se non presente
if ! command -v mc &> /dev/null; then
  echo "📦 Installo MinIO Client (mc)..."
  curl https://dl.min.io/client/mc/release/linux-amd64/mc \
    --create-dirs \
    -o $HOME/minio-binaries/mc
  chmod +x $HOME/minio-binaries/mc
  export PATH=$PATH:$HOME/minio-binaries/
fi

# 🔗 Alias per utente root MinIO
echo "🔗 Creo alias root MinIO..."
mc alias set minio_root https://minio-api.local minio minio123

# 🐍 Avvia script Python OIDC
echo "🐍 Avvio autenticazione OIDC tramite Python..."
python3 oidc_auth.py
