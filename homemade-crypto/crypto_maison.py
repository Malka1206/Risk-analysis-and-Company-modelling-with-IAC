"""
BioLab Analytics - "chiffrement maison" (Description.md section 3.5)

DELIBERATELY WEAK, real cipher: repeating-key XOR with a static, hardcoded
key. No IV, no salt, no key rotation, no authenticated encryption. XOR is
involutive, so `encrypt_file` and `decrypt_file` are literally the same
transform -- which is itself worth pointing out in the risk-analysis report
(trivial to "break": XOR the ciphertext with the same key to recover the
plaintext, no cryptanalysis required if the key ever leaks).
"""

STATIC_KEY = b"BioLab2021!KeyNeverRotated"


def _xor_bytes(data: bytes, key: bytes) -> bytes:
    return bytes(b ^ key[i % len(key)] for i, b in enumerate(data))


def encrypt_file(path_in: str, path_out: str) -> None:
    with open(path_in, "rb") as f:
        data = f.read()
    with open(path_out, "wb") as f:
        f.write(_xor_bytes(data, STATIC_KEY))


# XOR is its own inverse: decrypting is the exact same operation.
decrypt_file = encrypt_file
