#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
if [[ -d .venv ]]; then
  # shellcheck disable=SC1091
  source .venv/bin/activate
fi
exec python ship_zendesk_to_coralogix.py --once --lookback-minutes 5
