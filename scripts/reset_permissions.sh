#!/usr/bin/env bash
set -euo pipefail

BUNDLE_ID="io.github.juifemn.pointerpilot"

tccutil reset Accessibility "$BUNDLE_ID" 2>/dev/null || true
tccutil reset ListenEvent "$BUNDLE_ID" 2>/dev/null || true

echo "Reset permissions for $BUNDLE_ID"
