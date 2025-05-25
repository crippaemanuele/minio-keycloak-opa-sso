#!/bin/bash

# 🔒 Aggiorna il truststore con i certificati locali per accettare Keycloak e MinIO self-signed
sudo cp Projects/minio-keycloak-sso/certs/*.crt /usr/local/share/ca-certificates/ && sudo update-ca-certificates

# 📦 Installa il client MinIO (`mc`)
curl https://dl.min.io/client/mc/release/linux-amd64/mc \
  --create-dirs \
  -o $HOME/minio-binaries/mc

chmod +x $HOME/minio-binaries/mc
export PATH=$PATH:$HOME/minio-binaries/

# 🔗 Crea un alias base per accedere a MinIO con l'utente root
mc alias set minio_root https://minio-api.local minio minio123

# ⚙️ Configura variabili per l'autenticazione OIDC con Keycloak
KEYCLOAK_URL="https://keycloak.local"
REALM="MinIO"
CLIENT_ID="minio-client"
CLIENT_SECRET="UySDgZLFW9GSWjtwVMx4yxEnpMkqD4"
MINIO_ENDPOINT="https://minio-api.local"

# Array di alias da creare (uno per ogni utente)
ALIASES=("oidc-root" "oidc-medico" "oidc-segretaria" "oidc-paziente")
ACCESS_KEYS=("amministratore" "medico" "segretaria" "paziente")
SECRET_KEYS=("amministratore_pass" "medico_pass" "segretaria_pass" "paziente_pass")

# 🔁 Ciclo sugli alias e relative credenziali
for i in "${!ALIASES[@]}"; do
  alias="${ALIASES[$i]}"
  username="${ACCESS_KEYS[$i]}"
  password="${SECRET_KEYS[$i]}"

  # 🎟️ Ottieni un access token OIDC da Keycloak
  RESPONSE=$(curl -s -X POST "${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=password" \
    -d "client_id=${CLIENT_ID}" \
    -d "client_secret=${CLIENT_SECRET}" \
    -d "username=${username}" \
    -d "password=${password}" \
    -d "scope=openid")

  ACCESS_TOKEN=$(echo "$RESPONSE" | jq -r .access_token)

  # ❗ Verifica che il token sia stato ottenuto correttamente
  if [[ "$ACCESS_TOKEN" == "null" || -z "$ACCESS_TOKEN" ]]; then
    echo "❌ Errore nell'ottenere il token per $username."
    echo "Risposta Keycloak: $RESPONSE"
    exit 1
  fi

  # 🏷️ Crea un alias `mc` usando il token OIDC
  mc alias set "$alias" "$MINIO_ENDPOINT" "$username" "$password" --api S3v4
  if [[ $? -ne 0 ]]; then
    echo "❌ Errore nella configurazione dell'alias mc: $alias"
    exit 1
  fi
done
