# MinIO + Keycloak SSO su Kubernetes

> Questo progetto fa parte della mia tesi e si propone di configurare un ambiente Kubernetes locale che integra MinIO e Keycloak tramite SSO (Single Sign-On) utilizzando OIDC (OpenID Connect). L'obiettivo è esplorare e implementare un'infrastruttura sicura e scalabile, con certificati TLS gestiti tramite `cert-manager` e ingress gestiti da NGINX.

---

## 🗂 Struttura del progetto

```
.
├── certs/                  # Certificati TLS generati da cert-manager
├── config/                 # Configurazioni custom (es. tenant)
├── keycloak/               # Valori Helm, export realm e override Keycloak
├── minio/                  # Valori Helm per MinIO
├── nginx/                  # Ingress per la console MinIO
├── keycloakaccessvalues.yaml  # Configurazione di accesso tra MinIO e Keycloak
├── mc.exe                  # MinIO Client (per Windows)
```

---

## 🎓 Obiettivo del progetto di tesi

L'obiettivo principale del progetto è studiare e implementare un'integrazione tra MinIO e Keycloak per gestire l'autenticazione centralizzata tramite OIDC. Questo include:

- Configurazione di un ambiente Kubernetes locale per test e sviluppo.
- Utilizzo di `cert-manager` per la gestione automatica dei certificati TLS.
- Configurazione di ingress NGINX per l'accesso sicuro ai servizi.
- Implementazione di un flusso SSO tra MinIO e Keycloak.
- Esplorazione delle funzionalità multi-tenant di MinIO.

---

## 🚀 Deployment (ordine consigliato)

1. **Cert-manager e issuer self-signed**

   ```bash
   kubectl apply -f certs/selfsigned-issuer.yaml
   ```

2. **Certificati TLS**

   ```bash
   kubectl apply -f certs/keycloak-certificate.yaml
   kubectl apply -f certs/minio-certificate.yaml
   kubectl apply -f certs/minio-console-certificate.yaml
   ```

3. **Keycloak**

   ```bash
   helm install keycloak oci://registry-1.docker.io/bitnamicharts/keycloak \
     -n keycloak --create-namespace \
     -f keycloak/k-values.yaml
   ```

   > Dopo il deploy, importa il realm:
   ```bash
   kubectl cp keycloak/minio-realm-export.json keycloak/keycloak-0:/tmp
   ```

4. **MinIO**

   ```bash
   helm install minio oci://registry-1.docker.io/bitnamicharts/minio \
     -n minio --create-namespace \
     -f minio/t-values.yaml
   ```

5. **Ingress per la console**

   ```bash
   kubectl apply -f nginx/console-ingress.yaml
   ```

---

## 🌐 Domini utilizzati (modifica `/etc/hosts` se in locale)

```
127.0.0.1 keycloak.local minio.local minio-console.local
```

---

## 🔐 Certificati Self-Signed

> In ambienti locali vengono generati certificati self-signed tramite `cert-manager`. Non adatti a produzione, ma utili per testare TLS/Ingress.

---

## 🛠 Tools utili

- `mc.exe`: MinIO Client (per Windows)
- `kubectl`, `helm`, `minikube` o cluster a scelta
- `cert-manager` installato nel cluster

---

## 📌 Note

- `keycloakaccessvalues.yaml`: definisce le variabili per accesso SSO da MinIO
- `tenant.yaml`: configurazione (custom?) per MinIO multi-tenant

---

## ✅ TODO / miglioramenti futuri

- Aggiungere script di bootstrap
- Usare certificati validi con DNS pubblico
- Automazione con Makefile o Helmfile
- Documentare il flusso SSO tra MinIO e Keycloak
- Testare l'integrazione in un ambiente di produzione simulato