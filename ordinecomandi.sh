#Inizializzazione del progetto
cd Projects/minio-keycloak-sso/
minikube start --driver=docker --cpus=3 --memory=6gb
minikube addons enable ingress
kubectl create namespace keycloak
kubectl create namespace minio-tenant
#Inizializzazione cert-manager
helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --set crds.enabled=true
kubectl apply -f certs/cluster-issuer.yaml
kubectl apply -f certs/keycloak/keycloak-certificate.yaml
#Installazione di Keycloak
helm upgrade --install keycloak bitnami/keycloak -n keycloak -f keycloak/origin.yaml
    #Password di accesso a Keycloak
    kubectl -n keycloak get secret keycloak -o jsonpath='{.data.admin-password}' | base64 -d && echo
#Installazione di Minio
helm upgrade --install --namespace minio-operator --create-namespace operator minio-operator/operator
helm upgrade --install minio minio-operator/tenant --namespace minio-tenant --create-namespace -f old/t-values.yaml