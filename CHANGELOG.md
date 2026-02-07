# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog and this project uses Semantic Versioning.

## [Unreleased]

### Added
- Initial repository governance, licensing, and CI baseline.
- Modular Swift package scaffold for app, agent, audio, model, UI, and vision layers.
- Baseline local test harness via `scripts/test.sh` running package `xcodebuild` tests.
- Tahoe-first glass-surface UI with fallback styling and floating desktop window behavior.
- Microphone permission-gated audio startup coordinator for wake-word and STT flow.
- Model runtime bootstrap with first-run downloader, hash verification, and persona prompt builder.
- Agent loop timeout and cancellation controls with deterministic recovery to `idle`.
- Persona-driven face expression mapping and interruption-safe TTS output behavior.
- Settings panel, startup validation gates, and hardened release-preview packaging workflow.
- Vision v1.1 foundation with feature-flagged on-demand frame capture wiring.
