#!/usr/bin/env bash
#
# Generate the X.509 test PKI used by the e2e harnesses.
#
# For each signing algorithm used by the supported MLS cipher suites
# (Ed25519, ECDSA P-256, ECDSA P-384, ECDSA P-521) this creates:
#
#   test_pki/<name>_ca/{key.pem,cert.pem,cert.der}     self-signed root CA
#   test_pki/<name>_alice/{key.pem,cert.pem,cert.der}  leaf signed by the CA
#   test_pki/<name>_bob/{key.pem,cert.pem,cert.der}    leaf signed by the CA
#
# Root CAs carry `basicConstraints=critical,CA:true` and
# `keyUsage=critical,keyCertSign,cRLSign`; leaves carry
# `basicConstraints=critical,CA:false` and
# `keyUsage=critical,digitalSignature`, matching what the RustCrypto
# X.509 validator enforces for CA certificates.

set -euo pipefail

cd "$(dirname "$0")/.."
PKI_DIR="$(pwd)/test_pki"
mkdir -p "$PKI_DIR"

DAYS=3650

gen_key() {
    local curve="$1" out="$2"
    case "$curve" in
        ed25519)
            openssl genpkey -algorithm ed25519 -out "$out"
            ;;
        p256)
            openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out "$out"
            ;;
        p384)
            openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-384 -out "$out"
            ;;
        p521)
            openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-521 -out "$out"
            ;;
        *)
            echo "unknown curve: $curve" >&2
            return 1
            ;;
    esac
}

# The RustCrypto X.509 validator verifies certificate signatures with
# the digest matching the issuer's curve (P-256 -> SHA-256,
# P-384 -> SHA-384, P-521 -> SHA-512), so the signing digest must be
# pinned accordingly.
sig_digest() {
    case "$1" in
        p256) echo "-sha256" ;;
        p384) echo "-sha384" ;;
        p521) echo "-sha512" ;;
        *) echo "" ;;
    esac
}

der_of() {
    openssl x509 -in "$1" -outform DER -out "$2"
}

for curve in ed25519 p256 p384 p521; do
    ca="$PKI_DIR/${curve}_ca"
    mkdir -p "$ca"

    if [[ ! -f "$ca/cert.der" ]]; then
        gen_key "$curve" "$ca/key.pem"
        openssl req -x509 -new -key "$ca/key.pem" -days "$DAYS" \
            $(sig_digest "$curve") \
            -subj "/CN=MlsRs Test CA ($curve)" \
            -addext "basicConstraints=critical,CA:true" \
            -addext "keyUsage=critical,keyCertSign,cRLSign" \
            -out "$ca/cert.pem"
        der_of "$ca/cert.pem" "$ca/cert.der"
    fi

    for who in alice bob; do
        leaf="$PKI_DIR/${curve}_${who}"
        mkdir -p "$leaf"
        [[ -f "$leaf/cert.der" ]] && continue

        gen_key "$curve" "$leaf/key.pem"
        openssl req -new -key "$leaf/key.pem" \
            -subj "/CN=$who ($curve)" -out "$leaf/csr.pem"
        openssl x509 -req -in "$leaf/csr.pem" \
            -CA "$ca/cert.pem" -CAkey "$ca/key.pem" -CAcreateserial \
            -days "$DAYS" $(sig_digest "$curve") \
            -extfile <(printf '%s\n' \
                "basicConstraints=critical,CA:false" \
                "keyUsage=critical,digitalSignature") \
            -out "$leaf/cert.pem"
        der_of "$leaf/cert.pem" "$leaf/cert.der"
    done

    echo "generated $curve PKI"
done

echo "Test PKI written to $PKI_DIR"
