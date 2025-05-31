package httpapi.authz

default allow := false

# Consentito se medico
allow if {
	is_amministratore
}

allow if {
	is_medico
	input.input.action == "s3:GetObject"
}

allow if {
	is_medico
	input.input.action == "s3:PutObject"
}

# Consentito se segretario e solo in lettura
allow if {
	is_segreteria
	input.input.action == "s3:GetObject"
}

# Consentito se paziente e il documento è intestato a lui
allow if {
	is_paziente
	input.input.action == "s3:GetObject"
	document_intestato_all_utente
}

allow if {
	input.input.account == "minio"
}

# Helper per controllare il gruppo
is_amministratore if {
    input.input.claims.policy == "amministratore"
}

is_medico if {
	input.input.claims.policy == "medici"
}

is_segreteria if {
	input.input.claims.policy == "segreteria"
}

is_paziente if {
	input.input.claims.policy == "pazienti"
}

# Controlla se l'oggetto contiene il nome dell'utente
document_intestato_all_utente if {
	cognome_nome := lower(replace(input.input.claims.family_name, "_", input.input.claims.given_name))
	contains(lower(input.input.object), cognome_nome)
}