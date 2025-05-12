cd Projects/minio-keycloak-sso/
minikube start --driver=docker --cpus=3 --memory=6144
minikube addons enable ingress
helm upgrade --install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --set crds.enabled=true  # Installa o aggiorna cert-manager con CRD abilitate
kubectl apply -f certs/selfsigned-root-clusterissuer.yaml
kubectl create ns minio-operator
kubectl apply -f certs/operator-ca-tls-secret.yaml
kubectl apply -f certs/operator-ca-issuer.yaml
kubectl apply -f certs/sts-tls-certificate.yaml
helm upgrade --install operator minio-operator/operator --namespace minio-operator --create-namespace -f minio/o-values.yaml
kubectl create ns tenant-1
kubectl apply -f certs/tenant-1-ca-certificate.yaml
kubectl apply -f certs/tenant-1-ca-issuer.yaml
kubectl apply -f certs/tenant-1-minio-certificate.yaml
kubectl get secrets -n tenant-1 tenant-1-ca-tls -o=jsonpath='{.data.ca\.crt}' | base64 -d > ca.crt
kubectl create secret generic operator-ca-tls-tenant-1 --from-file=ca.crt -n minio-operator
kubectl apply -f certs/minio-api-crt.yaml
kubectl apply -f certs/minio-console-crt.yaml
kubectl create secret generic myminio-tls-custom --from-literal=public.crt="$(kubectl get secret myminio-tls -n tenant-1 -o jsonpath='{.data.tls\.crt}' | base64 -d)" --from-literal=private.key="$(kubectl get secret myminio-tls -n tenant-1 -o jsonpath='{.data.tls\.key}' | base64 -d)" -n tenant-1
helm upgrade --install myminio minio-operator/tenant --namespace tenant-1 --create-namespace -f minio/t-values.yaml 
