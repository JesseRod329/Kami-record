#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
open -a Xcode "$ROOT_DIR/KAMIBotApp/Package.swift"
