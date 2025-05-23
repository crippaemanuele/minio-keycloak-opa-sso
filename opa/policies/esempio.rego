package httpapi.authz

import input

default allow = false

# Allow the root user to perform any action.
allow {
 input.owner == true
}

# All other users may do anything other than call PutObject
allow {
 input.action != "s3:PutObject"
 input.owner == false
}