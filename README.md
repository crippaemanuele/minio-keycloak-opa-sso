### **Garantire la sicurezza di Object Storage in Kubernetes**

Autenticazione e Autorizzazione con Keycloak, Open Policy Agent e MinIO

<br>

**Tesi di Laurea in Ingegneria Informatica**
*Università degli Studi di Bergamo*
*Anno Accademico 2024/2025*

---

#### **Sommario**

Questo lavoro di tesi esplora l'integrazione di servizi open-source in un ambiente cloud-native, focalizzandosi sulla sicurezza di un sistema di object storage. L'obiettivo è stato quello di replicare un sistema di autenticazione e autorizzazione simile a quello di **Amazon S3**, utilizzando esclusivamente tecnologie open-source.

L'infrastruttura, sviluppata in ambiente **Kubernetes** su **Minikube**, si basa sull'integrazione dei seguenti componenti:

* **MinIO**: Utilizzato come servizio di object storage.
* **Keycloak**: Per la gestione centralizzata dell'autenticazione tramite Single Sign-On (SSO).
* **Open Policy Agent (OPA)**: Per la definizione di policy di autorizzazione flessibili e modulari.
* **Helm Charts**: Usato per il deployment dei servizi.
* **cert-manager** e **trust-manager**: Per la gestione dei certificati TLS e delle autorità di certificazione, garantendo comunicazioni sicure.

Il risultato è un sistema sicuro, modulare e scalabile che dimostra la fattibilità di un'infrastruttura di object storage affidabile con strumenti open-source, fornendo un modello di riferimento per contesti di ricerca, sviluppo e produzione.

---

#### **Architettura e Implementazione**

L'architettura della soluzione è stata progettata per separare in modo netto i flussi di autenticazione e autorizzazione:

* **Flusso di autenticazione (AuthN)**: Gestito da Keycloak, che autentica gli utenti e rilascia token per l'accesso.
* **Flusso di autorizzazione (AuthZ)**: Delegato a OPA, che valuta le richieste in base a policy personalizzate scritte in linguaggio Rego e decide se consentire o negare l'accesso alle risorse di MinIO.

Il progetto ha affrontato e risolto diverse problematiche, tra cui la configurazione dei servizi in un ambiente locale privo di domini pubblici, la gestione della persistenza dei dati e l'automazione del caricamento delle policy personalizzate.

---

#### **Come avviare il progetto**

1.  **Clonare il repository:**
    ```bash
    git clone [https://github.com/tuo-utente/tuo-repo.git](https://github.com/tuo-utente/tuo-repo.git)
    cd tuo-repo
    ```
2.  **Configurare Minikube:**
    * Assicurarsi di avere le risorse necessarie (almeno 3 CPU e 6 GB di RAM).
    * Avviare Minikube con il comando appropriato:
        ```bash
        minikube start --driver=docker --cpus=3 --memory=6144
        ```
3.  **Installare e configurare i servizi:**
    * Seguire la documentazione all'interno del repository per installare e configurare i vari componenti utilizzando Helm Charts e i file di configurazione personalizzati.

Per maggiori dettagli sull'implementazione, l'architettura e la risoluzione dei problemi, si rimanda al testo completo della tesi in formato PDF.
