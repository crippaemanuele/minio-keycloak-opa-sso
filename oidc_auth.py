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
    access_key = root.find('.//AccessKeyId').text
    secret_key = root.find('.//SecretAccessKey').text
    session_token = root.find('.//SessionToken').text
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
