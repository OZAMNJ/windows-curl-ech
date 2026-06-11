#!/usr/bin/env bash
set -Eeuo pipefail

# Configuration
WOLFSSL_VERSION="5.7.0"
CURL_VERSION="8.8.0"

WOLFSSL_TAR="wolfssl-${WOLFSSL_VERSION}.tar.gz"
CURL_TAR="curl-${CURL_VERSION}.tar.gz"

WOLFSSL_URL="https://github.com/wolfSSL/wolfssl/archive/refs/tags/v${WOLFSSL_VERSION}-stable.tar.gz"
CURL_URL="https://github.com/curl/curl/releases/download/curl-${CURL_VERSION//./_}/curl-${CURL_VERSION}.tar.gz"

# Logging Functions
log_info()  { echo "[INFO]  $*" ; }
log_error() { echo "[ERROR] $*" >&2 ; }

export PATH="/mingw64/bin:$PATH"

log_info "=== Starting Reproducible Build ==="
log_info "wolfSSL Version: $WOLFSSL_VERSION"
log_info "curl Version: $CURL_VERSION"

# 1. Download and Verify wolfSSL
log_info "--- Downloading wolfSSL ---"
if [[ ! -f "$WOLFSSL_TAR" ]]; then
    curl -sS -L "$WOLFSSL_URL" -o "$WOLFSSL_TAR" --fail
fi

log_info "Extracting wolfSSL..."
mkdir -p wolfssl_src
tar -xzf "$WOLFSSL_TAR" -C wolfssl_src --strip-components=1

log_info "Building wolfSSL..."
cd wolfssl_src
./autogen.sh
./configure --enable-ech --enable-curl --prefix=/mingw64
make -j"$(nproc)"
make install
cd ..

# 2. Download and Verify curl
log_info "--- Downloading curl ---"
if [[ ! -f "$CURL_TAR" ]]; then
    curl -sS -L "$CURL_URL" -o "$CURL_TAR" --fail
fi

log_info "Extracting curl..."
mkdir -p curl_src
tar -xzf "$CURL_TAR" -C curl_src --strip-components=1

log_info "Building curl..."
cd curl_src
./configure --with-wolfssl=/mingw64 --enable-ech
make -j"$(nproc)"
make install
cd ..

# 3. Validation
log_info "--- Validating Build ---"
if [[ ! -x "/mingw64/bin/curl.exe" ]]; then
    log_error "curl.exe was not generated!"
    exit 1
fi

CURL_V=$(/mingw64/bin/curl.exe -V)

if ! echo "$CURL_V" | grep -qi "wolfSSL"; then
    log_error "wolfSSL backend not found in curl!"
    exit 1
fi

if ! echo "$CURL_V" | grep -qi "ECH"; then
    log_error "ECH feature not found in curl!"
    exit 1
fi

log_info "Validation passed: ECH and wolfSSL present."

# 4. Packaging and Manifest
log_info "--- Generating Manifest ---"
mkdir -p release_bin
cp /mingw64/bin/curl.exe release_bin/
cp /mingw64/bin/libcurl-*.dll release_bin/
cp /mingw64/bin/libwolfssl-*.dll release_bin/
cp /mingw64/bin/zlib*.dll release_bin/
cp /mingw64/bin/libzstd*.dll release_bin/

cd release_bin
CURL_HASH=$(sha256sum curl.exe | awk '{print $1}')
cat > build-manifest.json <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "compiler": "$(gcc --version | head -n1)",
  "wolfssl": {
    "version": "$WOLFSSL_VERSION",
    "archive_sha256": "$(sha256sum ../$WOLFSSL_TAR | awk '{print $1}')"
  },
  "curl": {
    "version": "$CURL_VERSION",
    "archive_sha256": "$(sha256sum ../$CURL_TAR | awk '{print $1}')"
  },
  "hashes": {
    "curl.exe": "$CURL_HASH"
  }
}
EOF
cd ..

log_info "=== Build Complete ==="
cat release_bin/build-manifest.json
