#!/usr/bin/env bash
# Lance ensemble les composants du projet. Ctrl+C les arrête tous.
set -euo pipefail

cd "$(dirname "$0")/.."

trap 'kill 0' EXIT

{{lancements}}

wait
