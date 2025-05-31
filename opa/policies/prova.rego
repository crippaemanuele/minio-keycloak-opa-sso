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

is_medico if {
	input.input.claims.policy == "medici"
}

is_segreteria if {
	input.input.claims.policy == "segreteria"
}

is_segreteria if {
	"segreteria" in input.input.claims.policy
}

is_paziente if {
	input.input.claims.policy == "pazienti"
}

is_paziente if {
	"pazienti" in input.input.claims.policy
}

# Controlla se l'oggetto contiene il nome dell'utente
document_intestato_all_utente if {
	cognome_nome := lower(replace(input.input.claims.family_name, "_", input.input.claims.given_name))
	contains(lower(input.input.object), cognome_nome)
}

# Lista delle azioni S3 consentite in sola lettura
read_only_actions := {
	"s3:ListBucket",
	"s3:GetBucketLocation",
	"s3:GetBucketPolicy",
	"s3:GetBucketAcl",
	"s3:GetBucketCORS",
	"s3:GetBucketLogging",
	"s3:GetBucketVersioning",
	"s3:GetBucketWebsite",
	"s3:GetBucketNotification",
	"s3:GetBucketTagging",
	"s3:GetObject",
	"s3:GetObjectAcl",
	"s3:GetObjectTagging",
	"s3:GetObjectVersion",
	"s3:GetObjectVersionAcl",
	"s3:GetObjectVersionTagging",
	"s3:ListMultipartUploadParts",
	"s3:ListBucketVersions",
	"s3:ListBucketMultipartUploads",
}
