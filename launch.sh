#!/bin/bash

echo "=== INIZIO CONFIGURAZIONE CLUSTER KUBERNETES ==="

# =====================================================
# PREREQUISITI - Aggiunge repository Helm e aggiorna
# =====================================================
echo "Configurando repository Helm..."
helm repo add jetstack https://charts.jetstack.io
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add opa-kube-mgmt https://open-policy-agent.github.io/kube-mgmt/charts
helm repo add minio-operator https://operator.min.io
helm repo update
sleep 3

# =====================================================
# INIZIALIZZAZIONE - Avvia Minikube e crea namespace
# =====================================================
echo "Inizializzando Minikube..."
minikube start --driver=docker --cpus=3 --memory=6144
minikube addons enable ingress

echo "Creando namespace necessari..."
for ns in cert-manager keycloak minio-operator opa tenant-1; do
  kubectl create ns $ns --dry-run=client -o yaml | kubectl apply -f -
  kubectl label namespace $ns create-ca-bundle=true --overwrite=true
done
sleep 5

# =====================================================
# CERT-MANAGER - Installa cert-manager e trust-manager
# =====================================================
echo "Configurando Cert-Manager..."
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set crds.enabled=true

helm upgrade --install trust-manager jetstack/trust-manager \
  --namespace cert-manager \
  -f trust-manager/values.yaml

kubectl apply -f tls/selfsigned-root-clusterissuer.yaml
sleep 10

# =====================================================
# CERTIFICATI - Configura tutti i certificati TLS
# =====================================================
echo "Configurando certificati TLS..."

# Crea directory per certificati se non esiste
mkdir -p certs

# --- CERTIFICATI KEYCLOAK ---
echo "Configurando certificati Keycloak..."
kubectl apply -f tls/keycloak/keycloak-ca-certificate.yaml
kubectl apply -f tls/keycloak/keycloak-ca-issuer.yaml
kubectl wait --for=create secret keycloak-ca-tls -n keycloak --timeout=120s
kubectl get secrets -n keycloak keycloak-ca-tls -o jsonpath='{.data.ca\.crt}' | base64 -d > certs/keycloak-ca.crt
kubectl create secret generic keycloak-ca-tls --from-file=certs/keycloak-ca.crt -n cert-manager --dry-run=client -o yaml | kubectl apply -f -

# --- CERTIFICATI OPA ---
echo "Configurando certificati OPA..."
kubectl apply -f tls/opa/opa-ca-certificate.yaml
kubectl apply -f tls/opa/opa-ca-issuer.yaml
kubectl wait --for=create secret opa-ca-tls -n opa --timeout=120s
kubectl get secrets -n opa opa-ca-tls -o jsonpath='{.data.ca\.crt}' | base64 -d > certs/opa-ca.crt
kubectl create secret generic opa-ca-tls --from-file=certs/opa-ca.crt -n cert-manager --dry-run=client -o yaml | kubectl apply -f -

# --- CERTIFICATI MINIO OPERATOR ---
echo "Configurando certificati MinIO Operator..."
kubectl apply -f tls/minio/operator-ca-tls-secret.yaml
kubectl apply -f tls/minio/operator-ca-issuer.yaml
kubectl apply -f tls/minio/sts-tls-certificate.yaml

# --- CERTIFICATI MINIO TENANT ---
echo "Configurando certificati MinIO Tenant..."
kubectl apply -f tls/minio/tenant-1-ca-certificate.yaml
kubectl apply -f tls/minio/tenant-1-ca-issuer.yaml
kubectl apply -f tls/minio/tenant-1-minio-certificate.yaml
kubectl wait --for=create secret tenant-1-ca-tls -n tenant-1 --timeout=120s
kubectl get secrets -n tenant-1 tenant-1-ca-tls -o jsonpath='{.data.ca\.crt}' | base64 -d > certs/minio-ca.crt
kubectl create secret generic tenant-1-ca-tls --from-file=certs/minio-ca.crt -n cert-manager --dry-run=client -o yaml | kubectl apply -f -

# --- ESTRAZIONE E PATCH CERTIFICATI MINIO ---
echo "Processando certificati MinIO..."
mkdir -p ./tmp
kubectl wait --for=create secret myminio-tls -n tenant-1 --timeout=120s
kubectl get secret myminio-tls -n tenant-1 -o jsonpath='{.data.tls\.crt}' | base64 -d > tmp/m_public.crt
kubectl get secret myminio-tls -n tenant-1 -o jsonpath='{.data.tls\.key}' | base64 -d > tmp/m_private.key
kubectl create secret generic myminio-tls-custom --from-file=public.crt=tmp/m_public.crt --from-file=private.key=tmp/m_private.key -n tenant-1 --dry-run=client -o yaml | kubectl apply -f -

