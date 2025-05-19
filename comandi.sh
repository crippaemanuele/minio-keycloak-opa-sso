# Funzione per l'inizializzazione
inizializzazione() {
  echo "Eseguendo inizializzazione..."
  cd Projects/minio-keycloak-sso/
  minikube start --driver=docker --cpus=3 --memory=6144
  minikube addons enable ingress
  kubectl create ns cert-manager
  kubectl create ns keycloak
  kubectl label namespace keycloak create-ca-bundle=true --overwrite=true
  kubectl create ns minio-operator
  kubectl create ns tenant-1
  kubectl label namespace tenant-1 create-ca-bundle=true --overwrite=true
}

# Funzione per configurare Cert-Manager
configura_cert_manager() {
  echo "Configurando Cert-Manager..."
  helm upgrade --install cert-manager jetstack/cert-manager \
    --namespace cert-manager --create-namespace \
    --set crds.enabled=true
  helm upgrade --install trust-manager jetstack/trust-manager \
    --namespace cert-manager \
    -f trust-manager/values.yaml
  kubectl apply -f certs/selfsigned-root-clusterissuer.yaml
}

configura_certificati(){
  # --- KEYCLOAK ---
  kubectl apply -f certs/keycloak/keycloak-ca-certificate.yaml  # Applica CA Keycloak
  kubectl apply -f certs/keycloak/keycloak-ca-issuer.yaml       # Applica issuer Keycloak
  kubectl wait --for=create secret keycloak-ca-tls -n keycloak  # Attendi secret CA Keycloak
  kubectl get secrets -n keycloak keycloak-ca-tls -o=jsonpath='{.data.ca\.crt}' | base64 -d > keycloak-ca.crt  # Estrai CA Keycloak
  kubectl create secret generic keycloak-ca-tls --from-file=keycloak-ca.crt -n cert-manager  # Secret CA Keycloak per cert-manager

  # --- MINIO OPERATOR ---
  kubectl apply -f certs/minio/operator-ca-tls-secret.yaml      # Secret CA Operator
  kubectl apply -f certs/minio/operator-ca-issuer.yaml          # Issuer Operator
  kubectl apply -f certs/minio/sts-tls-certificate.yaml         # Certificato TLS Operator

  # --- MINIO TENANT ---
  kubectl apply -f certs/minio/tenant-1-ca-certificate.yaml     # CA Tenant
  kubectl apply -f certs/minio/tenant-1-ca-issuer.yaml          # Issuer Tenant
  kubectl apply -f certs/minio/tenant-1-minio-certificate.yaml  # Certificato Tenant
  kubectl wait --for=create secret tenant-1-ca-tls -n tenant-1  # Attendi secret CA Tenant
  kubectl get secrets -n tenant-1 tenant-1-ca-tls -o=jsonpath='{.data.ca\.crt}' | base64 -d > minio-ca.crt  # Estrai CA Tenant
  kubectl create secret generic tenant-1-ca-tls --from-file=minio-ca.crt -n cert-manager  # Secret CA Tenant per cert-manager

  # --- ESTRAZIONE E PATCH DEI CERTIFICATI ---
  mkdir ./tmp  # Crea cartella temporanea
  kubectl wait --for=create secret myminio-tls -n tenant-1  # Attendi secret TLS MinIO
  kubectl get secret myminio-tls -n tenant-1 -o jsonpath='{.data.tls\.crt}' | base64 -d > tmp/m_public.crt  # Estrai cert pubblico MinIO
  kubectl get secret myminio-tls -n tenant-1 -o jsonpath='{.data.tls\.key}' | base64 -d > tmp/m_private.key # Estrai chiave privata MinIO
  kubectl create secret generic myminio-tls-custom --from-file=public.crt=tmp/m_public.crt --from-file=private.key=tmp/m_private.key -n tenant-1  # Secret custom MinIO
  kubectl patch secret myminio-tls -n tenant-1 --type='json' -p='[
    {"op": "add", "path": "/data/public.crt", "value":"'"$(cat tmp/m_public.crt | base64 -w 0)"'"},
    {"op": "add", "path": "/data/private.key", "value":"'"$(cat tmp/m_private.key | base64 -w 0)"'"}
  ]'  # Aggiungi public.crt e private.key al secret originale

  # --- KEYCLOAK TLS PER TENANT ---
  kubectl wait --for=create secret keycloak-tls -n keycloak  # Attendi secret TLS Keycloak
  kubectl get secret keycloak-tls -n keycloak -o jsonpath='{.data.tls\.crt}' | base64 -d > tmp/k_public.crt  # Estrai cert pubblico Keycloak
  kubectl get secret keycloak-tls -n keycloak -o jsonpath='{.data.tls\.key}' | base64 -d > tmp/k_private.key # Estrai chiave privata Keycloak
  kubectl create secret generic keycloak-tls-custom --from-file=public.crt=tmp/k_public.crt --from-file=private.key=tmp/k_private.key -n tenant-1  # Secret custom Keycloak

  rm -rf ./tmp  # Pulisci cartella temporanea

  # --- BUNDLE TRUST MANAGER ---
  kubectl create -f trust-manager/bundle.yaml  # Crea bundle trust-manager
}

# Funzione per configurare Keycloak
configura_keycloak() {
  echo "Configurando Keycloak..."
  helm upgrade --install keycloak bitnami/keycloak --namespace keycloak --create-namespace -f keycloak/values.yaml
  KEYCLOAK_PASSWORD=$(kubectl -n keycloak get secret keycloak -o jsonpath='{.data.admin-password}' | base64 -d)
  echo "Password di Keycloak: $KEYCLOAK_PASSWORD"
}

# Funzione per configurare il MinIO Operator
configura_minio_operator() {
  echo "Configurando MinIO Operator..."
  helm upgrade --install operator minio-operator/operator \
    --namespace minio-operator --create-namespace \
    -f minio/o-values.yaml
}

# Funzione per configurare il tenant di MinIO
configura_tenant_minio() {
  kubectl wait --for=condition=Ready pod/keycloak-0 -n keycloak  # Attendi che Keycloak sia pronto
  echo "Configurando il tenant di MinIO..."
  helm upgrade --install myminio minio-operator/tenant \
    --namespace tenant-1 --create-namespace \
    -f minio/t-values.yaml
}

inizializzazione
configura_cert_manager
configura_certificati
configura_keycloak
configura_minio_operator
configura_tenant_minio
