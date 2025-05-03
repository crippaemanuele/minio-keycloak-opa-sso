# MinIO + Keycloak SSO su Kubernetes

> Questo progetto fa parte della mia tesi e si propone di configurare un ambiente Kubernetes locale che integra MinIO e Keycloak tramite SSO (Single Sign-On) utilizzando OIDC (OpenID Connect). L'obiettivo è implementare un'infrastruttura sicura e scalabile, con certificati TLS gestiti tramite `cert-manager` e ingress gestiti da NGINX.

---

## 🗂 Struttura del progetto

```
.
├── certs/                  # Certificati TLS gestiti da cert-manager
├── config/                 # Configurazioni custom (es. tenant MinIO)
├── keycloak/               # Configurazioni Helm e realm per Keycloak
├── minio/                  # Configurazioni Helm per MinIO
├── nginx/                  # Configurazioni degli ingress NGINX
├── keycloakaccessvalues.yaml  # Configurazione per l'accesso OIDC tra MinIO e Keycloak
├── mc.exe                  # MinIO Client (per Windows)
```

---

## 🎓 Obiettivo del progetto

L'obiettivo principale del progetto è studiare e implementare un'integrazione tra MinIO e Keycloak per gestire l'autenticazione centralizzata tramite OIDC. Questo include:

- Configurazione di un ambiente Kubernetes locale per test e sviluppo.
- Utilizzo di `cert-manager` per la gestione automatica dei certificati TLS.
- Configurazione di ingress NGINX per l'accesso sicuro ai servizi.
- Implementazione di un flusso SSO tra MinIO e Keycloak.
- Gestione delle policy di accesso ai bucket tramite il claim `policy` nei token OIDC.
- Esplorazione delle funzionalità multi-tenant di MinIO.

---

## 🚀 Deployment (ordine consigliato)

1. **Installazione di cert-manager e ClusterIssuer**

   ```bash
   kubectl apply -f certs/selfsigned-issuer.yaml
   ```

2. **Creazione dei certificati TLS**

   ```bash
   kubectl apply -f certs/keycloak-certificate.yaml
   kubectl apply -f certs/minio-api-certificate.yaml
   kubectl apply -f certs/minio-console-certificate.yaml
   ```

3. **Deploy di Keycloak**

   ```bash
   helm install keycloak oci://registry-1.docker.io/bitnamicharts/keycloak \
     -n keycloak --create-namespace \
     -f keycloak/values.yaml
   ```

   > Dopo il deploy, importa il realm configurato:
   ```bash
   kubectl cp keycloak/minio-realm-export.json keycloak/keycloak-0:/tmp
   ```

4. **Deploy di MinIO**

   ```bash
   helm install minio oci://registry-1.docker.io/bitnamicharts/minio \
     -n minio --create-namespace \
     -f minio/values.yaml
   ```

5. **Ingress per la console MinIO**

   ```bash
   kubectl apply -f nginx/console-ingress.yaml
   ```

---

## 🌐 Domini utilizzati (modifica `/etc/hosts` se in locale)

```
127.0.0.1 keycloak.local minio-api.local minio-console.local
```

---

## 🔐 Certificati Self-Signed

> In ambienti locali vengono utilizzati certificati self-signed generati tramite `cert-manager`. Questi certificati non sono adatti per ambienti di produzione, ma sono utili per testare TLS e ingress.

---

## 🛠 Strumenti utili

- `mc.exe`: MinIO Client (per Windows)
- `kubectl`, `helm`, `minikube` o un cluster Kubernetes a scelta
- `cert-manager` installato nel cluster

---

## 📌 Note

- **`keycloakaccessvalues.yaml`**: Definisce le variabili per l'accesso OIDC tra MinIO e Keycloak.
- **`minio/values.yaml`**: Configurazione per il tenant MinIO, inclusa l'autenticazione OIDC e le policy basate sul claim `policy`.
- **`keycloak/values.yaml`**: Configurazione per il deploy di Keycloak e il realm associato.

---

## ✅ TODO / Miglioramenti futuri

- Automatizzare la configurazione iniziale con script o Helmfile.
- Utilizzare certificati validi con DNS pubblico per ambienti di produzione.
- Documentare in dettaglio il flusso SSO tra MinIO e Keycloak.
- Testare l'integrazione in un ambiente di produzione simulato.
- Aggiungere supporto per ulteriori funzionalità multi-tenant di MinIO.

---

## 📖 Riferimenti

- [MinIO Documentation](https://min.io/docs/minio)
- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [cert-manager Documentation](https://cert-manager.io/docs/)