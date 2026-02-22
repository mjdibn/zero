package zerotrust

import future.keywords

default allow := false

allow if {
    identity_verified
    device_trusted
    resource_authorized
}

identity_verified if {
    input.user.sub != ""
    input.user.sub != null
    count(input.user.realm_access.roles) > 0
}

device_trusted if {
    input.device.trusted == true
    input.device.compliance_score >= 70
}

resource_authorized if {
    some role in input.user.realm_access.roles
    has_permission(role, input.method, input.path)
}

has_permission(role, method, path) if {
    role_perms := permissions[role]
    some i
    perm := role_perms[i]
    method_match(perm.action, method)
    path_match(perm.resource, path)
}

method_match(allowed, requested) if {
    allowed == "*"
}
method_match(allowed, requested) if {
    allowed == requested
}

path_match(allowed, requested) if {
    allowed == "*"
}
path_match(allowed, requested) if {
    requested[0] == allowed
}
path_match(allowed, requested) if {
    startswith(concat("/", requested), allowed)
}

permissions := {
    "admin": [{"resource": "*", "action": "*"}],
    "manager": [
        {"resource": "api", "action": "GET"},
        {"resource": "reports", "action": "GET"},
        {"resource": "public", "action": "GET"}
    ],
    "user": [
        {"resource": "api", "action": "GET"},
        {"resource": "public", "action": "GET"}
    ],
    "guest": [{"resource": "public", "action": "GET"}]
}
