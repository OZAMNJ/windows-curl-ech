#!/usr/bin/env bash
set -Eeuo pipefail

# ==============================================================================
# curl ECH Wrapper Utility
# ==============================================================================

log_info()  { echo "[INFO]  $*" >&2 ; }
log_warn()  { echo "[WARN]  $*" >&2 ; }
log_error() { echo "[ERROR] $*" >&2 ; }
log_debug() { if [[ "${DEBUG_MODE:-false}" == "true" ]]; then echo "[DEBUG] $*" >&2 ; fi }

# Detect OS to select correct binary
detect_os() {
    uname -s
}

get_curl_binary() {
    local os_type="$1"
    if [[ "$os_type" == MINGW* || "$os_type" == CYGWIN* || "$os_type" == MSYS* || "$os_type" == *NT* ]]; then
        echo "curl.exe"
    else
        echo "curl"
    fi
}

resolve_curl_path() {
    local bin="$1"
    if command -v "$bin" >/dev/null 2>&1; then
        command -v "$bin"
    else
        echo ""
    fi
}

get_curl_version_output() {
    local curl_path="$1"
    "$curl_path" -V || true
}

execute_curl() {
    local curl_path="$1"
    shift
    "$curl_path" "$@"
}

parse_arguments() {
    ECH_MODE="hard"
    DEBUG_MODE="false"
    CURL_ARGS=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --ech-mode)
                if [[ "$2" =~ ^(true|hard|grease|false)$ ]]; then
                    ECH_MODE="$2"
                    shift 2
                else
                    log_error "Invalid --ech-mode value: '$2'. Allowed values: true, hard, grease, false."
                    return 1
                fi
                ;;
            --debug)
                DEBUG_MODE="true"
                shift
                ;;
            *)
                CURL_ARGS+=("$1")
                shift
                ;;
        esac
    done
    return 0
}

main() {
    if ! parse_arguments "$@"; then
        exit 1
    fi

    local os_type
    os_type=$(detect_os)
    
    local curl_bin
    curl_bin=$(get_curl_binary "$os_type")
    
    local curl_path
    curl_path=$(resolve_curl_path "$curl_bin")
    
    if [[ -z "$curl_path" ]]; then
        log_error "Could not locate '$curl_bin' in PATH."
        exit 1
    fi

    local curl_v_output
    curl_v_output=$(get_curl_version_output "$curl_path")
    
    local curl_version
    curl_version=$(echo "$curl_v_output" | head -n1 | awk '{print $2}')

    local ech_supported="false"
    
    # Strip non-numeric/dot characters
    local clean_version="${curl_version//[^0-9.]/}"
    local -a v_parts
    IFS='.' read -ra v_parts <<< "$clean_version"
    
    if [[ ${v_parts[0]:-0} -lt 8 ]] || { [[ ${v_parts[0]:-0} -eq 8 ]] && [[ ${v_parts[1]:-0} -lt 8 ]]; }; then
        log_warn "curl version is $curl_version. ECH requires curl >= 8.8.0. Proceeding without ECH."
    else
        if echo "$curl_v_output" | grep -qi "ECH"; then
            ech_supported="true"
        else
            log_warn "curl binary does not have ECH support compiled in. Proceeding without ECH."
        fi
    fi

    local -a exec_args=()
    if [[ "$ech_supported" == "true" && "$ECH_MODE" != "false" ]]; then
        exec_args+=("--ech" "$ECH_MODE")
    fi
    exec_args+=("${CURL_ARGS[@]}")

    log_debug "OS Detected: $os_type"
    log_debug "Curl Binary: $curl_path (Version: $curl_version)"
    log_debug "ECH Supported: $ech_supported"
    log_debug "Executing Command: $curl_path ${exec_args[*]}"

    set +e
    execute_curl "$curl_path" "${exec_args[@]}"
    local curl_exit_code=$?
    set -e

    if [[ $curl_exit_code -ne 0 && "$ech_supported" == "true" && "$ECH_MODE" != "false" ]]; then
        log_warn "Curl request failed (Exit Code: $curl_exit_code)."
        log_warn "Initiating safe fallback: Retrying request WITHOUT ECH..."
        
        log_debug "Executing Command (Fallback): $curl_path ${CURL_ARGS[*]}"
        
        set +e
        execute_curl "$curl_path" "${CURL_ARGS[@]}"
        local fallback_exit_code=$?
        set -e
        
        if [[ $fallback_exit_code -ne 0 ]]; then
            log_error "Fallback request also failed (Exit Code: $fallback_exit_code)."
            exit $fallback_exit_code
        fi
        exit 0
    fi

    exit $curl_exit_code
}

# Only execute main if the script is not being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
