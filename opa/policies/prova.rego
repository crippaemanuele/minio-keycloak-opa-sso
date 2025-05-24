package minio.authz

default allow := false

# Consentito se medico
allow if {
	is_amministratore
}

allow if {
	is_medico
	input.request.action == "s3:GetObject"
}

allow if {
	is_medico
	input.request.action == "s3:PutObject"
}

# Consentito se segretario e solo in lettura
allow if {
	is_segreteria
	input.request.action == "s3:GetObject"
}

# Consentito se paziente e il documento è intestato a lui
allow if {
	is_paziente
	input.request.action == "s3:GetObject"
	document_intestato_all_utente
}

# Helper per controllare il gruppo
is_amministratore if {
	"amministratori" in input.request.groups
}

is_medico if {
	"medici" in input.request.groups
}

is_segreteria if {
	"segreteria" in input.request.groups
}

is_paziente if {
	"pazienti" in input.request.groups
}

# Controlla se l'oggetto contiene il nome dell'utente
document_intestato_all_utente if {
	nome_cognome := lower(replace(input.request.user, " ", "_"))
	contains(lower(input.request.object), nome_cognome)
}
