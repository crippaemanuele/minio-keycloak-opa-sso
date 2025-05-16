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
  #KEYCLOAK
  echo 30
  kubectl apply -f certs/keycloak/keycloak-ca-certificate.yaml
  echo 32
  kubectl apply -f certs/keycloak/keycloak-ca-issuer.yaml
  echo 34
  kubectl wait --for=create secret keycloak-ca-tls -n keycloak
  kubectl get secrets -n keycloak keycloak-ca-tls \
    -o=jsonpath='{.data.ca\.crt}' | base64 -d > keycloak-ca.crt
  echo 38
  kubectl create secret generic keycloak-ca-tls \
    --from-file=keycloak-ca.crt -n cert-manager
  #MINIO-OPERATOR
  echo 42
  kubectl apply -f certs/minio/operator-ca-tls-secret.yaml
  echo 44
  kubectl apply -f certs/minio/operator-ca-issuer.yaml
  echo 46
  kubectl apply -f certs/minio/sts-tls-certificate.yaml
  #MINIO-TENANT
  echo 49
  kubectl apply -f certs/minio/tenant-1-ca-certificate.yaml
  echo 51
  kubectl apply -f certs/minio/tenant-1-ca-issuer.yaml
  echo 53
  kubectl apply -f certs/minio/tenant-1-minio-certificate.yaml
  kubectl wait --for=create secret tenant-1-ca-tls -n tenant-1
  echo 56
  kubectl get secrets -n tenant-1 tenant-1-ca-tls \
    -o=jsonpath='{.data.ca\.crt}' | base64 -d > minio-ca.crt
  echo 59
  kubectl create secret generic tenant-1-ca-tls \
    --from-file=minio-ca.crt -n cert-manager
  # Estrai e decodifica i dati in file temporanei
  mkdir ./tmp
  kubectl wait --for=create secret myminio-tls -n tenant-1
  echo 65
  kubectl get secret myminio-tls -n tenant-1 -o jsonpath='{.data.tls\.crt}' | base64 -d > tmp/m_public.crt
  echo 67
  kubectl get secret myminio-tls -n tenant-1 -o jsonpath='{.data.tls\.key}' | base64 -d > tmp/m_private.key
  # Crea il nuovo secret mantenendo la formattazione esatta
  echo 70
  kubectl create secret generic myminio-tls-custom \
    --from-file=public.crt=tmp/m_public.crt \
    --from-file=private.key=tmp/m_private.key \
    -n tenant-1

  # Aggiungi public.crt e private.key al secret myminio-tls
  echo 77
  kubectl patch secret myminio-tls -n tenant-1 --type='json' -p='[
    {"op": "add", "path": "/data/public.crt", "value":"'"$(cat tmp/m_public.crt | base64 -w 0)"'"},
    {"op": "add", "path": "/data/private.key", "value":"'"$(cat tmp/m_private.key | base64 -w 0)"'"}
  ]'

  # Estrai e decodifica i dati in file temporanei
  kubectl wait --for=create secret keycloak-tls -n keycloak
  echo 85
  kubectl get secret keycloak-tls -n keycloak -o jsonpath='{.data.tls\.crt}' | base64 -d > tmp/k_public.crt
  echo 87
  kubectl get secret keycloak-tls -n keycloak -o jsonpath='{.data.tls\.key}' | base64 -d > tmp/k_private.key
  # Crea il nuovo secret mantenendo la formattazione esatta
  echo 90
  kubectl create secret generic keycloak-tls-custom \
    --from-file=public.crt=tmp/k_public.crt \
    --from-file=private.key=tmp/k_private.key \
    -n tenant-1
  # Pulisci i file temporanei 
  rm -rf ./tmp

  #Creazione bundle
  kubectl create -f trust-manager/bundle.yaml
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
