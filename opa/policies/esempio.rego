package httpapi.authz

import input

default allow = false

# Allow the root user to perform any action
allow if{
 input.owner == true
}

# All other users may do anything other than call PutObject
allow if{
 input.action != "s3:PutObject"
 input.owner == false
}