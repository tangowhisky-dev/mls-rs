#!/usr/bin/env python3
"""Export raw key material of the generated test PKI as JSON.

For every `test_pki/<name>/key.pem` this writes `key.json` containing
`public_key` and `secret_key` as byte arrays, in the exact encoding the
RustCrypto provider expects:

* Ed25519: 32-byte public key, 64-byte keypair (seed || public) secret
* NIST curves: uncompressed SEC1 point, raw scalar secret

Usage: python3 export_key_json.py [pki_dir]
"""

import json
import re
import subprocess
import sys
from pathlib import Path


def key_hex(pem_path: Path) -> tuple[bytes, bytes]:
    """Return (priv_bytes, pub_bytes) from `openssl pkey -text`."""
    out = subprocess.run(
        ["openssl", "pkey", "-in", str(pem_path), "-text", "-noout"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout

    blocks = {}
    current = None
    for line in out.splitlines():
        m = re.match(r"^(priv|pub|NIST CURVE|ED25519|ASN1 OID|Attributes|pub-|priv-)", line)
        stripped = line.strip()
        if stripped.startswith(("priv:", "pub:")):
            current = stripped[:4].rstrip(":")
            blocks[current] = ""
            rest = stripped.split(":", 1)[1].strip()
            blocks[current] += re.sub(r"[^0-9a-fA-F]", "", rest)
        elif current and re.match(r"^[0-9a-fA-F:]+\s*$", stripped):
            blocks[current] += re.sub(r"[^0-9a-fA-F]", "", stripped)
        else:
            current = None

    return bytes.fromhex(blocks["priv"]), bytes.fromhex(blocks["pub"])


def is_ed25519(pem_path: Path) -> bool:
    out = subprocess.run(
        ["openssl", "pkey", "-in", str(pem_path), "-text", "-noout"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout
    return "ED25519" in out.upper() or len(key_hex(pem_path)[0]) == 32 and "NIST CURVE" not in out


def main() -> None:
    pki_dir = Path(sys.argv[1] if len(sys.argv) > 1 else "test_pki")
    for key_pem in sorted(pki_dir.glob("*/key.pem")):
        priv, pub = key_hex(key_pem)
        if len(priv) == 32 and len(pub) == 32:
            # Ed25519: provider wants the 64-byte keypair encoding.
            secret = priv + pub
        else:
            secret = priv
        out = {
            "public_key": list(pub),
            "secret_key": list(secret),
        }
        dest = key_pem.with_name("key.json")
        dest.write_text(json.dumps(out))
        # Raw byte dumps for consumers without a JSON parser at hand
        # (Kotlin/Swift harnesses).
        key_pem.with_name("public.bin").write_bytes(pub)
        key_pem.with_name("secret.bin").write_bytes(secret)
        print(f"wrote {dest}")


if __name__ == "__main__":
    main()
