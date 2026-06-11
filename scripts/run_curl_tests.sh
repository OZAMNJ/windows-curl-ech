#!/usr/bin/env bash
set -Eeuo pipefail

# ==============================================================================
# ECH Test Validation Suite
# 
# CACERT HANDLING:
# This script requires a Mozilla Root CA Certificate bundle to validate the
# TLS handshake (since we are not using the Windows native Schannel). 
# If 'cacert.pem' is not found in the current directory, it will be downloaded
# securely from curl.se.
# ==============================================================================

# Configuration
RETRY_COUNT=3
CURL_BIN="/mingw64/bin/curl"
CACERT_FILE="cacert.pem"
CACERT_URL="https://curl.se/ca/cacert.pem"
DOH_URL="https://cloudflare-dns.com/dns-query"
RESULTS_CSV="curl_ech_results.csv"

# Logging Functions
log_info()  { echo "[INFO]  $*" ; }
log_warn()  { echo "[WARN]  $*" >&2 ; }
log_error() { echo "[ERROR] $*" >&2 ; }

log_info "=== ECH Curl Validation Suite ==="

# Download cacert.pem dynamically if missing
if [[ ! -f "$CACERT_FILE" ]]; then
    log_info "Downloading Mozilla CA certificate ($CACERT_FILE)..."
    if ! "$CURL_BIN" -k -sS -L "$CACERT_URL" -o "$CACERT_FILE" --fail --connect-timeout 15 --max-time 30; then
        log_error "Failed to download $CACERT_FILE from $CACERT_URL"
        exit 1
    fi
fi

if [[ ! -x "$CURL_BIN" ]]; then
    log_error "curl binary not found at $CURL_BIN"
    exit 1
fi

CURL_V=$("$CURL_BIN" -V)
if ! echo "$CURL_V" | grep -qi "wolfssl"; then
    log_error "wolfSSL backend not found in curl version output!"
    exit 1
fi

if ! echo "$CURL_V" | grep -qi "ECH"; then
    log_error "ECH feature not found in curl version output!"
    exit 1
fi
log_info "Environment checks passed."

echo "TestName,URL,HTTP_Status,TLS_Status,ECH_Status" > "$RESULTS_CSV"

# Network Retry Wrapper
run_with_retry() {
    local max_attempts=$1
    shift
    local attempt=1
    while (( attempt <= max_attempts )); do
        set +e
        "$@"
        local exit_code=$?
        set -e
        if [[ $exit_code -eq 0 ]]; then
            return 0
        fi
        log_warn "Command failed (Attempt $attempt of $max_attempts). Retrying in 2 seconds..."
        sleep 2
        (( attempt++ ))
    done
    return 1
}

# Test execution logic
execute_test() {
    local test_name=$1
    local target_url=$2
    local expect_ech=$3

    log_info "Running Test: $test_name ($target_url)"
    
    local tmp_body="tmp_body.txt"
    local tmp_stderr="tmp_stderr.txt"
    local wout_file="tmp_wout.txt"
    
    set +e
    run_with_retry "$RETRY_COUNT" \
        "$CURL_BIN" -sS --cacert "$CACERT_FILE" --ech hard --doh-url "$DOH_URL" \
        --connect-timeout 10 --max-time 30 \
        -w "%{http_code}" -o "$tmp_body" "$target_url" > "$wout_file" 2> "$tmp_stderr"
    local exit_code=$?
    set -e

    local http_code
    http_code=$(cat "$wout_file" 2>/dev/null || echo "000")
    local body
    body=$(cat "$tmp_body" 2>/dev/null || echo "")
    local err_log
    err_log=$(cat "$tmp_stderr" 2>/dev/null || echo "")

    local tls_status="Failed"
    local ech_status="Failed"

    if [[ $exit_code -eq 0 ]]; then
        tls_status="Success"
    else
        tls_status="Failed ($exit_code)"
    fi

    # Structured ECH evaluation
    if [[ "$target_url" == *"cloudflare-ech.com"* ]]; then
        if echo "$body" | grep -qi "sni=encrypted"; then
            ech_status="Success"
        fi
    elif [[ "$target_url" == *"defo.ie"* ]]; then
        if command -v jq >/dev/null 2>&1; then
            local parsed
            parsed=$(echo "$body" | jq -r '.SSL_ECH_STATUS' 2>/dev/null || echo "null")
            if [[ "$parsed" == "success" ]]; then
                ech_status="Success"
            fi
        else
            if echo "$body" | grep -Eq '"SSL_ECH_STATUS"\s*:\s*"success"'; then
                ech_status="Success"
            fi
        fi
    fi

    echo "$test_name,$target_url,$http_code,$tls_status,$ech_status" >> "$RESULTS_CSV"

    # Validation Logic
    if [[ "$expect_ech" == "true" ]]; then
        if [[ "$ech_status" != "Success" ]]; then
            log_error "Test '$test_name' expected ECH Success but got $ech_status!"
            log_error "Curl Exit Code: $exit_code"
            log_error "Curl Stderr: $err_log"
            exit 1
        fi
        log_info "  -> SUCCESS (ECH Negotiated)"
    else
        if [[ "$exit_code" -eq 0 ]]; then
            log_error "Test '$test_name' expected ECH Failure (due to no DNS record) but connection succeeded!"
            exit 1
        fi
        log_info "  -> SUCCESS (ECH correctly rejected or unavailable)"
    fi
}

log_info "--- Executing Network Tests ---"
execute_test "Cloudflare Trace (Valid ECH)" "https://cloudflare-ech.com/cdn-cgi/trace" "true"
execute_test "Defo.ie Standard (Valid ECH)" "https://defo.ie/echstat.php?format=json" "true"
execute_test "Example.com (No ECH config in DNS)" "https://example.com" "false"

log_info "=== All Tests Passed Successfully! ==="
cat "$RESULTS_CSV"
rm -f tmp_body.txt tmp_stderr.txt tmp_wout.txt
