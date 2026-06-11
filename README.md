# Curl with Encrypted Client Hello (ECH) for Windows

This repository provides a custom-compiled version of `curl` for Windows that natively supports **Encrypted Client Hello (ECH)**. 

The native `curl.exe` bundled with Windows 10/11 uses the Microsoft Schannel TLS backend, which currently does not support the ECH standard. As a result, network monitors and ISPs can still see the SNI (Server Name Indication) in plaintext during the TLS handshake, exposing which domains you visit.

By compiling `curl` from source with the `wolfSSL` cryptographic backend, this build fully unlocks strict ECH support on the Windows command line, ensuring your SNI is completely encrypted!

## Download the Pre-compiled Binary

You don't need to compile anything! You can download the ready-to-use executable from the **Releases** page on this repository.

1. Download `curl-ech-windows-x64.zip` from the latest Release.
2. Extract the folder (it contains `curl.exe`, its required DLLs, and a standard Mozilla `cacert.pem`).
3. Open your terminal in the extracted folder and run your curl commands!

**Release v1.0.1 Checksum (SHA256):**
`2F58CDBE0D7E277D320C62C577406C4BDAEC9A3BDD956738316FF04975226489`

### Usage Example

To test ECH against Cloudflare's diagnostic trace, run:

```bash
curl.exe -s --cacert cacert.pem --ech hard --doh-url https://cloudflare-dns.com/dns-query https://cloudflare-ech.com/cdn-cgi/trace | findstr sni
```
*If successful, it will print `sni=encrypted`.*

## Compiling from Source

If you wish to compile this yourself from source, you will need the MSYS2 GNU toolchain on Windows.

### Prerequisites
1. Download and install [MSYS2](https://www.msys2.org/).
2. Open the **MSYS2 MinGW 64-bit** terminal.
3. Install the toolchain: `pacman -S make cmake gcc git nasm autoconf automake libtool`

*(Alternatively, use the `scripts/install_msys2.ps1` provided in this repo to automate the deployment).*

### 1. Build wolfSSL
ECH support in curl requires either `wolfSSL` or `BoringSSL`. We use `wolfSSL`.

```bash
git clone https://github.com/wolfSSL/wolfssl.git
cd wolfssl
./autogen.sh
./configure --enable-ech --enable-curl --prefix=/mingw64
make -j$(nproc)
make install
```

### 2. Build Curl
Compile the latest `curl` source against the `wolfSSL` libraries.

```bash
git clone https://github.com/curl/curl.git
cd curl
autoreconf -fi
./configure --with-wolfssl=/mingw64 --enable-ech
make -j$(nproc)
make install
```

Your custom curl will be available in `/mingw64/bin/curl.exe`.

## Automated ECH Testing

We have provided a bash script (`scripts/run_curl_tests.sh`) to automate batch testing against the `defo.ie` ECH test suite. Run it from within the MSYS2 environment to verify ECH cryptographic compliance across different server configurations.

## License
MIT License
