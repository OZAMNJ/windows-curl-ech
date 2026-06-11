# Curl with Encrypted Client Hello (ECH) for Windows

This repository provides a custom-compiled version of `curl` for Windows that natively supports **Encrypted Client Hello (ECH)**. It is built reproducibly via GitHub Actions using the `wolfSSL` cryptographic backend.

The native `curl.exe` bundled with Windows 10/11 uses the Microsoft Schannel TLS backend, which currently does not support the ECH standard. By compiling `curl` from source with `wolfSSL`, this build fully unlocks strict ECH support on the Windows command line, ensuring your Server Name Indication (SNI) is completely encrypted during the TLS handshake.

## Security & Provenance

We use a strict reproducible build pipeline via GitHub Actions.
Every release contains a `build-manifest.json` that details the exact `curl` and `wolfSSL` Git commits, the compiler version, and the SHA256 hashes of the resulting binaries.

### Verifying Your Download
To ensure the binary hasn't been tampered with, calculate the SHA256 hash of `curl.exe` locally and compare it to the manifest:

**PowerShell:**
```powershell
Get-FileHash curl.exe -Algorithm SHA256
```

**Bash / MSYS2:**
```bash
sha256sum curl.exe
```

## Download the Pre-compiled Binary

You can download the ready-to-use executable from the **Releases** page.
1. Download `curl-ech-windows-x64.zip` from the latest Release.
2. Extract the folder (it contains `curl.exe`, its required DLLs, and a standard Mozilla `cacert.pem`).
3. Open your terminal in the extracted folder and run your curl commands!

## ECH Prerequisites

> [!IMPORTANT]
> ECH does not magically encrypt SNI for every website. It only works if **ALL** the following conditions are met:
> 1. **Client Support:** You use this custom `curl` build.
> 2. **Server Support:** The destination server supports ECH (e.g., Cloudflare-proxied sites).
> 3. **DNS Configuration:** The server publishes an `HTTPS` DNS record containing the ECHConfigList.
> 4. **Secure DNS (DoH/DoT):** You use `--doh-url` so `curl` can securely fetch the HTTPS DNS record without it being intercepted.

### Usage Example

To test ECH against Cloudflare's diagnostic trace, run:

```bash
curl.exe -s --cacert cacert.pem --ech hard --doh-url https://cloudflare-dns.com/dns-query https://cloudflare-ech.com/cdn-cgi/trace | findstr sni
```
*If successful, it will print `sni=encrypted`.*

## Compiling from Source

If you wish to compile this yourself from source, run our automated build script in an MSYS2 environment. This script pins exact library versions for reproducibility.

1. Install [MSYS2](https://www.msys2.org/) (or use `scripts/install_msys2.ps1`).
2. Open the **MSYS2 MinGW 64-bit** terminal.
3. Install dependencies: `pacman -S make cmake gcc git nasm autoconf automake libtool`
4. Run our automated build: `./scripts/build_curl.sh`

The compiled executable and the `build-manifest.json` will be output to the `release_bin/` directory.

## Automated Validation Suite

We provide a strict testing suite (`scripts/run_curl_tests.sh`) that runs post-compilation. It tests:
* `curl -V` symbol validation (ensures `wolfSSL` and `ECH` are present).
* ECH Negotiation Success (e.g., against `cloudflare-ech.com`).
* ECH Negotiation Rejection (e.g., standard domains without ECH configs).

## Troubleshooting

- **`curl: (60) SSL certificate problem`**: You did not provide a CA certificate. Add `--cacert cacert.pem`.
- **`curl: (3) URL using bad/illegal format or missing URL`**: Your `--doh-url` format is invalid.
- **Connection Refused / Timeout**: The DoH server is unreachable or the destination server does not support ECH but you forced `--ech hard`. Fallback to `--ech true` (opportunistic) if the server does not strictly support ECH.

## License
MIT License
