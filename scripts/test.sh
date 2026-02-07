#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

run_package_tests() {
  local package_dir="$1"
  local scheme="$2"

  if [ ! -d "$package_dir" ]; then
    return 0
  fi

  (
    cd "$package_dir"
    xcodebuild test \
      -scheme "$scheme" \
      -destination 'platform=macOS,arch=arm64' \
      -quiet
  )
}

run_package_tests "Packages/CoreAgent" "CoreAgent"
run_package_tests "Packages/AudioPipeline" "AudioPipeline"
run_package_tests "Packages/ModelRuntime" "ModelRuntime"
run_package_tests "Packages/UIComponents" "UIComponents"
run_package_tests "Packages/VisionPipeline" "VisionPipeline"
run_package_tests "KAMIBotApp" "KAMIBotApp"
