"""
BioLab Analytics - homemade-crypto watcher (Description.md section 3.5)

Real, automatic step: polls /exchange/to_encrypt (workflow step 7, fed by
the admin workstation once a result is medically validated) and, for every
new file found, encrypts it with the weak homemade cipher and drops it in
/exchange/outbound (workflow step 8-9), which is the SAME physical
directory the sftp-server container exposes to the hospital account as
/data/outbound.

No key management whatsoever: the key lives in crypto_maison.py, baked into
the image, identical on every run -- exactly the weakness documented in the
plan.
"""

import os
import time

from crypto_maison import encrypt_file

EXCHANGE_ROOT = os.environ.get("EXCHANGE_ROOT", "/exchange")
WATCH_DIR = os.path.join(EXCHANGE_ROOT, "to_encrypt")
OUT_DIR = os.path.join(EXCHANGE_ROOT, "outbound")
PROCESSED_LOG = os.path.join(EXCHANGE_ROOT, ".processed")
POLL_INTERVAL_SECONDS = int(os.environ.get("POLL_INTERVAL_SECONDS", "3"))


def load_processed() -> set:
    if not os.path.exists(PROCESSED_LOG):
        return set()
    with open(PROCESSED_LOG) as f:
        return set(line.strip() for line in f if line.strip())


def mark_processed(fname: str) -> None:
    with open(PROCESSED_LOG, "a") as f:
        f.write(fname + "\n")


def main() -> None:
    os.makedirs(WATCH_DIR, exist_ok=True)
    os.makedirs(OUT_DIR, exist_ok=True)

    processed = load_processed()
    print(f"[homemade-crypto] watching {WATCH_DIR} -> {OUT_DIR}", flush=True)

    while True:
        try:
            for fname in sorted(os.listdir(WATCH_DIR)):
                if fname in processed:
                    continue
                src = os.path.join(WATCH_DIR, fname)
                if not os.path.isfile(src):
                    continue

                dst = os.path.join(OUT_DIR, fname + ".enc")
                encrypt_file(src, dst)
                processed.add(fname)
                mark_processed(fname)
                print(f"[homemade-crypto] encrypted {fname} -> {dst}", flush=True)
        except FileNotFoundError:
            # WATCH_DIR briefly missing (e.g. volume not yet mounted); retry.
            pass

        time.sleep(POLL_INTERVAL_SECONDS)


if __name__ == "__main__":
    main()
