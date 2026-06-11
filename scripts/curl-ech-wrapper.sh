#!/usr/bin/env bash
set -Eeuo pipefail

# ==============================================================================
# curl ECH Wrapper Utility
# ==============================================================================
# Pure CLI wrapper. Prioritizes environment variables for testability.

log_info()  { echo "[INFO]  $*" >&2 ; }
log_warn()  { echo "[WARN]  $*" >&2 ; }
log_error() { echo "[ERROR] $*" >&2 ; }
log_debug() { if [[ "${DEBUG_MODE:-false}" == "true" ]]; then echo "[DEBUG] $*" >&2 ; fi }

# 1. Argument Parsing & Sanitization
ECH_MODE="hard"
DEBUG_MODE="false"
declare -a CURL_ARGS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --ech-mode)
            if [[ "$2" =~ ^(true|hard|grease|false)$ ]]; then
                ECH_MODE="$2"
                shift 2
            else
                log_error "Invalid --ech-mode value: '$2'. Allowed values: true, hard, grease, false."
                exit 1
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

# 2. OS Detection & Binary Selection
OS_TYPE="${CURL_ECH_OS:-$(uname -s)}"
if [[ -n "${CURL_BIN_OVERRIDE:-}" ]]; then
    CURL_BIN="$CURL_BIN_OVERRIDE"
elif [[ "$OS_TYPE" == MINGW* || "$OS_TYPE" == CYGWIN* || "$OS_TYPE" == MSYS* || "$OS_TYPE" == *NT* ]]; then
    CURL_BIN="curl.exe"
else
    CURL_BIN="curl"
fi

# Determine absolute path if possible
if command -v "$CURL_BIN" >/dev/null 2>&1; then
    CURL_PATH=$(command -v "$CURL_BIN")
else
    log_error "Could not locate '$CURL_BIN' in PATH."
    exit 1
fi

# 3. Version and Feature Validation
# Disable pipefail briefly to parse curl output safely
set +e
CURL_V_OUTPUT=$("$CURL_PATH" -V 2>/dev/null)
set -e

CURL_VERSION=$(echo "$CURL_V_OUTPUT" | head -n1 | awk '{print $2}')
ECH_SUPPORTED="false"

# Strip non-numeric/dot characters
clean_version="${CURL_VERSION//[^0-9.]/}"
IFS='.' read -ra V_PARTS <<< "${clean_version:-0.0.0}"

if [[ ${V_PARTS[0]:-0} -lt 8 ]] || { [[ ${V_PARTS[0]:-0} -eq 8 ]] && [[ ${V_PARTS[1]:-0} -lt 8 ]]; }; then
    log_warn "curl version is $CURL_VERSION. ECH requires curl >= 8.8.0. Proceeding without ECH."
else
    if echo "$CURL_V_OUTPUT" | grep -qi "ECH"; then
        ECH_SUPPORTED="true"
    else
        log_warn "curl binary does not have ECH support compiled in. Proceeding without ECH."
    fi
fi

# 4. Construct Command
declare -a EXEC_ARGS=()

if [[ "$ECH_SUPPORTED" == "true" && "$ECH_MODE" != "false" ]]; then
    EXEC_ARGS+=("--ech" "$ECH_MODE")
fi

EXEC_ARGS+=("${CURL_ARGS[@]}")

log_debug "OS Detected: $OS_TYPE"
log_debug "Curl Binary: $CURL_PATH (Version: $CURL_VERSION)"
log_debug "ECH Supported: $ECH_SUPPORTED"
log_debug "Executing Command: $CURL_PATH ${EXEC_ARGS[*]}"

# 5. Execution and Fallback Behavior
set +e
"$CURL_PATH" "${EXEC_ARGS[@]}"
CURL_EXIT_CODE=$?
set -e

# If curl failed, and we attempted an ECH request, retry without ECH
if [[ $CURL_EXIT_CODE -ne 0 && "$ECH_SUPPORTED" == "true" && "$ECH_MODE" != "false" ]]; then
    log_warn "Curl request failed (Exit Code: $CURL_EXIT_CODE)."
    log_warn "Initiating safe fallback: Retrying request WITHOUT ECH..."
    
    log_debug "Executing Command (Fallback): $CURL_PATH ${CURL_ARGS[*]}"
    
    set +e
    "$CURL_PATH" "${CURL_ARGS[@]}"
    FALLBACK_EXIT_CODE=$?
    set -e
    
    if [[ $FALLBACK_EXIT_CODE -ne 0 ]]; then
        log_error "Fallback request also failed (Exit Code: $FALLBACK_EXIT_CODE)."
        exit $FALLBACK_EXIT_CODE
    fi
    exit 0
fi

exit $CURL_EXIT_CODE
