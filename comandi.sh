#Aggiorna truststore
sudo cp Projects/minio-keycloak-sso/certs/*.crt /usr/local/share/ca-certificates/ && sudo update-ca-certificates
#Installa MinIO client
curl https://dl.min.io/client/mc/release/linux-amd64/mc \
  --create-dirs \
  -o $HOME/minio-binaries/mc

chmod +x $HOME/minio-binaries/mc
export PATH=$PATH:$HOME/minio-binaries/

#Crea alias
mc alias set minio_root https://minio-api.local minio minio123

#!/bin/bash

# Configurazione variabili
KEYCLOAK_URL="https://keycloak.local"
REALM="MinIO"
CLIENT_ID="minio-client"
CLIENT_SECRET="UySDgZLFW9GSWjtwVMx4yxEnpMkqD4"
MINIO_ALIAS="minio-oidc"
MINIO_ENDPOINT="https://minio.local"

# Chiedi username e password in modo sicuro
read -p "Username: " USERNAME
read -s -p "Password: " PASSWORD
echo

# Ottieni il token OIDC da Keycloak (access_token)
RESPONSE=$(curl -s -X POST "${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=${CLIENT_ID}" \
  -d "client_secret=${CLIENT_SECRET}" \
  -d "username=${USERNAME}" \
  -d "password=${PASSWORD}" \
  -d "scope=openid")

ACCESS_TOKEN=$(echo "$RESPONSE" | jq -r .access_token)

if [[ "$ACCESS_TOKEN" == "null" || -z "$ACCESS_TOKEN" ]]; then
  echo "Errore nell'ottenere il token. Controlla username, password, client_id e secret."
  echo "Risposta Keycloak:"
  echo "$RESPONSE"
  exit 1
fi

echo "Token ottenuto con successo!"

# Configura mc con il token come access key
mc alias set "$MINIO_ALIAS" "$MINIO_ENDPOINT" "$ACCESS_TOKEN" "" --api S3v4

if [[ $? -ne 0 ]]; then
  echo "Errore nella configurazione dell'alias mc."
  exit 1
fi

echo "Alias mc configurato: $MINIO_ALIAS -> $MINIO_ENDPOINT"

# Esegui un comando di prova
mc ls "$MINIO_ALIAS"

# Fine script
