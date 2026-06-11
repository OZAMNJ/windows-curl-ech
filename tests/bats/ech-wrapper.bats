#!/usr/bin/env bats

setup() {
    export MOCK_DIR="${BATS_TEST_DIRNAME}/../mocks"
    export WRAPPER="${BATS_TEST_DIRNAME}/../../scripts/curl-ech-wrapper.sh"
    
    # Prepend mocks to PATH
    export PATH="${MOCK_DIR}:${PATH}"
    
    # Initialize shared mock state
    export BATS_TMPDIR="${BATS_TMPDIR:-/tmp}"
    rm -f "${BATS_TMPDIR}/curl_args.log"
    rm -f "${BATS_TMPDIR}/curl_fail_once.lock"
    
    chmod +x "$WRAPPER"
    chmod +x "${MOCK_DIR}/curl"
    chmod +x "${MOCK_DIR}/curl.exe"
}

# --- A. Argument Validation ---
@test "A.1 Rejects invalid ech-mode" {
    run "$WRAPPER" --ech-mode invalid_mode https://example.com
    [ "$status" -eq 1 ]
    [[ "$output" == *"[ERROR] Invalid --ech-mode value:"* ]]
    [ ! -f "${BATS_TMPDIR}/curl_args.log" ]
}

@test "A.2 Accepts valid ech-modes" {
    run "$WRAPPER" --ech-mode hard https://example.com
    [ "$status" -eq 0 ]
    
    run "$WRAPPER" --ech-mode false https://example.com
    [ "$status" -eq 0 ]
}

# --- B. OS Detection Logic ---
@test "B.1 Windows OS calls curl.exe" {
    # We must mock uname to return MSYS to test this.
    # We'll create a temporary uname mock in our mock dir.
    echo -e '#!/usr/bin/env bash\necho MSYS_NT-10.0' > "${MOCK_DIR}/uname"
    chmod +x "${MOCK_DIR}/uname"
    
    run "$WRAPPER" --debug https://example.com
    
    # Cleanup uname mock
    rm "${MOCK_DIR}/uname"
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"Curl Binary: ${MOCK_DIR}/curl.exe"* ]]
}

@test "B.2 Linux OS calls curl" {
    echo -e '#!/usr/bin/env bash\necho Linux' > "${MOCK_DIR}/uname"
    chmod +x "${MOCK_DIR}/uname"
    
    run "$WRAPPER" --debug https://example.com
    
    rm "${MOCK_DIR}/uname"
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"Curl Binary: ${MOCK_DIR}/curl"* ]]
}

# --- C. Execution Correctness ---
@test "C.1 Passes arguments correctly with ech enabled" {
    run "$WRAPPER" --ech-mode hard --silent https://example.com
    [ "$status" -eq 0 ]
    
    local args=$(cat "${BATS_TMPDIR}/curl_args.log")
    [[ "$args" == *"--ech hard --silent https://example.com"* ]]
}

@test "C.2 Excludes ech if ech-mode is false" {
    run "$WRAPPER" --ech-mode false https://example.com
    [ "$status" -eq 0 ]
    
    local args=$(cat "${BATS_TMPDIR}/curl_args.log")
    [[ "$args" != *"--ech"* ]]
    [[ "$args" == *"https://example.com"* ]]
}

# --- D. Fallback Behavior (CRITICAL) ---
@test "D.1 Fallback triggers on failure and succeeds" {
    export MOCK_CURL_BEHAVIOR="fail-once"
    
    run "$WRAPPER" --ech-mode hard https://example.com
    [ "$status" -eq 0 ]
    
    # Verify curl was called exactly twice
    local call_count=$(wc -l < "${BATS_TMPDIR}/curl_args.log")
    [ "$call_count" -eq 2 ]
    
    # First call should have --ech hard
    local first_call=$(sed -n '1p' "${BATS_TMPDIR}/curl_args.log")
    [[ "$first_call" == *"--ech hard"* ]]
    
    # Second call should NOT have --ech hard
    local second_call=$(sed -n '2p' "${BATS_TMPDIR}/curl_args.log")
    [[ "$second_call" != *"--ech"* ]]
}

@test "D.2 Final failure propagates exit code" {
    export MOCK_CURL_BEHAVIOR="fail"
    
    run "$WRAPPER" --ech-mode hard https://example.com
    [ "$status" -eq 35 ]
    
    [[ "$output" == *"[ERROR] Fallback request also failed (Exit Code: 35)."* ]]
}

# --- E. Version Parsing ---
@test "E.1 Disables ECH for older curl versions" {
    export MOCK_CURL_VERSION="old"
    
    run "$WRAPPER" --ech-mode hard https://example.com
    [ "$status" -eq 0 ]
    
    [[ "$output" == *"[WARN]  curl version is 8.7.1. ECH requires curl >= 8.8.0. Proceeding without ECH."* ]]
    
    local args=$(cat "${BATS_TMPDIR}/curl_args.log")
    [[ "$args" != *"--ech"* ]]
}

@test "E.2 Disables ECH if feature flag missing" {
    export MOCK_CURL_VERSION="no-ech"
    
    run "$WRAPPER" --ech-mode hard https://example.com
    [ "$status" -eq 0 ]
    
    [[ "$output" == *"[WARN]  curl binary does not have ECH support compiled in. Proceeding without ECH."* ]]
    
    local args=$(cat "${BATS_TMPDIR}/curl_args.log")
    [[ "$args" != *"--ech"* ]]
}

# --- F. Injection Safety ---
@test "F.1 Prevents command injection via ech-mode" {
    run "$WRAPPER" --ech-mode "hard; touch ${BATS_TMPDIR}/evil_file" https://example.com
    [ "$status" -eq 1 ]
    [ ! -f "${BATS_TMPDIR}/evil_file" ]
    [ ! -f "${BATS_TMPDIR}/curl_args.log" ]
}

@test "F.2 Safely escapes target URLs" {
    run "$WRAPPER" --ech-mode hard "https://example.com/\$(touch ${BATS_TMPDIR}/evil_file2)"
    [ "$status" -eq 0 ]
    
    [ ! -f "${BATS_TMPDIR}/evil_file2" ]
    
    # The literal string should have been passed to curl without execution
    local args=$(cat "${BATS_TMPDIR}/curl_args.log")
    [[ "$args" == *"\$(touch"* ]]
}

# --- G. Debug Mode ---
@test "G.1 Prints debug information" {
    run "$WRAPPER" --debug https://example.com
    [ "$status" -eq 0 ]
    
    [[ "$output" == *"[DEBUG] OS Detected:"* ]]
    [[ "$output" == *"[DEBUG] Curl Binary:"* ]]
    [[ "$output" == *"[DEBUG] Executing Command:"* ]]
}
