package httpapi.authz

default allow = false

# Questo serve solo a loggare l'input
trace_input {
  debug("INPUT RICEVUTO: ", input)
}

# Esegui il trace (non fa nulla in logica, solo logging)
_ = trace_input


# Consentito se medico
allow if {
	is_amministratore
}

allow if {
	is_medico
	input.action == "s3:GetObject"
}

allow if {
	is_medico
	input.action == "s3:PutObject"
}

# Consentito se segretario e solo in lettura
allow if {
	is_segreteria
	input.action == "s3:GetObject"
}

# Consentito se paziente e il documento è intestato a lui
allow if {
	is_paziente
	input.action == "s3:GetObject"
	document_intestato_all_utente
}

allow if {
    input.account == "minio"
}

# Helper per controllare il gruppo
is_amministratore if {
    input.claims.policy == "consoleAdmin"
}

is_medico if {
    input.claims.policy == "medici"
}

is_segreteria if {
    input.claims.policy == "segreteria"
}

is_paziente if {
    input.claims.policy == "pazienti"
}

# Controlla se l'oggetto contiene il nome dell'utente
document_intestato_all_utente if {
	cognome_nome := lower(replace(input.claims.family_name, "_",input.claims.given_name))
	contains(lower(input.object), cognome_nome)
}
