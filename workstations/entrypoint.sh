#!/bin/sh
set -e

echo "[workstation] booting as role=${WORKSTATION_ROLE} uid=${LDAP_UID}"
python /app/ldap_login_test.py

echo "[workstation] LDAP session established. Waiting for interactive use"
echo "[workstation] (docker exec -it <container> python <script>.py ...)"

# Keep the "workstation" up and idle, like a logged-in machine waiting at
# its desk -- workflow actions are run explicitly via docker exec, exactly
# like a real user would run a script or open an app.
exec tail -f /dev/null
