# Curl with Encrypted Client Hello (ECH) for Windows

## Overview

This repository provides a custom-compiled version of `curl` for Windows that natively supports **Encrypted Client Hello (ECH)**.

**What is ECH?**
During a standard TLS handshake, the Server Name Indication (SNI) is sent in plaintext, revealing the exact domain you are visiting to your ISP, network administrators, or passive eavesdroppers. **ECH** encrypts this handshake, completely blinding network observers to your destination domain.

**Supported Versions:**
- `curl`: 8.8.0
- `wolfSSL`: 5.7.0

*(Native `curl.exe` on Windows uses Schannel, which does not support ECH. This repository solves that by providing a fully reproducible build of curl using the wolfSSL cryptography backend.)*

---

## Security & Verification

We provide enterprise-grade build reproducibility and provenance tracking. Every GitHub Action build guarantees parity with the source code.

### Binary Verification

To verify that your downloaded `curl-ech-windows-x64.zip` is authentic:

**Windows PowerShell:**
```powershell
Get-FileHash curl-ech-windows-x64.zip -Algorithm SHA256
```
*(Compare the output to the `curl-ech-windows-x64.zip.sha256` file provided in the Release)*

**Bash / MSYS2:**
```bash
sha256sum -c curl-ech-windows-x64.zip.sha256
```

Additionally, check `build-manifest.json` inside the ZIP to verify the exact Git commits, source tarball hashes, and compiler versions used during the build.

---

## Build Instructions

### Windows (MSYS2)

You can easily compile this securely yourself using our provided scripts:

1. **Install MSYS2:**
   Open PowerShell as Administrator and run our secure installer wrapper:
   ```powershell
   .\scripts\install_msys2.ps1
   ```
   *(This downloads the exact MSYS2 release, verifies its SHA256 hash, and installs it to `C:\msys64`)*

2. **Run Build Script:**
   Open the **MSYS2 MinGW 64-bit** terminal and run:
   ```bash
   ./scripts/build-curl-ech.sh
   ```
   *(This downloads the exact `curl` and `wolfSSL` tarballs, validates their checksums, compiles them, and generates your new binary in the `release_bin/` folder).*

---

## Testing

Run our automated, deterministic validation suite to ensure ECH is functioning:

```bash
./scripts/run_curl_tests.sh
```

This suite will test endpoints with valid ECH configurations (e.g., Cloudflare Trace) and purposely broken endpoints, verifying strict TLS and ECH negotiation status without false positives.

## Cross-Platform ECH Wrapper

We provide a robust, production-safe wrapper script (`scripts/curl-ech-wrapper.sh`) designed to intelligently manage ECH executions.

### Features
1. **OS Compatibility:** Automatically calls `curl.exe` on Windows environments to prevent alias clashes with PowerShell's native `Invoke-WebRequest`.
2. **Version & Feature Validation:** Safely parses `curl -V` to ensure you are running `curl >= 8.8.0` with ECH support compiled in. If ECH is unavailable, it gracefully disables the flag instead of crashing.
3. **Graceful Fallbacks:** If an ECH connection is rejected or fails due to network conditions, the wrapper will catch the failure and automatically retry the request without ECH, keeping your production pipelines stable.
4. **Debug Mode:** Use the `--debug` flag to see exact binary paths, version strings, and execution arrays.

**Usage:**
```bash
./scripts/curl-ech-wrapper.sh --ech-mode hard --debug --cacert cacert.pem --doh-url https://cloudflare-dns.com/dns-query https://cloudflare-ech.com/cdn-cgi/trace
```

---

## Troubleshooting

### ECH Is Not Working / Handshake Fails
ECH is a multi-layered protocol. It requires cooperation from the entire network stack.

1. **Client Support:** Ensure you are using *this* custom `curl.exe` and NOT your native `C:\Windows\System32\curl.exe`. Run `curl -V` and look for `wolfSSL` and `ECH`.
2. **DNS Record:** The destination server *must* publish an `HTTPS` DNS record containing the `ECHConfigList`. Use an external tool to check if the domain supports ECH.
3. **Secure DNS:** You MUST pass a DNS-over-HTTPS server to curl using `--doh-url <url>`. If you rely on standard port 53 UDP DNS, your ISP can intercept the query, or curl will fail to securely fetch the required `HTTPS` record.
4. **Certificate Errors:** If you get `SSL certificate problem`, ensure you pass `--cacert cacert.pem` to provide curl with root trust anchors.

**Example Command for Testing:**
```bash
curl.exe -sS --cacert cacert.pem --ech hard --doh-url https://cloudflare-dns.com/dns-query https://cloudflare-ech.com/cdn-cgi/trace | grep sni
```

## License
MIT License
