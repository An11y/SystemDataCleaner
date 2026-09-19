#!/bin/zsh
# Создаёт/находит стабильный identity для codesign, чтобы Full Disk Access
# не слетал при каждой пересборке (adhoc CDHash каждый раз новый).
set -euo pipefail

CERT_CN="System Data Cleaner"

# Имена из вывода security find-identity (строки вида: 1) HASH "Name" …)
identity_names() {
  # $1 = optional "-v" for valid-only
  security find-identity ${1:-} -p codesigning 2>/dev/null \
    | sed -n 's/^ *[0-9][0-9]*) [A-F0-9]* "\(.*\)".*/\1/p'
}

find_identity() {
  local name
  # 1) Trusted Apple identities
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    if [[ "$name" == Developer\ ID\ Application:* ]]; then
      print -r -- "$name"
      return 0
    fi
  done < <(identity_names -v)

  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    if [[ "$name" == Apple\ Development:* ]]; then
      print -r -- "$name"
      return 0
    fi
  done < <(identity_names -v)

  # 2) Наш локальный сертификат (может быть CSSMERR_TP_NOT_TRUSTED — codesign всё равно работает)
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    if [[ "$name" == "$CERT_CN" ]]; then
      print -r -- "$name"
      return 0
    fi
  done < <(identity_names)

  return 1
}

if ID="$(find_identity)"; then
  print -r -- "$ID"
  exit 0
fi

TMP="$(mktemp -d)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

openssl genrsa -out "$TMP/key.pem" 2048 2>/dev/null
cat > "$TMP/cert.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = v3
prompt = no

[dn]
CN = ${CERT_CN}
O = System Data Cleaner
OU = Local Development

[v3]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF

openssl req -new -x509 -key "$TMP/key.pem" -out "$TMP/cert.pem" \
  -days 3650 -config "$TMP/cert.cnf" -extensions v3 2>/dev/null

# OpenSSL 3 PKCS12 по умолчанию не импортируется в связку ключей macOS.
if openssl pkcs12 -help 2>&1 | grep -q -- '-legacy'; then
  openssl pkcs12 -export -legacy -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -out "$TMP/cert.p12" -passout pass:sdc-local -name "$CERT_CN" 2>/dev/null
else
  openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -out "$TMP/cert.p12" -passout pass:sdc-local -name "$CERT_CN" \
    -certpbe PBE-SHA1-3DES -keypbe PBE-SHA1-3DES -macalg sha1 2>/dev/null
fi

KEYCHAIN="${HOME}/Library/Keychains/login.keychain-db"
if [[ ! -f "$KEYCHAIN" ]]; then
  KEYCHAIN="${HOME}/Library/Keychains/login.keychain"
fi

security import "$TMP/cert.p12" \
  -k "$KEYCHAIN" \
  -P sdc-local \
  -T /usr/bin/codesign \
  -T /usr/bin/security \
  -T /usr/bin/productsign >/dev/null 2>&1 || true

# По возможности доверяем для code signing (без sudo; может потребовать клик в UI один раз).
security add-trusted-cert -d -r trustRoot -p codeSign -k "$KEYCHAIN" "$TMP/cert.pem" >/dev/null 2>&1 || true

security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "" "$KEYCHAIN" >/dev/null 2>&1 || true

if ID="$(find_identity)"; then
  print -r -- "$ID"
  exit 0
fi

print -r -- "-"
exit 0
