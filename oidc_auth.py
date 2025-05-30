import requests
import json
import xml.etree.ElementTree as ET
from minio import Minio
from minio.error import S3Error

keycloak_url = "https://keycloak.local/realms/MinIO/protocol/openid-connect/token"
client_id = "minio-client"
client_secret = "UySDgZLFW9GSWjtwVMx4yxEnpMkqD4"
minio_api = "https://minio-api.local/"
arn = "arn:minio:iam:::role/1mAsqpUGox8eewepDQ1dmtwpdY8"
scelta=-1
username = input("Enter your username: ")
password = input("Enter your password: ")
data_oidc = {
    "client_id": client_id,
    "client_secret": client_secret,
    "grant_type": "password",
    "username": username,
    "password": password,
    "scope": "openid profile email"
}
# Richiesta token OIDC per l'utente
richiesta = requests.post(keycloak_url, data=data_oidc)
if richiesta.status_code == 200:
    token_oidc = richiesta.json().get("access_token") # Ottieni il token OIDC
    print("Token OIDC ottenuto con successo.")
else:
    print("Errore durante l'ottenimento del token OIDC:", richiesta.status_code, richiesta.text)
    exit(1)
# Richiesta credenziali STS temporanee
data_sts={
    "Action": "AssumeRoleWithWebIdentity",
    "Version": "2011-06-15",
    "DurationSeconds": 86000,
    "Token": token_oidc,
    "RoleArn": arn 
}
richiesta = requests.post(minio_api, data=data_sts)

if richiesta.status_code == 200:
    # Parsing della risposta XML per ottenere le credenziali temporanee
    root = ET.fromstring(richiesta.text)
    access_key = root.find('.//AccessKeyId')
    secret_key = root.find('.//SecretAccessKey')
    session_token = root.find('.//SessionToken')
    print("Credenziali STS ottenute con successo.")
else:
    print("Errore durante l'ottenimento delle credenziali STS:", richiesta.status_code, richiesta.text)
    exit(1)
# Inizializzazione del client MinIO con le credenziali STS
client = Minio(
    "minio-api.local",
    access_key=access_key,
    secret_key=secret_key,
    session_token=session_token,
    secure=True
)
while scelta == -1 or scelta <= 0 or scelta > 6:
    print("1. Elenca i bucket")
    print("2. Crea un nuovo bucket")
    print("3. Elimina un bucket")
    print("4. Carica file nel bucket")
    print("5. Scarica file dal bucket")
    print("0. Esci")
    scelta = int(input("Scegli un'opzione: "))
    match scelta:
        case 1:
            #Elenca bucket
            try:
                buckets = client.list_buckets()
                print("Bucket disponibili:")
                for bucket in buckets:
                    print(bucket.name)
            except S3Error as e:
                print("Errore durante l'elenco dei bucket:", e)
        case 2:
            #Crea bucket
            bucket_name = input("Inserisci il nome del nuovo bucket: ")
            try:
                client.make_bucket(bucket_name)
                print(f"Bucket '{bucket_name}' creato con successo.")
            except S3Error as e:
                print("Errore durante la creazione del bucket:", e)
        case 3: 
            #Elimina bucket
            bucket_name = input("Inserisci il nome del bucket da eliminare: ")
            try:
                client.remove_bucket(bucket_name)
                print(f"Bucket '{bucket_name}' eliminato con successo.")
            except S3Error as e:
                print("Errore durante l'eliminazione del bucket:", e)
        case 4:
            #Carica file
            bucket_name = input("Inserisci il nome del bucket in cui caricare il file: ")
            file_path = input("Inserisci il percorso del file da caricare: ")
            try:
                client.fput_object(bucket_name, file_path.split('/')[-1], file_path)
                print(f"File '{file_path}' caricato con successo nel bucket '{bucket_name}'.")
            except S3Error as e:
                print("Errore durante il caricamento del file:", e)
        case 5:
            #Scarica file
            bucket_name = input("Inserisci il nome del bucket da cui scaricare il file: ")
            file_name = input("Inserisci il nome del file da scaricare: ")
            try:
                client.fget_object(bucket_name, file_name, file_name)
                print(f"File '{file_name}' scaricato con successo dal bucket '{bucket_name}'.")
            except S3Error as e:
                print("Errore durante il download del file:", e)
        case 0:
            print("Uscita in corso...")
            exit(0)
        case _:
            print("Opzione non valida. Riprova.")
            scelta = -1