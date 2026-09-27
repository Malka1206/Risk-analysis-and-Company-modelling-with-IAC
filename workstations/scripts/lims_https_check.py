"""
BioLab Analytics - workstation: real certificate verification against the
LIMS (Description.md section 6.4 / Plan_Maquette.txt section 12).

Unlike the compute-node/LIMS -> MinIO flow (which deliberately disables
verification), THIS flow performs a genuine certificate check: `verify`
points at BioLab's internal CA bundle, and requests will raise
SSLCertificateVerificationError if the LIMS ever presented a certificate
NOT signed by that CA (self-signed by someone else, expired, wrong
hostname, etc.).

Usage:
  python lims_https_check.py
"""

import os
import sys

import requests

LIMS_URL = os.environ.get("LIMS_URL", "https://lims:5001")
CA_BUNDLE = os.environ.get("CA_BUNDLE", "/pki/ca.crt")


def main() -> int:
    try:
        response = requests.get(f"{LIMS_URL}/health", verify=CA_BUNDLE, timeout=10)
    except requests.exceptions.SSLError as exc:
        print(f"[workstation] TLS verification FAILED for {LIMS_URL}: {exc}", file=sys.stderr)
        return 1

    if response.status_code == 200:
        print(f"[workstation] {LIMS_URL} presented a certificate signed by "
              f"BioLab's internal CA -- verification OK ({response.json()}).")
        return 0

    print(f"[workstation] unexpected status {response.status_code} from {LIMS_URL}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
