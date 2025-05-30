import requests
import xml.etree.ElementTree as ET
from minio import Minio
from minio.error import S3Error

# Configurazioni e costanti
keycloak_url = "https://keycloak.local/realms/MinIO/protocol/openid-connect/token"
client_id = "minio-client"
client_secret = "UySDgZLFW9GSWjtwVMx4yxEnpMkqD4"
minio_api = "https://minio-api.local/"
arn = "arn:minio:iam:::role/1mAsqpUGox8eewepDQ1dmtwpdY8"

def ottieni_token_oidc(username, password):
    """Richiede un token OIDC da Keycloak usando username e password."""
    data_oidc = {
        "client_id": client_id,
        "client_secret": client_secret,
        "grant_type": "password",
        "username": username,
        "password": password,
        "scope": "openid profile email"
    }
    risposta = requests.post(keycloak_url, data=data_oidc)
    if risposta.status_code == 200:
        return risposta.json().get("access_token")
    else:
        print(f"Errore ottenimento token OIDC: {risposta.status_code} - {risposta.text}")
        return None

def ottieni_credenziali_sts(token_oidc):
    """Richiede le credenziali temporanee STS da MinIO usando il token OIDC."""
    data_sts = {
        "Action": "AssumeRoleWithWebIdentity",
        "Version": "2011-06-15",
        "DurationSeconds": 86000,
        "Token": token_oidc,
        "RoleArn": arn 
    }
    risposta = requests.post(minio_api, data=data_sts)
    if risposta.status_code != 200:
        print(f"Errore ottenimento credenziali STS: {risposta.status_code} - {risposta.text}")
        return None, None, None

    try:
        root = ET.fromstring(risposta.text)
    except ET.ParseError:
        print("Errore: risposta STS non è XML valido")
        print("Risposta:", risposta.text)
        return None, None, None

    namespaces = {'ns': 'https://sts.amazonaws.com/doc/2011-06-15/'}
    access_key_elem = root.find('.//ns:AccessKeyId', namespaces)
    secret_key_elem = root.find('.//ns:SecretAccessKey', namespaces)
    session_token_elem = root.find('.//ns:SessionToken', namespaces)

    if any(elem is None for elem in [access_key_elem, secret_key_elem, session_token_elem]):
        print("Errore: mancano alcune credenziali nella risposta XML.")
        print("Risposta:", risposta.text)
        return None, None, None

    return access_key_elem.text, secret_key_elem.text, session_token_elem.text

def main():
    print("Benvenuto nel client MinIO con autenticazione OIDC")

    # Input username e password
    username = input("Inserisci il tuo username: ")
    password = input("Inserisci la tua password: ")

    # Ottieni token OIDC
    token_oidc = ottieni_token_oidc(username, password)
    if not token_oidc:
        print("Impossibile ottenere il token OIDC. Esco.")
        return

    print("Token OIDC ottenuto con successo.")

    # Ottieni credenziali STS temporanee
    access_key, secret_key, session_token = ottieni_credenziali_sts(token_oidc)
    if not all([access_key, secret_key, session_token]):
        print("Impossibile ottenere le credenziali STS. Esco.")
        return

    print("Credenziali STS ottenute con successo.")

    # Inizializza client MinIO con le credenziali temporanee
    client = Minio(
        "minio-api.local",
        access_key=access_key,
        secret_key=secret_key,
        session_token=session_token,
        secure=True
    )

    # Loop del menu interattivo
    while True:
        print("\nMenu:")
        print("1. Elenca i bucket")
        print("2. Crea un nuovo bucket")
        print("3. Elimina un bucket")
        print("4. Elenca contenuto di un bucket")
        print("5. Carica file nel bucket")
        print("6. Scarica file dal bucket")
        print("0. Esci")

        try:
            scelta = int(input("Scegli un'opzione: "))
        except ValueError:
            print("Inserisci un numero valido.")
            continue

        if scelta == 0:
            print("Uscita in corso...")
            break

        try:
            match scelta:
                case 1:
                    # Elenca tutti i bucket disponibili
                    buckets = client.list_buckets()
                    print("Bucket disponibili:")
                    for bucket in buckets:
                        print(f"- {bucket.name}")
                case 2:
                    # Crea un nuovo bucket
                    bucket_name = input("Inserisci il nome del nuovo bucket: ")
                    client.make_bucket(bucket_name)
                    print(f"Bucket '{bucket_name}' creato con successo.")
                case 3:
                    # Elimina un bucket esistente
                    bucket_name = input("Inserisci il nome del bucket da eliminare: ")
                    client.remove_bucket(bucket_name)
                    print(f"Bucket '{bucket_name}' eliminato con successo.")
                case 4:
                    # Elenca contenuto di un bucket
                    bucket_name = input("Inserisci il nome del bucket da cui caricare il file: ")
                    objects = client.list_objects(bucket_name)
                    print(f"Contenuto del bucket '{bucket_name}':")
                    for obj in objects:
                        print(f"- {obj.object_name} (Size: {obj.size} bytes, Last Modified: {obj.last_modified})")
                case 5:
                    # Carica un file in un bucket
                    bucket_name = input("Inserisci il nome del bucket in cui caricare il file: ")
                    file_path = input("Inserisci il percorso del file da caricare: ")
                    object_name = file_path.split('/')[-1]  # Nome file senza percorso
                    client.fput_object(bucket_name, object_name, file_path)
                    print(f"File '{file_path}' caricato con successo nel bucket '{bucket_name}'.")
                case 6:
                    # Scarica un file da un bucket
                    bucket_name = input("Inserisci il nome del bucket da cui scaricare il file: ")
                    file_name = input("Inserisci il nome del file da scaricare: ")
                    client.fget_object(bucket_name, file_name, "clinica/"+file_name)
                    print(f"File '{file_name}' scaricato con successo dal bucket '{bucket_name}'.")
                case _:
                    print("Opzione non valida. Riprova.")
        except S3Error as e:
            print("Errore durante l'operazione:", e)

if __name__ == "__main__":
    main()
