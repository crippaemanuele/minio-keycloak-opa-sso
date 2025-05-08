#Inizializzazione del progetto
cd Projects/minio-keycloak-sso/
minikube start --driver=docker --cpus=3 --memory=6gb
minikube addons enable ingress
kubectl create namespace keycloak
kubectl create namespace minio-tenant
#Inizializzazione cert-manager
helm upgrade --install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --set crds.enabled=true
#Creazione del cluster issuer e dei certificati
kubectl apply -f certs/cluster-issuer.yaml
kubectl apply -f certs/keycloak/keycloak-certificate.yaml
kubectl apply -f certs/minio/minio-api-crt.yaml
kubectl apply -f certs/minio/minio-console-crt.yaml
#Installazione di Keycloak
#kubectl create configmap keycloak-realm-config --from-file=realm-export.json=/home/lelec/Projects/minio-keycloak-sso/keycloak/realm-export.json -n keycloak
helm upgrade --install keycloak bitnami/keycloak -n keycloak -f keycloak/values.yaml
KEYCLOAK_PASSWORD=$(kubectl -n keycloak get secret keycloak -o jsonpath='{.data.admin-password}' | base64 -d)
echo $KEYCLOAK_PASSWORD
#Installazione di Minio
helm upgrade --install --namespace minio-operator --create-namespace operator minio-operator/operator
helm upgrade --install minio minio-operator/tenant --namespace minio-tenant --create-namespace -f minio/values.yaml