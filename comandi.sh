# Funzione per l'inizializzazione
inizializzazione() {
  echo "Eseguendo inizializzazione..."
  cd Projects/minio-keycloak-sso/
  minikube start --driver=docker --cpus=3 --memory=6144
  minikube addons enable ingress
  kubectl create ns cert-manager
  kubectl create ns keycloak
  kubectl create ns minio-operator
  kubectl create ns tenant-1
}

# Funzione per configurare Cert-Manager
configura_cert_manager() {
  echo "Configurando Cert-Manager..."
  helm upgrade --install cert-manager jetstack/cert-manager \
    --namespace cert-manager --create-namespace \
    --set crds.enabled=true
  kubectl apply -f certs/selfsigned-root-clusterissuer.yaml
}

# Funzione per configurare Keycloak
configura_keycloak() {
  echo "Configurando Keycloak..."
  kubectl apply -f certs/keycloak/keycloak-ca-certificate.yaml
  kubectl apply -f certs/keycloak/keycloak-ca-issuer.yaml
  kubectl apply -f certs/keycloak/keycloak-certificate.yaml
  kubectl get secrets -n keycloak keycloak-ca-tls \
    -o=jsonpath='{.data.ca\.crt}' | base64 -d > keycloak-ca.crt
  kubectl create secret generic operator-ca-tls-keycloak \
    --from-file=keycloak-ca.crt -n keycloak
  kubectl create secret generic operator-ca-tls-keycloak \
    --from-file=keycloak-ca.crt -n tenant-1
  helm upgrade --install keycloak bitnami/keycloak --namespace keycloak --create-namespace -f keycloak/values.yaml
  KEYCLOAK_PASSWORD=$(kubectl -n keycloak get secret keycloak -o jsonpath='{.data.admin-password}' | base64 -d)
  echo "Password di Keycloak: $KEYCLOAK_PASSWORD"
}

# Funzione per configurare il MinIO Operator
configura_minio_operator() {
  echo "Configurando MinIO Operator..."
  kubectl apply -f certs/minio/operator-ca-tls-secret.yaml
  kubectl apply -f certs/minio/operator-ca-issuer.yaml
  kubectl apply -f certs/minio/sts-tls-certificate.yaml
  helm upgrade --install operator minio-operator/operator \
    --namespace minio-operator --create-namespace \
    -f minio/o-values.yaml
}

# Funzione per configurare il tenant di MinIO
configura_tenant_minio() {
  echo "Configurando il tenant di MinIO..."
  kubectl apply -f certs/minio/tenant-1-ca-certificate.yaml
  kubectl apply -f certs/minio/tenant-1-ca-issuer.yaml
  kubectl apply -f certs/minio/tenant-1-minio-certificate.yaml
  kubectl get secrets -n tenant-1 tenant-1-ca-tls \
    -o=jsonpath='{.data.ca\.crt}' | base64 -d > minio-ca.crt
  kubectl create secret generic operator-ca-tls-tenant-1 \
    --from-file=minio-ca.crt -n minio-operator
  kubectl apply -f certs/ingress/minio-api-crt.yaml
  kubectl apply -f certs/ingress/minio-console-crt.yaml
  kubectl create secret generic myminio-tls-custom \
    --from-literal=public.crt="$(kubectl get secret myminio-tls -n tenant-1 -o jsonpath='{.data.tls\.crt}' | base64 -d)" \
    --from-literal=private.key="$(kubectl get secret myminio-tls -n tenant-1 -o jsonpath='{.data.tls\.key}' | base64 -d)" \
    -n tenant-1
  kubectl patch secret myminio-tls -n tenant-1 --type='json' -p='[
    {"op": "replace", "path": "/data/public.crt", "value":"'"$(kubectl get secret myminio-tls-custom -n tenant-1 -o jsonpath='{.data.public\.crt}')"'" },
    {"op": "replace", "path": "/data/private.key", "value":"'"$(kubectl get secret myminio-tls-custom -n tenant-1 -o jsonpath='{.data.private\.key}')"'" }
  ]'
  kubectl create secret generic keycloak-tls-custom \
    --from-literal=public.crt="$(kubectl get secret keycloak-tls -n keycloak -o jsonpath='{.data.tls\.crt}' | base64 -d)" \
    --from-literal=private.key="$(kubectl get secret keycloak-tls -n keycloak -o jsonpath='{.data.tls\.key}' | base64 -d)" \
    -n tenant-1
  helm upgrade --install myminio minio-operator/tenant \
    --namespace tenant-1 --create-namespace \
    -f minio/t-values.yaml
}

inizializzazione
configura_cert_manager
configura_keycloak
configura_minio_operator
configura_tenant_minio
