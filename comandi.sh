# --- Inizializzazione ---
# Spostati nella directory del progetto
cd Projects/minio-keycloak-sso/

# Avvia Minikube con il driver Docker e risorse specifiche
minikube start --driver=docker --cpus=3 --memory=6144

# Abilita il componente Ingress in Minikube
minikube addons enable ingress

# Crea i namespace necessari
kubectl create ns cert-manager
kubectl create ns keycloak
kubectl create ns minio-operator
kubectl create ns tenant-1

# --- Cert-Manager ---
# Installa o aggiorna cert-manager con CRD abilitate
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set crds.enabled=true

# Applica il ClusterIssuer self-signed per cert-manager
kubectl apply -f certs/selfsigned-root-clusterissuer.yaml

# --- Keycloak ---
# Configura il certificato CA per Keycloak
kubectl apply -f certs/keycloak/keycloak-ca-certificate.yaml
kubectl apply -f certs/keycloak/keycloak-ca-issuer.yaml

# Configura il certificato TLS per Keycloak
kubectl apply -f certs/keycloak/keycloak-certificate.yaml

# Estrai il certificato CA di Keycloak e salvalo in un file
kubectl get secrets -n keycloak keycloak-ca-tls \
  -o=jsonpath='{.data.ca\.crt}' | base64 -d > keycloak-ca.crt

# Crea un secret per il certificato CA di Keycloak nel namespace del MinIO Operator
kubectl create secret generic operator-ca-tls-keycloak \
  --from-file=keycloak-ca.crt -n minio-operator

#Installa o aggiorna Keycloak con Helm
helm upgrade --install keycloak bitnami/keycloak --namespace keycloak --create-namespace -f keycloak/values.yaml
KEYCLOAK_PASSWORD=$(kubectl -n keycloak get secret keycloak -o jsonpath='{.data.admin-password}' | base64 -d)
echo "Password di Keycloak: $KEYCLOAK_PASSWORD"

# --- MinIO Operator ---
# Configura il certificato CA per il MinIO Operator
kubectl apply -f certs/minio/operator-ca-tls-secret.yaml
kubectl apply -f certs/minio/operator-ca-issuer.yaml

# Configura il certificato TLS per il servizio STS del MinIO Operator
kubectl apply -f certs/minio/sts-tls-certificate.yaml

# Installa o aggiorna il MinIO Operator con Helm
helm upgrade --install operator minio-operator/operator \
  --namespace minio-operator --create-namespace \
  -f minio/o-values.yaml

# --- Tenant di MinIO ---
# Configura il certificato CA per il tenant MinIO
kubectl apply -f certs/minio/tenant-1-ca-certificate.yaml
kubectl apply -f certs/minio/tenant-1-ca-issuer.yaml

# Configura il certificato TLS per il tenant MinIO
kubectl apply -f certs/minio/tenant-1-minio-certificate.yaml

# Estrai il certificato CA del tenant e salvalo in un file
kubectl get secrets -n tenant-1 tenant-1-ca-tls \
  -o=jsonpath='{.data.ca\.crt}' | base64 -d > minio-ca.crt

# Crea un secret per il certificato CA del tenant nel namespace del MinIO Operator
kubectl create secret generic operator-ca-tls-tenant-1 \
  --from-file=minio-ca.crt -n minio-operator

# Configura i certificati TLS per gli ingress di MinIO
kubectl apply -f certs/ingress/minio-api-crt.yaml
kubectl apply -f certs/ingress/minio-console-crt.yaml

# Crea un secret personalizzato per MinIO con i nomi delle chiavi attesi
kubectl create secret generic myminio-tls-custom \
  --from-literal=public.crt="$(kubectl get secret myminio-tls -n tenant-1 -o jsonpath='{.data.tls\.crt}' | base64 -d)" \
  --from-literal=private.key="$(kubectl get secret myminio-tls -n tenant-1 -o jsonpath='{.data.tls\.key}' | base64 -d)" \
  -n tenant-1

# Crea un secret personalizzato per Keycloak con i nomi delle chiavi attesi
kubectl create secret generic keycloak-tls-custom \
  --from-literal=public.crt="$(kubectl get secret keycloak-tls -n keycloak -o jsonpath='{.data.tls\.crt}' | base64 -d)" \
  --from-literal=private.key="$(kubectl get secret keycloak-tls -n keycloak -o jsonpath='{.data.tls\.key}' | base64 -d)" \
  -n tenant-1

# Installa o aggiorna il tenant MinIO con Helm
helm upgrade --install myminio minio-operator/tenant \
  --namespace tenant-1 --create-namespace \
  -f minio/t-values.yaml
