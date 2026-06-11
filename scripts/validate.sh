#!/usr/bin/env bash
set -Eeuo pipefail

# ==============================================================================
# Validation Smoke Test
# ==============================================================================
# Verifies that the wrapper executes properly in the native environment,
# properly parses arguments, and reaches the curl binary.

log_info()  { echo "[INFO]  $*" >&2 ; }
log_error() { echo "[ERROR] $*" >&2 ; }

WRAPPER="./scripts/curl-ech-wrapper.sh"

if [[ ! -x "$WRAPPER" ]]; then
    log_error "Wrapper script not found or not executable: $WRAPPER"
    exit 1
fi

# We use the system curl natively, so this validates true behavior.
log_info "1. Testing invalid ECH mode rejection..."
set +e
"$WRAPPER" --ech-mode invalid_mode https://example.com > /dev/null 2>&1
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 0 ]]; then
    log_error "Wrapper failed to reject invalid ECH mode."
    exit 1
fi
log_info "-> Invalid mode cleanly rejected (Exit code: $EXIT_CODE)."

log_info "2. Testing wrapper execution with ECH disabled..."
set +e
"$WRAPPER" --ech-mode false --version > /dev/null
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -ne 0 ]]; then
    log_error "Wrapper failed to execute native curl successfully."
    exit 1
fi
log_info "-> Basic execution passed (Exit code: $EXIT_CODE)."

log_info "Validation successful."
exit 0
