#!/usr/bin/env bash
set -Eeuo pipefail

# ==============================================================================
# Validation Script
# ==============================================================================
# Ensures the wrapper runs without errors when called natively.

log_info()  { echo "[INFO]  $*" >&2 ; }
log_error() { echo "[ERROR] $*" >&2 ; }

WRAPPER="./scripts/curl-ech-wrapper.sh"

if [[ ! -x "$WRAPPER" ]]; then
    log_error "Wrapper script not found or not executable: $WRAPPER"
    exit 1
fi

log_info "Testing invalid ECH mode rejection..."
set +e
"$WRAPPER" --ech-mode invalid_mode https://example.com > /dev/null 2>&1
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 0 ]]; then
    log_error "Wrapper failed to reject invalid ECH mode."
    exit 1
fi
log_info "Invalid ECH mode cleanly rejected."

log_info "Testing wrapper basic execution..."
"$WRAPPER" --ech-mode false --version > /dev/null
log_info "Basic execution passed."

log_info "Validation successful."
exit 0
