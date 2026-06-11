#!/usr/bin/env bats

setup() {
    export WRAPPER="${BATS_TEST_DIRNAME}/../../scripts/curl-ech-wrapper.sh"
    export MOCK_DIR="${BATS_TEST_DIRNAME}/../mocks"
    export PATH="${MOCK_DIR}:${PATH}"
    export BATS_TMPDIR="${BATS_TMPDIR:-/tmp}"
    rm -f "${BATS_TMPDIR}/curl_args.log"

    # Source the wrapper so we can test functions directly
    source "$WRAPPER"
}

# --- 1. Argument Parsing Correctness ---
@test "parse_arguments rejects invalid ech-mode" {
    run parse_arguments --ech-mode invalid_mode https://example.com
    [ "$status" -eq 1 ]
    [[ "$output" == *"[ERROR] Invalid --ech-mode value:"* ]]
}

@test "parse_arguments accepts valid ech-modes" {
    parse_arguments --ech-mode hard https://example.com
    [ "$ECH_MODE" == "hard" ]
    [ "${CURL_ARGS[0]}" == "https://example.com" ]

    parse_arguments --ech-mode false https://example.com
    [ "$ECH_MODE" == "false" ]
}

@test "parse_arguments safely captures target URL with shell characters" {
    # It must not execute $(touch evil) or fail when seeing semicolons
    local payload="https://example.com/\$(touch evil); echo test"
    parse_arguments --ech-mode hard "$payload"
    [ "${CURL_ARGS[0]}" == "$payload" ]
}

# --- 2. OS Detection and Binary Selection ---
@test "get_curl_binary returns curl.exe for Windows variants" {
    [ "$(get_curl_binary "MSYS_NT-10.0")" == "curl.exe" ]
    [ "$(get_curl_binary "MINGW64_NT-10.0")" == "curl.exe" ]
    [ "$(get_curl_binary "CYGWIN_NT-10.0")" == "curl.exe" ]
}

@test "get_curl_binary returns curl for Linux/macOS" {
    [ "$(get_curl_binary "Linux")" == "curl" ]
    [ "$(get_curl_binary "Darwin")" == "curl" ]
}

# --- 3. Wrapper Execution Logic ---
# To test the wrapper execution without a full mock, we override internal functions.

@test "main executes curl with ECH when supported" {
    # Stub internal functions to simulate a clean run
    detect_os() { echo "Linux"; }
    resolve_curl_path() { echo "curl"; }
    get_curl_version_output() { echo -e "curl 8.8.0\nFeatures: ECH"; }
    
    # We execute main, which will eventually call execute_curl pointing to our mock
    run main --ech-mode hard https://example.com
    [ "$status" -eq 0 ]
    
    local args=$(cat "${BATS_TMPDIR}/curl_args.log")
    [[ "$args" == *"--ech hard https://example.com"* ]]
}

@test "main strips ECH when ECH mode is false" {
    detect_os() { echo "Linux"; }
    resolve_curl_path() { echo "curl"; }
    get_curl_version_output() { echo -e "curl 8.8.0\nFeatures: ECH"; }
    
    run main --ech-mode false https://example.com
    [ "$status" -eq 0 ]
    
    local args=$(cat "${BATS_TMPDIR}/curl_args.log")
    [[ "$args" != *"--ech"* ]]
    [[ "$args" == *"https://example.com"* ]]
}

@test "main disables ECH if feature flag missing" {
    detect_os() { echo "Linux"; }
    resolve_curl_path() { echo "curl"; }
    get_curl_version_output() { echo -e "curl 8.8.0\nFeatures: SSL"; } # No ECH
    
    run main --ech-mode hard https://example.com
    [ "$status" -eq 0 ]
    
    [[ "$output" == *"[WARN]  curl binary does not have ECH support compiled in."* ]]
    
    local args=$(cat "${BATS_TMPDIR}/curl_args.log")
    [[ "$args" != *"--ech"* ]]
}

@test "main gracefully handles version parsing of older versions" {
    detect_os() { echo "Linux"; }
    resolve_curl_path() { echo "curl"; }
    get_curl_version_output() { echo -e "curl 8.7.1\nFeatures: ECH"; }
    
    run main --ech-mode hard https://example.com
    [ "$status" -eq 0 ]
    
    [[ "$output" == *"[WARN]  curl version is 8.7.1. ECH requires curl >= 8.8.0."* ]]
    
    local args=$(cat "${BATS_TMPDIR}/curl_args.log")
    [[ "$args" != *"--ech"* ]]
}
