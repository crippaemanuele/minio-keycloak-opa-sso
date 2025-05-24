package minio.authz

default allow = false

# Consentito se medico
allow {
  is_medico
  input.request.action == "s3:GetObject"
}

allow {
  is_medico
  input.request.action == "s3:PutObject"
}

# Consentito se segretario e solo in lettura
allow {
  is_segreteria
  input.request.action == "s3:GetObject"
}

# Consentito se paziente e il documento è intestato a lui
allow {
  is_paziente
  input.request.action == "s3:GetObject"
  document_intestato_all_utente
}

# Helper per controllare il gruppo
is_medico {
  input.request.groups[_] == "medici"
}

is_segreteria {
  input.request.groups[_] == "segreteria"
}

is_paziente {
  input.request.groups[_] == "pazienti"
}

# Controlla se l'oggetto contiene il nome dell'utente
document_intestato_all_utente {
  # Split dell'oggetto per analizzarlo
  nome_cognome := lower(replace(input.request.user, " ", "_"))
  contains(lower(input.request.object), nome_cognome)
}