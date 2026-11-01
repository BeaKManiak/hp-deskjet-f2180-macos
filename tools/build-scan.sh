#!/bin/bash
# build-scan.sh - compile the CLI scanner (needs Xcode Command Line Tools).
set -euo pipefail
cd "$(dirname "$0")"
xcrun --find swiftc >/dev/null 2>&1 || { echo "error: install Xcode Command Line Tools: xcode-select --install" >&2; exit 1; }
swiftc -O f2180-scan.swift -o f2180-scan
echo "built $PWD/f2180-scan"
