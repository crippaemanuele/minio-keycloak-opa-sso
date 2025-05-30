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

echo "🔗 Creo alias root MinIO..."
mc alias set "$MINIO_ALIAS_ROOT" "$MINIO_URL" minio minio123

#echo "📦 Installo dipendenze Python..."
#pip install --upgrade pip
#pip install requests minio

#echo "🔑 Richiedo token OIDC da Keycloak..."
#token_oidc=$(curl -s -X POST "$KEYCLOAK_TOKEN_ENDPOINT" \
#  -d "client_id=$CLIENT_ID" \
#  -d "client_secret=$CLIENT_SECRET" \
#  -d "grant_type=password" \
#  -d "username=$USERNAME" \
#  -d "password=$PASSWORD" \
#  -d "scope=openid profile email" |
#  jq -r '.access_token')
#
#echo "🔐 Assumo ruolo su MinIO tramite STS..."
#token_sts=$(curl -s -X POST "$MINIO_URL" \
#  -d "Action=AssumeRoleWithWebIdentity" \
#  -d "Version=2011-06-15" \
#  -d "DurationSeconds=86000" \
#  -d "Token=$token_oidc" \
#  -d "RoleArn=$ROLE_ARN")
#
#echo "🧪 Estraggo credenziali temporanee..."
#access_key=$(echo "$token_sts" | xmllint --xpath "string(//*[local-name()='AccessKeyId'])" -)
#secret_key=$(echo "$token_sts" | xmllint --xpath "string(//*[local-name()='SecretAccessKey'])" -)
#session_token=$(echo "$token_sts" | xmllint --xpath "string(//*[local-name()='SessionToken'])" -)
#
#if [[ -z "$access_key" || -z "$secret_key" || -z "$session_token" ]]; then
#  echo "❌ Errore nell'estrazione delle credenziali."
#  exit 1
#fi
#
#echo "🔑 Credenziali ottenute:"
#echo "  Access Key: $access_key"
#echo "  Secret Key: $secret_key"
#echo "  Session Token: $session_token"
#
#echo "🔗 Imposto variabili d'ambiente per mc..."
#export MC_ACCESS_KEY="$access_key"
#export MC_SECRET_KEY="$secret_key"
#export MC_SESSION_TOKEN="$session_token"
#
#echo "🔗 Creo alias MinIO OIDC temporaneo (con session token)..."
#mc alias set "$MINIO_ALIAS_OIDC" "$MINIO_URL" "$access_key" "$secret_key"

echo "🐍 Avvio autenticazione OIDC tramite Python..."
python3 oidc_auth.py