kubectl patch secret myminio-tls -n tenant-1 --type='json' -p='[
  {"op": "add", "path": "/data/public.crt", "value":"'"$(cat tmp/m_public.crt | base64 -w 0)"'"},
  {"op": "add", "path": "/data/private.key", "value":"'"$(cat tmp/m_private.key | base64 -w 0)"'"}
]'
rm -rf ./tmp
sleep 30

# --- BUNDLE TRUST MANAGER ---
echo "Configurando Trust Manager Bundle..."
kubectl apply -f trust-manager/bundle.yaml
sleep 30

# =====================================================
# KEYCLOAK - Installa e configura Keycloak
# =====================================================
echo "Installando Keycloak..."
helm upgrade --install keycloak bitnami/keycloak \
  --namespace keycloak --create-namespace \
  -f keycloak/values.yaml

# Salva la password admin di Keycloak
KEYCLOAK_PASSWORD=$(kubectl -n keycloak get secret keycloak -o jsonpath='{.data.admin-password}' | base64 -d 2>/dev/null || echo "Password non ancora disponibile")
sleep 30

# =====================================================
# OPA - Installa Open Policy Agent
# =====================================================
echo "Configurando Open Policy Agent..."

# Applica tutte le policy .rego
if [ -d "opa/policies" ]; then
  for policy in opa/policies/*.rego; do
    if [ -f "$policy" ]; then
      policy_name=$(basename "$policy" .rego)
      echo "Applicando policy: $policy_name"
      kubectl create configmap "$policy_name" --from-file=main="$policy" -n opa --dry-run=client -o yaml | kubectl apply -f -
      kubectl label configmap "$policy_name" openpolicyagent.org/policy=rego -n opa --overwrite
      kubectl wait --for=create configMap $policy_name -n opa --timeout=60s
    fi
  done
fi

kubectl wait --for=create secret opa-opa-kube-mgmt-cert -n opa --timeout=120s
helm upgrade --install opa opa-kube-mgmt/opa-kube-mgmt \
  --namespace opa --create-namespace \
  -f opa/values.yaml

kubectl apply -f opa/ingress.yaml
sleep 30

# =====================================================
# MINIO OPERATOR - Installa l'operatore MinIO
# =====================================================
echo "Installando MinIO Operator..."
helm upgrade --install operator minio-operator/operator \
  --namespace minio-operator --create-namespace \
  -f minio/o-values.yaml
sleep 30

# =====================================================
# MINIO TENANT - Installa il tenant MinIO
# =====================================================
echo "Attendendo che i servizi siano pronti..."
kubectl wait -n keycloak --for=condition=Ready pod/keycloak-0 --timeout=300s
kubectl wait pod -n opa -l app=opa-opa-kube-mgmt --for=condition=Ready --timeout=120s

echo "Installando MinIO Tenant..."
helm upgrade --install myminio minio-operator/tenant \
  --namespace tenant-1 --create-namespace \
  -f minio/t-values.yaml
sleep 30

# =====================================================
# PULIZIA FINALE
# =====================================================
echo "Pulendo il cluster..."

# Rimuove pod falliti
kubectl get pods --all-namespaces --field-selector=status.phase=Failed -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name' --no-headers | while read ns name; do
  if [ ! -z "$ns" ] && [ ! -z "$name" ]; then
    echo "Rimuovendo pod fallito: $name in namespace $ns"
    kubectl delete pod "$name" -n "$ns" --ignore-not-found=true
  fi
done

# Rimuove pod completati
kubectl get pods --all-namespaces --field-selector=status.phase=Succeeded -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name' --no-headers | while read ns name; do
  if [ ! -z "$ns" ] && [ ! -z "$name" ]; then
    echo "Rimuovendo pod completato: $name in namespace $ns"
    kubectl delete pod "$name" -n "$ns" --ignore-not-found=true
  fi
done

# =====================================================
# INFORMAZIONI FINALI
# =====================================================
echo ""
echo "============================================="
echo "   CONFIGURAZIONE COMPLETATA CON SUCCESSO!"
echo "============================================="
echo ""
echo "URLs di accesso:"
echo "• Keycloak: https://keycloak.local"
echo "• MinIO:    https://minio.local"
echo "• OPA:      https://opa.local"
echo ""
echo "Credenziali:"
echo "• Password Keycloak Admin: $KEYCLOAK_PASSWORD"
echo ""
echo "Note:"
echo "• Assicurati di aver configurato /etc/hosts per i domini locali"
echo "• I certificati sono stati salvati nella cartella 'certs/'"
echo ""
echo "Per verificare lo stato dei pod:"
echo "kubectl get pods --all-namespaces"
echo ""