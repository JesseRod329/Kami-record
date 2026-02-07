import AppKit
import AudioPipeline
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settingsStore: SettingsStore
    let recorderViewModel: RecorderViewModel

    private let recorderService: LocalAudioRecorderService
    private var panelController: RecorderPanelWindowController?
    private var notchHitController: NotchHitWindowController?
    private var statusItem: NSStatusItem?
    private var screenObserver: NSObjectProtocol?

    override init() {
        self.settingsStore = SettingsStore()
        self.recorderService = LocalAudioRecorderService(outputDirectory: settingsStore.recordingsDirectoryURL)
        self.recorderViewModel = RecorderViewModel(recorderService: recorderService)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)

        let rootView = AnyView(
            RecorderView(
                viewModel: recorderViewModel,
                settingsStore: settingsStore,
                onRequestClose: { [weak self] in
                    self?.collapsePanel()
                }
            )
            .frame(width: NotchGeometry.panelSize.width, height: NotchGeometry.panelSize.height)
        )

        panelController = RecorderPanelWindowController(rootView: rootView)
        notchHitController = NotchHitWindowController(onTap: { [weak self] in
            self?.togglePanel()
        })
        notchHitController?.show(on: NSScreen.main)

        configureStatusItem()
        configureObservers()

        Task {
            await recorderViewModel.setOutputDirectory(settingsStore.recordingsDirectoryURL)
            await recorderViewModel.refreshLatestRecording()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
    }

    @objc private func togglePanelAction() {
        togglePanel()
    }

    private func togglePanel() {
        panelController?.isVisible == true ? collapsePanel() : expandPanel()
    }

    private func expandPanel() {
        guard let panelController else { return }
        let screen = statusItem?.button?.window?.screen ?? NSScreen.main
        let notchFrame = notchHitController?.currentFrame
            ?? (screen.map { NotchGeometry.notchFrame(on: $0) } ?? .zero)
        panelController.expand(from: notchFrame, on: screen)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func collapsePanel() {
        guard let panelController else { return }
        let screen = statusItem?.button?.window?.screen ?? NSScreen.main
        let notchFrame = notchHitController?.currentFrame
            ?? (screen.map { NotchGeometry.notchFrame(on: $0) } ?? .zero)
        panelController.collapse(to: notchFrame, on: screen)
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = item.button else {
            return
        }

        button.image = Self.statusIcon()
        button.imagePosition = .imageOnly
        button.action = #selector(togglePanelAction)
        button.target = self
        button.toolTip = "KAMI RECORD"

        statusItem = item
    }

    private func configureObservers() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }
                self.notchHitController?.updateFrame(on: NSScreen.main)
                self.panelController?.reposition(on: NSScreen.main)
            }
        }
    }

    private static func statusIcon() -> NSImage {
        if let logo = Bundle.module.imageResource(named: "kami-record-logo") {
            logo.size = NSSize(width: 18, height: 18)
            return logo
        }

        if let symbol = NSImage(systemSymbolName: "waveform", accessibilityDescription: "KAMI RECORD") {
            symbol.size = NSSize(width: 16, height: 16)
            return symbol
        }

        return NSImage()
    }
}

private extension Bundle {
    func imageResource(named name: String) -> NSImage? {
        guard let url = url(forResource: name, withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }
}
