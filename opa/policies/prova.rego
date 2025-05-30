package httpapi.authz

import base64url
import json

default allow := false

allow if {
    is_amministratore
}

allow if {
    is_medico
    input.input.action != "s3:DeleteBucket"
}

allow if {
    is_segreteria
    input.input.action == "s3:GetObject"
}

allow if {
    is_paziente
    input.input.action == "s3:GetObject"
    document_intestato_all_utente
}

allow if {
    input.input.account == "minio"
}

# Funzione helper per estrarre e decodificare il payload JWT
jwt_payload := payload if {
    token := input.input.conditions["X-Amz-Security-Token"][0]
    parts := split(token, ".")
    # La seconda parte è il payload base64url
    payload_b64 := parts[1]
    payload_json := base64url.decode(payload_b64)
    payload := json.unmarshal(payload_json)
}

# Controllo se una data policy è presente nel token JWT o nei claims o in input.policy
has_policy(p) if {
    # Verifica in jwt_payload.policy (se esiste)
    jwt_payload.policy[_] == p
} else if {
    input.input.claims.policy == p
} else if {
    p in input.policy
} else if {
    input.input.condition.policy == p
}

# Regole di ruolo

is_amministratore if {
    has_policy("amministratori") 
} else if {
    has_policy("consoleAdmin")
}

is_medico if {
    has_policy("medici")
}

is_segreteria if {
    has_policy("segreteria")
}

is_paziente if {
    has_policy("pazienti")
}

document_intestato_all_utente if {
    cognome := lower(input.input.claims.family_name)
    nome := lower(input.input.claims.given_name)
    full_name := sprintf("%s %s", [cognome, nome])
    contains(lower(input.input.object), full_name)
}
