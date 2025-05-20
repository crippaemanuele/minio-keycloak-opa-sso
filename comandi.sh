prerequisiti() {
  helm repo add jetstack https://charts.jetstack.io
  helm repo add bitnami https://charts.bitnami.com/bitnami
  helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
  helm repo add minio-operator https://operator.min.io
  helm repo update
  cd Projects/minio-keycloak-sso/
  sleep 3
  clear
}

inizializzazione() {
  echo "Eseguendo inizializzazione..."
  minikube start --driver=docker --cpus=3 --memory=6144
  minikube addons enable ingress
  kubectl create ns cert-manager
  kubectl create ns keycloak
  kubectl label namespace keycloak create-ca-bundle=true --overwrite=true
  kubectl create ns minio-operator
  kubectl create ns opa
  kubectl label namespace opa create-ca-bundle=true --overwrite=true
  kubectl create ns tenant-1
  kubectl label namespace tenant-1 create-ca-bundle=true --overwrite=true
  sleep 3
  clear
}

configura_cert_manager() {
  echo "Configurando Cert-Manager..."
  helm upgrade --install cert-manager jetstack/cert-manager \
    --namespace cert-manager --create-namespace \
    --set crds.enabled=true
  helm upgrade --install trust-manager jetstack/trust-manager \
    --namespace cert-manager \
    -f trust-manager/values.yaml
  kubectl apply -f certs/selfsigned-root-clusterissuer.yaml
  sleep 3
  clear
}

configura_certificati() {
  # --- KEYCLOAK ---
  kubectl apply -f certs/keycloak/keycloak-ca-certificate.yaml
  kubectl apply -f certs/keycloak/keycloak-ca-issuer.yaml
  kubectl wait --for=create secret keycloak-ca-tls -n keycloak
  kubectl get secrets -n keycloak keycloak-ca-tls -o jsonpath='{.data.ca\.crt}' | base64 -d > keycloak-ca.crt
  kubectl create secret generic keycloak-ca-tls --from-file=keycloak-ca.crt -n cert-manager

  # --- OPA ---
  kubectl apply -f certs/opa/opa-ca-certificate.yaml
  kubectl apply -f certs/opa/opa-ca-issuer.yaml
  kubectl wait --for=create secret opa-ca-tls -n opa
  kubectl get secrets -n opa opa-ca-tls -o jsonpath='{.data.ca\.crt}' | base64 -d > opa-ca.crt
  kubectl create secret generic opa-ca-tls --from-file=opa-ca.crt -n cert-manager

  # --- MINIO OPERATOR ---
  kubectl apply -f certs/minio/operator-ca-tls-secret.yaml
  kubectl apply -f certs/minio/operator-ca-issuer.yaml
  kubectl apply -f certs/minio/sts-tls-certificate.yaml

  # --- MINIO TENANT ---
  kubectl apply -f certs/minio/tenant-1-ca-certificate.yaml
  kubectl apply -f certs/minio/tenant-1-ca-issuer.yaml
  kubectl apply -f certs/minio/tenant-1-minio-certificate.yaml
  kubectl wait --for=create secret tenant-1-ca-tls -n tenant-1
  kubectl get secrets -n tenant-1 tenant-1-ca-tls -o jsonpath='{.data.ca\.crt}' | base64 -d > minio-ca.crt
  kubectl create secret generic tenant-1-ca-tls --from-file=minio-ca.crt -n cert-manager

  # --- ESTRAZIONE E PATCH DEI CERTIFICATI ---
  mkdir ./tmp
  kubectl wait --for=create secret myminio-tls -n tenant-1
  kubectl get secret myminio-tls -n tenant-1 -o jsonpath='{.data.tls\.crt}' | base64 -d > tmp/m_public.crt
  kubectl get secret myminio-tls -n tenant-1 -o jsonpath='{.data.tls\.key}' | base64 -d > tmp/m_private.key
  kubectl create secret generic myminio-tls-custom --from-file=public.crt=tmp/m_public.crt --from-file=private.key=tmp/m_private.key -n tenant-1
  kubectl patch secret myminio-tls -n tenant-1 --type='json' -p='[
    {"op": "add", "path": "/data/public.crt", "value":"'"$(cat tmp/m_public.crt | base64 -w 0)"'"},
    {"op": "add", "path": "/data/private.key", "value":"'"$(cat tmp/m_private.key | base64 -w 0)"'"}
  ]'
  rm -rf ./tmp
  sleep 30

  # --- BUNDLE TRUST MANAGER ---
  kubectl create -f trust-manager/bundle.yaml
  sleep 3
  #clear
}

configura_keycloak() {
  echo "Configurando Keycloak..."
  helm upgrade --install keycloak bitnami/keycloak \
    --namespace keycloak --create-namespace \
    -f keycloak/values.yaml
  KEYCLOAK_PASSWORD=$(kubectl -n keycloak get secret keycloak -o jsonpath='{.data.admin-password}' | base64 -d)
  sleep 3
  clear
}

configura_opa() {
  echo "Configurando OPA..."
  #utilizzare opa-kube-mgmt
  sleep 3
  clear
}

configura_minio_operator() {
  echo "Configurando MinIO Operator..."
  helm upgrade --install operator minio-operator/operator \
    --namespace minio-operator --create-namespace \
    -f minio/o-values.yaml
  sleep 3
  clear
}

configura_tenant_minio() {
  kubectl wait --for=condition=Ready pod/keycloak-0 -n keycloak
  kubectl wait --for=condition=Ready pods -n opa
  echo "Configurando il tenant di MinIO..."
  helm upgrade --install myminio minio-operator/tenant \
    --namespace tenant-1 --create-namespace \
    -f minio/t-values.yaml
  sleep 3
  clear
}

terminazione() {
  echo "Pulendo il cluster..."
  kubectl get pods --all-namespaces --field-selector=status.phase=Failed -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name' --no-headers | while read ns name; do
    kubectl delete pod "$name" -n "$ns"
  done
  kubectl get pods --all-namespaces --field-selector=status.phase=Succeeded -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name' --no-headers | while read ns name; do
    kubectl delete pod "$name" -n "$ns"
  done
  echo "Tutte le configurazioni sono state completate con successo!"
  echo "Per accedere a Keycloak, utilizza l'URL: http://keycloak.local"
  echo "Password di Keycloak: $KEYCLOAK_PASSWORD"
  echo "Per accedere a MinIO, utilizza l'URL: http://minio.local"
  echo "Per accedere a OPA, utilizza l'URL: http://opa.local"
}

# Esecuzione sequenziale delle funzioni principali
prerequisiti
inizializzazione
configura_cert_manager
configura_certificati
configura_keycloak
#configura_opa
#configura_minio_operator
#configura_tenant_minio
#terminazione
