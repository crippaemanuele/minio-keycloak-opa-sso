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

# Aggiorna pip (opzionale ma consigliato)
pip install --upgrade pip

# Installa requests
pip install requests

# Installa minio
pip install minio

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
     -X POST $ENDPOINT_KEYCLOAK | jq -r '.access_token')
#Ottieni credenziali STS
curl -X POST "https://minio-api.local" \
     -d "Action=AssumeRoleWithWebIdentity" \
     -d "Version=2011-06-15" \
     -d "DurationSeconds=86000" \
     -d "Token=$token_oidc" \
     -d "RoleArn=arn:minio:iam:::role/1mAsqpUGox8eewepDQ1dmtwpdY8"
# Accedi a MinIO con token OIDC

## 🐍 Avvia script Python OIDC
echo "🐍 Avvio autenticazione OIDC tramite Python..."
python3 oidc_auth.py
