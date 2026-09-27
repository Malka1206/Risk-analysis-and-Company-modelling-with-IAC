Bastion / IT admin key (Description.md section 6.6 / Plan_Maquette.txt section 14).

`bastion_it_key.key` is the private key an IT staff member uses to reach
the combined bastion + log server container (see ../logging/). It is named
with a `.key` extension so it is automatically excluded by the project's
`.gitignore`.

Usage once deployed:
  ssh -i bastion/keys/bastion_it_key.key -p 2200 itsys@localhost

From that session, administer the internal services directly:
  psql -h patient-db -U biolab_app -d patient_db
  ldapsearch -x -H ldap://ldap -D "uid=it1,ou=people,dc=biolab-analytics,dc=local" -W -b "dc=biolab-analytics,dc=local"
  tail -f /var/log/central.log

Documented weakness (kept as validated): sshd on this box does not
restrict source IPs to "only legitimate IT staff" -- anyone who can reach
it on net_it or net_sci_admin and has this key can connect. There is no
separate network-level enforcement that this must be used only as a
"jump" from a specific place; it is a policy expectation, not a technical
one.
