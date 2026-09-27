"""
External stakeholder - former developer / external contractor
(Description.md section 6 / Plan_Maquette.txt section 15).

This contractor used to maintain the homemade-encryption tool. Their
engagement ended, but their SSH public key was never removed from
biolab_admin's authorized_keys (see sftp-server/entrypoint.sh). This
script demonstrates that the access still works -- connecting AS
biolab_admin, using a key nobody at BioLab remembers exists anymore.

Usage:
  python residual_access_demo.py
"""

import os

import paramiko

SFTP_HOST = os.environ.get("SFTP_HOST", "sftp-server")
SFTP_PORT = int(os.environ.get("SFTP_PORT", "22"))
SFTP_KEY_PATH = os.environ.get("SFTP_KEY_PATH", "/keys/former_contractor_key.key")


def main() -> None:
    key = paramiko.RSAKey.from_private_key_file(SFTP_KEY_PATH)
    transport = paramiko.Transport((SFTP_HOST, SFTP_PORT))
    # Connecting AS biolab_admin -- not as a distinct "contractor" account.
    # The whole point of this vulnerability is that there is no separate,
    # revocable identity for the contractor: they were simply given a key
    # into BioLab's own admin account.
    transport.connect(username="biolab_admin", pkey=key)
    sftp = paramiko.SFTPClient.from_transport(transport)

    print("[former-contractor] connected as biolab_admin using an old, "
          "never-revoked key. Directory listing:")
    for entry in sftp.listdir("."):
        print(f"  - {entry}")

    print(
        "[former-contractor] this account can read inbound/, write "
        "to_encrypt/, and read/write outbound/ -- the exact same "
        "privileges as BioLab's own admin workstation."
    )

    sftp.close()
    transport.close()


if __name__ == "__main__":
    main()
