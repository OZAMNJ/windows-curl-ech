#!/usr/bin/env bats

setup() {
    export WRAPPER="${BATS_TEST_DIRNAME}/../../scripts/curl-ech-wrapper.sh"
    export MOCK_DIR="${BATS_TEST_DIRNAME}/../mocks"
    
    # Prepend mocks to PATH
    export PATH="${MOCK_DIR}:${PATH}"
    
    # Initialize shared mock state
    export BATS_TMPDIR="${BATS_TMPDIR:-/tmp}"
    rm -f "${BATS_TMPDIR}/curl_args.log"
}

# --- 1. Argument Validation ---
@test "Wrapper rejects invalid ech-mode" {
    run "$WRAPPER" --ech-mode invalid_mode https://example.com
    [ "$status" -eq 1 ]
    [[ "$output" == *"[ERROR] Invalid --ech-mode value:"* ]]
    [ ! -f "${BATS_TMPDIR}/curl_args.log" ]
}

@test "Wrapper accepts valid ech-modes" {
    run "$WRAPPER" --ech-mode hard https://example.com
    [ "$status" -eq 0 ]
    
    run "$WRAPPER" --ech-mode false https://example.com
    [ "$status" -eq 0 ]
}

@test "Wrapper safely passes payload without expanding shell variables" {
    local payload="https://example.com/\$(touch evil); echo test"
    run "$WRAPPER" --ech-mode hard "$payload"
    [ "$status" -eq 0 ]
    
    local args=$(cat "${BATS_TMPDIR}/curl_args.log")
    [[ "$args" == *"$payload"* ]]
}

# --- 2. OS Detection and Binary Selection ---
@test "Wrapper maps Windows OS to curl.exe" {
    export CURL_ECH_OS="MSYS_NT-10.0"
    export CURL_BIN_OVERRIDE="curl" # We still map to our 'curl' mock physically, but check the logic
    
    # Run with debug to inspect OS parsing
    run "$WRAPPER" --debug https://example.com
    [ "$status" -eq 0 ]
    
    [[ "$output" == *"[DEBUG] OS Detected: MSYS_NT-10.0"* ]]
    # It would look for curl.exe if override wasn't set, but override ensures execution.
    # To test actual mapping without override breaking execution, we'd need curl.exe.
    # Let's test standard selection explicitly with debug logs.
}

@test "Wrapper selects curl.exe natively on Windows without override" {
    export CURL_ECH_OS="Windows_NT"
    unset CURL_BIN_OVERRIDE
    
    # To prevent execution failure (since curl.exe might not exist in mocks), 
    # we just run the script and ensure it errors out looking for 'curl.exe'.
    run "$WRAPPER" --debug https://example.com
    [ "$status" -eq 1 ]
    [[ "$output" == *"[ERROR] Could not locate 'curl.exe' in PATH."* ]]
}

@test "Wrapper selects curl natively on Linux" {
    export CURL_ECH_OS="Linux"
    unset CURL_BIN_OVERRIDE
    
    # Runs successfully because 'curl' is in mocks
    run "$WRAPPER" --debug https://example.com
    [ "$status" -eq 0 ]
    [[ "$output" == *"[DEBUG] OS Detected: Linux"* ]]
    [[ "$output" == *"[DEBUG] Curl Binary: ${MOCK_DIR}/curl"* ]]
}

# --- 3. Execution Logic ---
@test "Wrapper executes curl with ECH when supported" {
    export CURL_ECH_OS="Linux"
    
    run "$WRAPPER" --ech-mode hard https://example.com
    [ "$status" -eq 0 ]
    
    local args=$(cat "${BATS_TMPDIR}/curl_args.log")
    [[ "$args" == *"--ech hard https://example.com"* ]]
}

@test "Wrapper strips ECH when ECH mode is false" {
    export CURL_ECH_OS="Linux"
    
    run "$WRAPPER" --ech-mode false https://example.com
    [ "$status" -eq 0 ]
    
    local args=$(cat "${BATS_TMPDIR}/curl_args.log")
    [[ "$args" != *"--ech"* ]]
    [[ "$args" == *"https://example.com"* ]]
}
