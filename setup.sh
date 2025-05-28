#!/bin/bash

# 🔒 Aggiunge certificati self-signed al sistema (Keycloak + MinIO)
echo "📥 Aggiorno certificati locali..."
sudo cp certs/*.crt /usr/local/share/ca-certificates/ && sudo update-ca-certificates

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

#TO-DO: Da qui in giù riscrivere in python
#Auth-flow:
ENDPOINT_KEYCLOAK="https://keycloak.local/realms/MinIO/protocol/openid-connect/token"
ENDPOINT_MINIO="https://minio-api.local/"
client_id="minio-client"
client_secret="UySDgZLFW9GSWjtwVMx4yxEnpMkqD4"
username="medico"
password="medico_pass"
# Ottieni token OIDC
token_oidc=$(curl -s -d "client_id=$client_id" \
     -d "client_secret=$client_secret" \
     -d "grant_type=password" \
     -d "username=$username" \
     -d "password=$password" \
     -d "scope=openid profile email" \
     -H "Content-Type: application/x-www-form-urlencoded" \
     -X POST $ENDPOINT_KEYCLOAK | jq -r '.access_token')
  # Ottieni token STS temporaneo
sts_response=$(curl -s -X POST "$ENDPOINT_MINIO" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "Action=AssumeRoleWithWebIdentity" \
  -d "Version=2011-06-15" \
  -d "WebIdentityToken=$token_oidc" \
  -d "RoleArn=arn:minio:iam:::role/dummy-internal" \
  -d "RoleSessionName=my-session")
  # Accedi a MinIO con token STS

## 🐍 Avvia script Python OIDC
#echo "🐍 Avvio autenticazione OIDC tramite Python..."
#python3 oidc_auth.py
