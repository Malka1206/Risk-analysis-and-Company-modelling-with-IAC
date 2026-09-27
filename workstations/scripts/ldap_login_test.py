"""
BioLab Analytics - workstation LDAP login check.

Run once at container startup by every workstation (admin, technicien,
biologiste, bioinfo, it). Performs a REAL LDAP bind with the credentials
assigned to that workstation -- there is no unauthenticated path (see
ldap/bootstrap/02-disable-anonymous-bind.ldif): if LDAP_UID/LDAP_PASSWORD
are wrong, the container refuses to consider itself "logged in" and the
workstation is meant to be treated as unusable until fixed.
"""

import os
import sys

from ldap3 import ALL, Connection, Server

LDAP_HOST = os.environ.get("LDAP_HOST", "ldap")
LDAP_BASE_DN = os.environ.get("LDAP_BASE_DN", "dc=biolab-analytics,dc=local")
LDAP_UID = os.environ.get("LDAP_UID")
LDAP_PASSWORD = os.environ.get("LDAP_PASSWORD")
WORKSTATION_ROLE = os.environ.get("WORKSTATION_ROLE", "unknown")


def main() -> int:
    if not LDAP_UID or not LDAP_PASSWORD:
        print("[workstation] LDAP_UID / LDAP_PASSWORD not set", file=sys.stderr)
        return 1

    user_dn = f"uid={LDAP_UID},ou=people,{LDAP_BASE_DN}"
    server = Server(LDAP_HOST, get_info=ALL)
    try:
        conn = Connection(server, user=user_dn, password=LDAP_PASSWORD, auto_bind=True)
        conn.unbind()
    except Exception as exc:
        print(f"[workstation:{WORKSTATION_ROLE}] LDAP bind FAILED for {LDAP_UID}: {exc}", file=sys.stderr)
        return 1

    print(f"[workstation:{WORKSTATION_ROLE}] LDAP bind OK for {LDAP_UID}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
