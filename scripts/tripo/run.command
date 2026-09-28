#!/bin/zsh
set -e
cd "$(dirname "$0")/../.."
set -a
source .env
set +a
GILDED_NODE="${NODE_BIN:-/Users/yangjianwen/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node}"
mkdir -p tools/cache
if [[ ! -s tools/cache/system-ca.pem ]]; then
    /usr/bin/security find-certificate -a -p /Library/Keychains/System.keychain > "tools/cache/system-ca.pem.$$"
    /usr/bin/security find-certificate -a -p /System/Library/Keychains/SystemRootCertificates.keychain >> "tools/cache/system-ca.pem.$$"
    mv "tools/cache/system-ca.pem.$$" tools/cache/system-ca.pem
fi
export CURL_CA_BUNDLE="$PWD/tools/cache/system-ca.pem"
export TRIPO_DOWNLOAD_DIRECT="${TRIPO_DOWNLOAD_DIRECT:-1}"
exec "$GILDED_NODE" tools/network/with-system-proxy.mjs "$GILDED_NODE" scripts/tripo/produce.mjs "$@"
