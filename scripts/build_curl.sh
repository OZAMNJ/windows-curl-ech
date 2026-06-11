#!/bin/bash
set -e

WOLFSSL_VERSION="v5.7.0-stable"
CURL_VERSION="curl-8_8_0"

echo "=== Starting Reproducible Build ==="
echo "Pinned wolfSSL: $WOLFSSL_VERSION"
echo "Pinned curl: $CURL_VERSION"

export PATH="/mingw64/bin:$PATH"

# 1. Build wolfSSL
echo "--- Building wolfSSL ---"
if [ ! -d "wolfssl" ]; then
    git clone https://github.com/wolfSSL/wolfssl.git
fi
cd wolfssl
git checkout $WOLFSSL_VERSION
WOLFSSL_COMMIT=$(git rev-parse HEAD)
./autogen.sh
./configure --enable-ech --enable-curl --prefix=/mingw64
make -j$(nproc)
make install
cd ..

# 2. Build curl
echo "--- Building curl ---"
if [ ! -d "curl" ]; then
    git clone https://github.com/curl/curl.git
fi
cd curl
git checkout $CURL_VERSION
CURL_COMMIT=$(git rev-parse HEAD)
autoreconf -fi
./configure --with-wolfssl=/mingw64 --enable-ech
make -j$(nproc)
make install
cd ..

# 3. Validation
echo "--- Validating Build ---"
CURL_V=$(/mingw64/bin/curl -V)

if ! echo "$CURL_V" | grep -q "wolfSSL"; then
    echo "ERROR: wolfSSL backend not found in curl!"
    exit 1
fi

if ! echo "$CURL_V" | grep -q "ECH"; then
    echo "ERROR: ECH feature not found in curl!"
    exit 1
fi

echo "Validation passed: ECH and wolfSSL present."

# 4. Packaging and Manifest
echo "--- Generating Manifest ---"
mkdir -p release_bin
cp /mingw64/bin/curl.exe release_bin/
cp /mingw64/bin/libcurl-4.dll release_bin/
cp /mingw64/bin/libwolfssl-44.dll release_bin/
cp /mingw64/bin/zlib1.dll release_bin/
cp /mingw64/bin/libzstd.dll release_bin/

cd release_bin
CURL_HASH=$(sha256sum curl.exe | awk '{print $1}')
cat > build-manifest.json <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "compiler": "$(gcc --version | head -n1)",
  "wolfssl": {
    "tag": "$WOLFSSL_VERSION",
    "commit": "$WOLFSSL_COMMIT"
  },
  "curl": {
    "tag": "$CURL_VERSION",
    "commit": "$CURL_COMMIT"
  },
  "hashes": {
    "curl.exe": "$CURL_HASH"
  }
}
EOF
cd ..

echo "=== Build Complete ==="
cat release_bin/build-manifest.json
