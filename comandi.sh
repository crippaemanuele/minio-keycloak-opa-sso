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
