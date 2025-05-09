# Funzione per l'inizializzazione del progetto
inizializzazione() {
  echo "Inizializzazione del progetto..."
  cd Projects/minio-keycloak-sso/
  minikube start --driver=docker --cpus=3 --memory=6gb
  minikube addons enable ingress
  kubectl create namespace minio-tenant
  sleep 10
}

# Funzione per l'installazione di cert-manager
installa_cert_manager() {
  echo "Installazione di cert-manager..."
  helm upgrade --install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --set crds.enabled=true
  sleep 10
  echo "Creazione del cluster issuer e dei certificati..."
  kubectl apply -f certs/cluster-issuer.yaml
  kubectl apply -f certs/minio/minio-api-crt.yaml
  kubectl apply -f certs/minio/minio-console-crt.yaml
}

# Funzione per l'installazione di Keycloak
installa_keycloak() {
  echo "Installazione di Keycloak..."
  helm upgrade --install keycloak bitnami/keycloak -n keycloak -f keycloak/values.yaml
  sleep 30
  KEYCLOAK_PASSWORD=$(kubectl -n keycloak get secret keycloak -o jsonpath='{.data.admin-password}' | base64 -d)
  echo "Password di Keycloak: $KEYCLOAK_PASSWORD"
}

# Funzione per l'installazione di Minio
installa_minio() {
  echo "Installazione di Minio..."
  helm upgrade --install --namespace minio-operator --create-namespace operator minio-operator/operator
  helm upgrade --install minio minio-operator/tenant --namespace minio-tenant --create-namespace -f minio/values.yaml
}

# Chiamata delle funzioni in sequenza
inizializzazione
installa_cert_manager
#installa_keycloak
installa_minio