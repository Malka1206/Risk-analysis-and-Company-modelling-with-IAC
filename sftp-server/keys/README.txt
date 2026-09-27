This directory holds the SFTP keypair reused, unrotated, by BOTH the
`biolab_admin` and `hopital_saint_martin` accounts (see Description.md
section 6.5 / Plan_Maquette.txt section 13 for the documented weakness this
represents).

- `biolab_partner_key.pub` is baked into the sftp-server image and IS meant
  to be committed.
- `biolab_partner_key.key` is the PRIVATE key. It is named with a `.key`
  extension on purpose, so it is automatically excluded by the project's
  existing `.gitignore` (`*.key`). Treat it as sensitive even though this is
  only a mockup: it is what an admin workstation and the simulated hospital
  endpoint (section 6) actually use to connect and push/pull files over
  SFTP.

  Note the aggravating factor this represents: the exact same private key
  file is handed to an EXTERNAL partner (the hospital) as is used
  internally by BioLab's own admin workstation -- BioLab cannot revoke the
  hospital's access without also breaking its own, and vice versa.

- `former_contractor_key.pub` / `.key` (Description.md section 6 - "Former
  developer / external contractor"): a SECOND keypair, generated once by a
  contractor who used to maintain the homemade-encryption tool. Their
  public key was added to `biolab_admin`'s authorized_keys and was never
  removed after the contract ended -- a real, still-usable residual access
  path (see external/former-contractor/). This is deliberately separate
  from the partner key above: it represents an internal admin account
  being reachable by someone who should no longer have any access at all,
  not a partner-key-reuse issue.
