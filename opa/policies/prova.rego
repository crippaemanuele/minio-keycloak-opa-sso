package httpapi.authz

default allow := false

# Consentito se amministratore con tutte le azioni
allow if {
    is_amministratore
}

# Consentito se medico e non cancella bucket
allow if {
    is_medico
    input.input.action != "s3:DeleteBucket"
}

# Consentito se segretario e solo in lettura
allow if {
    is_segreteria
    input.input.action in read_only_actions
}

# Consentito se paziente e il documento è intestato a lui
allow if {
    is_paziente
    input.input.action in read_only_actions
    document_intestato_all_utente
}

# Account di servizio MinIO
allow if {
    input.input.account == "minio"
}

# Helper per controllare il gruppo
is_amministratore if {
    "amministratori" in input.input.claims.policy
}

is_medico if {
    "medici" in input.input.claims.policy
}

is_segreteria if {
    "segreteria" in input.input.claims.policy
}

is_paziente if {
    "pazienti" in input.input.claims.policy
}

# Controlla se l'oggetto contiene il nome dell'utente (MIGLIORATA)
document_intestato_all_utente if {
    family_name := lower(input.input.claims.family_name)
    given_name := lower(input.input.claims.given_name)
    object_name := lower(input.input.object)
    
    # Verifica diverse combinazioni nome-cognome
    contains(object_name, sprintf("%s_%s", [family_name, given_name]))
}

document_intestato_all_utente if {
    family_name := lower(input.input.claims.family_name)
    given_name := lower(input.input.claims.given_name)
    object_name := lower(input.input.object)
    
    # Verifica anche cognome-nome
    contains(object_name, sprintf("%s_%s", [given_name, family_name]))
}

# Lista completa delle azioni S3 di sola lettura
read_only_actions := {
    # Listing generale
    "s3:ListAllMyBuckets",
    "s3:GetService",
    
    # Bucket operations (read)
    "s3:ListBucket",
    "s3:ListBucketVersions",
    "s3:ListBucketMultipartUploads",
    "s3:GetBucketLocation",
    "s3:GetBucketVersioning",
    "s3:GetBucketAcl",
    "s3:GetBucketCORS",
    "s3:GetBucketPolicy",
    "s3:GetBucketLogging",
    "s3:GetBucketNotification",
    "s3:GetBucketTagging",
    "s3:GetBucketWebsite",
    "s3:GetBucketInventory",
    "s3:GetBucketMetrics",
    "s3:GetBucketAnalytics",
    "s3:GetBucketAccelerateConfiguration",
    "s3:GetBucketRequestPayment",
    "s3:GetBucketReplication",
    "s3:GetBucketEncryption",
    "s3:GetBucketLifecycleConfiguration",
    "s3:HeadBucket",
    
    # Object operations (read)
    "s3:GetObject",
    "s3:GetObjectVersion",
    "s3:GetObjectAcl",
    "s3:GetObjectVersionAcl",
    "s3:GetObjectTagging",
    "s3:GetObjectVersionTagging",
    "s3:GetObjectTorrent",
    "s3:GetObjectRetention",
    "s3:GetObjectLegalHold",
    "s3:HeadObject",
    
    # Multipart operations (read)
    "s3:ListMultipartUploadParts",
    
    # Query operations
    "s3:SelectObjectContent",
}