import getpass
import json
import subprocess
import requests
import xml.etree.ElementTree as ET

# 🔧 Configura parametri
KEYCLOAK_TOKEN_URL = "https://keycloak.local/auth/realms/MinIO/protocol/openid-connect/token"
MINIO_STS_URL = "https://minio-api.local"
CLIENT_ID = "minio-client"
CLIENT_SECRET = "UySDgZLFW9GSWjtwVMx4yxEnpMkqD4"

# 🧑 Input utente
username = input("👤 Nome utente: ")
password = getpass.getpass("🔒 Password: ")

# 🪙 Richiesta token OIDC a Keycloak
print("🔑 Ottenimento access token da Keycloak...")
response = requests.post(
    KEYCLOAK_TOKEN_URL,
    data={
        "grant_type": "password",
        "client_id": CLIENT_ID,
        "client_secret": CLIENT_SECRET,
        "username": username,
        "password": password
    },
    headers={"Content-Type": "application/x-www-form-urlencoded"},
    verify=False  # accetta cert self-signed
)

if response.status_code != 200:
    print("❌ Errore autenticazione Keycloak:", response.text)
    exit(1)

access_token = response.json()["access_token"]

# 📩 Richiesta credenziali STS da MinIO
print("📩 Richiesta credenziali temporanee da MinIO...")
sts_response = requests.post(
    MINIO_STS_URL,
    data={
        "Action": "AssumeRoleWithWebIdentity",
        "Version": "2011-06-15",
        "WebIdentityToken": access_token
    },
    verify=False  # accetta cert self-signed
)

if sts_response.status_code != 200:
    print("❌ Errore richiesta STS MinIO:", sts_response.text)
    exit(1)

# 🧩 Parsing XML
root = ET.fromstring(sts_response.text)
ns = {"sts": "https://sts.amazonaws.com/doc/2011-06-15/"}

access_key = root.find(".//AccessKeyId").text
secret_key = root.find(".//SecretAccessKey").text
session_token = root.find(".//SessionToken").text

# 🎯 Configura alias autenticato su mc
print("🛠️ Configuro alias OIDC in mc...")
try:
    subprocess.run([
        "mc", "alias", "set", "minio_keycloak",
        MINIO_STS_URL, access_key, secret_key,
        "--api", "S3v4",
        "--session-token", session_token
    ], check=True)
    print("✅ Alias 'minio_keycloak' configurato con successo!")
except subprocess.CalledProcessError as e:
    print("❌ Errore durante la configurazione alias mc:", e)
    exit(1)
