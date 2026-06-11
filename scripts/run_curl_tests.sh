#!/bin/bash
set -e

export PATH="/mingw64/bin:$PATH"

echo "=== ECH Curl Validation Suite ==="

if [ ! -f "cacert.pem" ]; then
    echo "Downloading Mozilla CA certificate..."
    curl -sL "https://curl.se/ca/cacert.pem" -o cacert.pem
fi

# 1. Basic Curl & Backend Check
CURL_V=$(/mingw64/bin/curl -V)
if ! echo "$CURL_V" | grep -q "wolfSSL"; then
    echo "ERROR: wolfSSL backend not found! Aborting tests."
    exit 1
fi

if ! echo "$CURL_V" | grep -q "ECH"; then
    echo "ERROR: ECH feature not found in curl! Aborting tests."
    exit 1
fi
echo "Environment check passed."

# Prepare CSV
echo "TestName,URL,HTTP_Status,TLS_Status,ECH_Status" > curl_ech_results.csv

run_test() {
    local test_name=$1
    local url=$2
    local expect_ech=$3

    echo "Running Test: $test_name ($url)"
    
    # Run curl and capture output, headers, and exit code
    # We use -w to get http_code, and redirect stderr to capture TLS errors
    set +e
    output=$(/mingw64/bin/curl -sS --cacert cacert.pem --ech hard --doh-url https://cloudflare-dns.com/dns-query -w "\n%{http_code}" "$url" 2>curl_err.log)
    exit_code=$?
    set -e

    http_code=$(echo "$output" | tail -n1)
    body=$(echo "$output" | sed '$d')
    err_log=$(cat curl_err.log)

    tls_status="Failed"
    ech_status="Failed"

    if [ $exit_code -eq 0 ]; then
        tls_status="Success"
    else
        tls_status="Failed ($exit_code)"
    fi

    if echo "$body" | grep -q -i "sni=encrypted" || echo "$body" | grep -q '"SSL_ECH_STATUS"[[:space:]]*:[[:space:]]*"success"'; then
        ech_status="Success"
    fi

    echo "$test_name,$url,$http_code,$tls_status,$ech_status" >> curl_ech_results.csv

    # Validation
    if [ "$expect_ech" = "true" ]; then
        if [ "$ech_status" != "Success" ]; then
            echo "ERROR: Test '$test_name' expected ECH Success but got $ech_status!"
            echo "Curl Error Log: $err_log"
            exit 1
        fi
        echo "  -> SUCCESS (ECH Negotiated)"
    else
        if [ "$exit_code" -eq 0 ]; then
            echo "ERROR: Test '$test_name' expected ECH Failure but connection succeeded!"
            exit 1
        fi
        echo "  -> SUCCESS (ECH correctly rejected or unavailable)"
    fi
}

# 2. Run Test Cases
echo "--- Executing Network Tests ---"

run_test "Cloudflare Trace (Valid ECH)" "https://cloudflare-ech.com/cdn-cgi/trace" "true"
run_test "Defo.ie Standard (Valid ECH)" "https://defo.ie/echstat.php?format=json" "true"
run_test "Example.com (No ECH config in DNS)" "https://example.com" "false"
run_test "Defo.ie Broken Config" "https://badalpn-ng.test.defo.ie/echstat.php?format=json" "true" # Note: Some defo test endpoints succeed with ECH by design for fallback testing.

echo "=== All Tests Passed Successfully! ==="
cat curl_ech_results.csv
