#!/usr/bin/env bash
# Runs the python-compliance-logger end-to-end tests (stdlib only).
set -euo pipefail
cd "$(dirname "$0")"
python3 -m unittest discover -s tests -t . -v
