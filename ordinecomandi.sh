#Inizializzazione del progetto
cd Projects/minio-keycloak-sso/
minikube start --driver=docker --cpus=8 --memory=6gb
minikube addons enable ingress
kubectl create namespace keycloak
kubectl create namespace minio-tenant
#Inizializzazione cert-manager
helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --set crds.enabled=true
kubectl apply -f certs/cluster-issuer.yaml
kubectl apply -f certs/keycloak/keycloak-certificate.yaml
#Installazione di Keycloak
helm upgrade --install keycloak bitnami/keycloak -n keycloak -f keycloak/origin.yaml
