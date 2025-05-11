# Funzione per l'inizializzazione del progetto
inizializzazione() {
  echo "Inizializzazione del progetto..."
  cd Projects/minio-keycloak-sso/
  minikube start --driver=docker --cpus=3 --memory=6gb
  minikube addons enable ingress
  kubectl create namespace minio-tenant
  kubectl create namespace minio-operator
  kubectl create namespace keycloak
  sleep 10
}

# Funzione per l'installazione di cert-manager
installa_cert_manager() {
  echo "Installazione di cert-manager..."
  helm upgrade --install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --set crds.enabled=true  # Installa o aggiorna cert-manager con CRD abilitate
  sleep 10  # Attende 10 secondi per assicurarsi che cert-manager sia pronto

  echo "Creazione del cluster issuer e dei certificati..."
  kubectl apply -f certs/cluster-issuer.yaml  # Applica il ClusterIssuer per la gestione dei certificati
  kubectl apply -f certs/minio/operator-ca-tls-secret.yaml  # Configura il certificato CA per l'operatore MinIO
  kubectl apply -f certs/minio/operator-ca-issuer.yaml  # Crea l'Issuer per l'operatore MinIO basato sul certificato CA
  kubectl apply -f certs/minio/sts-tls-certificate.yaml  # Configura il certificato TLS per il servizio STS di MinIO
  kubectl apply -f certs/minio/tenant-ca-certificate.yaml  # Configura il certificato CA per il tenant MinIO
  kubectl apply -f certs/minio/tenant-ca-issuer.yaml  # Crea l'Issuer per il tenant MinIO basato sul certificato CA
  kubectl apply -f tenant-minio-certificate.yaml  # Configura il certificato TLS per il tenant MinIO
  kubectl apply -f certs/minio/minio-api-crt.yaml  # Configura il certificato TLS per l'API di MinIO
  kubectl apply -f certs/minio/minio-console-crt.yaml  # Configura il certificato TLS per la console di MinIO
  kubectl get secrets -n minio-tenant tenant-ca-tls -o=jsonpath='{.data.ca\.crt}' | base64 -d > ca.crt  # Estrae il certificato CA del tenant e lo salva in un file
  kubectl create secret generic operator-ca-tls-tenant --from-file=ca.crt -n minio-operator  # Crea un secret per il certificato CA del tenant nell'operatore MinIO
}

# Funzione per l'installazione di Keycloak
installa_keycloak() {
  echo "Installazione di Keycloak..."
  helm upgrade --install keycloak bitnami/keycloak --namespace keycloak --create-namespace -f keycloak/values.yaml
  sleep 30
  KEYCLOAK_PASSWORD=$(kubectl -n keycloak get secret keycloak -o jsonpath='{.data.admin-password}' | base64 -d)
  echo "Password di Keycloak: $KEYCLOAK_PASSWORD"
}

# Funzione per l'installazione di Minio
installa_minio() {
  echo "Installazione di Minio..."
  helm upgrade --install --namespace minio-operator --create-namespace operator minio-operator/operator
  kubectl apply -k minio-operator
  sleep 5
  kubectl apply -f minio/utenza_admin.yaml
  helm upgrade --install minio minio-operator/tenant --namespace minio-tenant --create-namespace -f minio/values.yaml
}

# Chiamata delle funzioni in sequenza
inizializzazione
installa_cert_manager
#installa_keycloak
installa_minio