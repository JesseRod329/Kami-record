# KAMI RECORD Architecture

## Goal

KAMI RECORD is a standalone macOS notch-style voice recorder app.

- Menubar-first (`NSStatusItem`) interaction.
- Top-notch hit window to toggle panel open/close.
- Springboard animation from notch frame to expanded recorder panel.
- Local-only recording with user-selectable output folder.

## Runtime Components

### App Lifecycle

- `KAMIBotApp`: SwiftUI app entry with `@NSApplicationDelegateAdaptor`.
- `AppDelegate`: owns long-lived controllers and app state:
  - `SettingsStore`
  - `RecorderViewModel`
  - `RecorderPanelWindowController`
  - `NotchHitWindowController`
  - `NSStatusItem`

### Windowing and Notch

- `NotchGeometry`: canonical geometry for:
  - notch hit frame
  - collapsed frame
  - expanded panel frame
- `NotchHitWindowController`: transparent borderless window anchored to top center.
  - captures notch clicks
  - toggles panel state
- `RecorderPanelWindowController`: borderless panel host for recorder UI.
  - `expand(from:on:)` springboards from notch frame
  - `collapse(to:on:)` animates back toward notch
- `PanelAnimator`: shared AppKit animation helper.

### Recorder UI

- `RecorderView`:
  - record/stop primary action
  - elapsed timer + level meter
  - save-folder picker
  - open-folder shortcut
  - explicit close button to collapse panel
- `RecorderViewModel`:
  - owns recorder state machine (`idle`, `recording`, `saving`, `error`)
  - updates elapsed timer and synthetic level meter
  - applies output-directory changes at runtime

### Persistence

- `SettingsStore` persists recording output directory path in `UserDefaults`.
- `AudioPipeline.LocalAudioRecorderService`:
  - validates microphone permission
  - records AAC (`.m4a`) files
  - supports runtime output-directory switching
  - exposes latest recording metadata

## Data Flow

1. App launches, sets accessory activation policy.
2. Menubar icon + notch hit window are created.
3. User clicks notch (or menubar icon) to toggle panel.
4. On `Record`, `RecorderViewModel` starts recorder service.
5. Service writes file to configured output directory.
6. On `Stop`, service finalizes file and returns `RecordingArtifact`.
7. ViewModel publishes latest artifact and returns to idle.

## Error Handling

- Microphone denied/restricted -> `AudioPipelineError.microphoneDenied`.
- Invalid output directory -> `AudioRecorderError.invalidOutputDirectory`.
- Save/start failures -> surfaced to view model and shown in UI.
