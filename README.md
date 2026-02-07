# KAMI RECORD

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![CI](https://img.shields.io/github/actions/workflow/status/JesseRod329/Kami-record/ci.yml?branch=main&label=CI)
![macOS](https://img.shields.io/badge/macOS-14%2B-111111)
![Tahoe](https://img.shields.io/badge/Enhanced%20for-macOS%2026%20Tahoe-007AFF)
![Swift](https://img.shields.io/badge/Swift-5.10%2B-orange)
![Open Source](https://img.shields.io/badge/Open%20Source-Yes-00A86B)

KAMI RECORD is a privacy-first, notch-style macOS recorder for instant voice memos and melody ideas.

<p align="center">
  <img src="./Gemini_Generated_Image_fzrmg9fzrmg9fzrm.png" alt="KAMI RECORD logo" width="360" />
</p>

## Features

- One-tap `Record` / `Stop` capture flow.
- Notch-inspired floating liquid-glass UI.
- Local-first capture storage in `captures/`.
- Mic-permission aware startup and error handling.
- Quick recorder mode plus existing BMO mode toggle.

## Project Layout

- `KAMIBotApp/`: SwiftUI app shell and recorder/BMO view models.
- `Packages/AudioPipeline/`: recorder service, microphone permission, STT/TTS services.
- `Packages/CoreAgent/`: shared agent state and protocols.
- `Packages/UIComponents/`: glass UI components and face visuals.
- `Packages/ModelRuntime/`: local model runtime lifecycle.
- `Packages/VisionPipeline/`: optional snapshot vision services.

## Run Locally

### Requirements

- macOS 14+
- Xcode 16+

### Build

```bash
swift build --package-path KAMIBotApp
```

### Test

```bash
./scripts/test.sh
```

### Run

```bash
swift run --package-path KAMIBotApp
```

## CI

GitHub Actions runs:

- `lint` (`./scripts/lint.sh`)
- `build` (`swift build --package-path KAMIBotApp`)
- `test` (`./scripts/test.sh`)

## Contributing

See `CONTRIBUTING.md`.

## Security

See `SECURITY.md`.

## License

MIT. See `LICENSE`.
