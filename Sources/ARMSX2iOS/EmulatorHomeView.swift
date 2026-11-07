import SwiftUI
import UniformTypeIdentifiers

/// Initial iOS front-end shell for the ARMSX2/PCSX2-based emulator.
/// The emulation core must be linked and wired into this view before games can run.
struct EmulatorHomeView: View {
    @State private var showingBIOSPicker = false
    @State private var showingGamePicker = false
    @State private var biosName: String?
    @State private var gameName: String?
    @State private var selectedBIOSURL: URL?
    @State private var selectedGameURL: URL?
    @State private var statusMessage = "ARMSX2 is ready for BIOS and game selection."
    @State private var isShowingStatus = false
    @State private var isLaunching = false
    @State private var framePacingEnabled = true
    @State private var performanceOverlayEnabled = true
    @State private var preferredMode = "Balanced"
    @State private var core = PlayableEmulatorCore()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header

                    Group {
                        fileRow(
                            title: "PlayStation 2 BIOS",
                            detail: biosName ?? "Choose your legally obtained BIOS file",
                            systemImage: "cpu",
                            actionTitle: "Choose BIOS",
                            action: { showingBIOSPicker = true }
                        )
                        fileRow(
                            title: "Game image",
                            detail: gameName ?? "ISO, BIN, IMG or CHD",
                            systemImage: "opticaldisc",
                            actionTitle: "Import game",
                            action: { showingGamePicker = true }
                        )
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Label("Performance", systemImage: "speedometer")
                            .font(.headline)

                        Picker("Mode", selection: $preferredMode) {
                            Text("Balanced").tag("Balanced")
                            Text("Performance").tag("Performance")
                            Text("Battery").tag("Battery")
                        }
                        .pickerStyle(.segmented)

                        Toggle("Frame pacing", isOn: $framePacingEnabled)
                        Toggle("Performance overlay", isOn: $performanceOverlayEnabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Runtime status", systemImage: "waveform.path")
                            .font(.headline)
                        Text(statusMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Core state: \(core.state.displayName)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        if selectedBIOSURL != nil && selectedGameURL != nil {
                            Button(isLaunching ? "Launching..." : "Launch game") {
                                launchGame()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isLaunching || !core.canLaunch)
                        } else {
                            Text("Select a BIOS and a game image to prepare the emulator.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

                    VStack(alignment: .leading, spacing: 12) {
                        Label("ARMSX2 design", systemImage: "sparkles")
                            .font(.headline)
                        Text("Optimized around fast mobile launch, touch-centric controls, and cleaner boot diagnostics instead of a generic emulator dashboard.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
                .padding()
            }
            .navigationTitle("ARMSX2")
            .fileImporter(
                isPresented: $showingBIOSPicker,
                allowedContentTypes: [.item],
                allowsMultipleSelection: false,
                onCompletion: { result in
                    handleImport(result, category: "BIOS")
                }
            )
            .fileImporter(
                isPresented: $showingGamePicker,
                allowedContentTypes: Self.gameImageTypes,
                allowsMultipleSelection: false,
                onCompletion: { result in
                    handleImport(result, category: "Games")
                }
            )
            .alert("Import status", isPresented: $isShowingStatus) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(statusMessage)
            }
        }
    }

    private func launchGame() {
        guard let biosURL = selectedBIOSURL, let gameURL = selectedGameURL else {
            statusMessage = "Add a BIOS and game image before launching."
            isShowingStatus = true
            return
        }

        isLaunching = true
        statusMessage = "Preparing ARMSX2 launch..."

        Task {
            do {
                let config = EmulatorLaunchConfiguration(
                    biosURL: biosURL,
                    gameURL: gameURL,
                    preferredMode: preferredMode,
                    saveStateDirectory: nil,
                    framePacingEnabled: framePacingEnabled,
                    performanceOverlayEnabled: performanceOverlayEnabled
                )

                try await core.configure(config)
                try await core.start()

                statusMessage = "Booting \(gameName ?? "game") into the emulator runtime."
                isShowingStatus = true
            } catch {
                statusMessage = error.localizedDescription
                isShowingStatus = true
            }

            isLaunching = false
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(.tint)
            Text("ARMSX2 Studio")
                .font(.title2.bold())
            Text("PS2 emulator front-end • mobile-first")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private func fileRow(
        title: String,
        detail: String,
        systemImage: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Button(actionTitle, action: action)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private static let gameImageTypes: [UTType] = [
        UTType(filenameExtension: "iso") ?? .data,
        UTType(filenameExtension: "bin") ?? .data,
        UTType(filenameExtension: "img") ?? .data,
        UTType(filenameExtension: "chd") ?? .data,
        UTType(filenameExtension: "cue") ?? .data,
        UTType(filenameExtension: "cso") ?? .data
    ]

    private func handleImport(_ result: Result<[URL], Error>, category: String) {
        do {
            guard let sourceURL = try result.get().first else { return }
            let didAccess = sourceURL.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    sourceURL.stopAccessingSecurityScopedResource()
                }
            }

            let folder = try Self.appSupportDirectory()
                .appendingPathComponent(category, isDirectory: true)
            try FileManager.default.createDirectory(
                at: folder,
                withIntermediateDirectories: true
            )

            let destination = Self.uniqueDestination(
                for: sourceURL.lastPathComponent,
                in: folder
            )
            try FileManager.default.copyItem(at: sourceURL, to: destination)

            if category == "BIOS" {
                biosName = destination.lastPathComponent
                selectedBIOSURL = destination
            } else {
                gameName = destination.lastPathComponent
                selectedGameURL = destination
            }

            statusMessage = "\(category) imported successfully."
            isShowingStatus = true

            if let biosURL = selectedBIOSURL, let gameURL = selectedGameURL {
                Task {
                    do {
                        let config = EmulatorLaunchConfiguration(
                            biosURL: biosURL,
                            gameURL: gameURL,
                            preferredMode: preferredMode,
                            saveStateDirectory: nil,
                            framePacingEnabled: framePacingEnabled,
                            performanceOverlayEnabled: performanceOverlayEnabled
                        )
                        try await core.configure(config)
                        statusMessage = "Core ready for launch."
                        isShowingStatus = true
                    } catch {
                        statusMessage = error.localizedDescription
                        isShowingStatus = true
                    }
                }
            }
        } catch {
            statusMessage = "Import failed: \(error.localizedDescription)"
            isShowingStatus = true
        }
    }

    private static func appSupportDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return base.appendingPathComponent("ARMSX2", isDirectory: true)
    }

    private static func uniqueDestination(for name: String, in folder: URL) -> URL {
        let initial = folder.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: initial.path) else {
            return initial
        }

        let source = URL(fileURLWithPath: name)
        let stem = source.deletingPathExtension().lastPathComponent
        let ext = source.pathExtension
        var index = 2
        while true {
            let candidateName = ext.isEmpty
                ? "\(stem)-\(index)"
                : "\(stem)-\(index).\(ext)"
            let candidate = folder.appendingPathComponent(candidateName)
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            index += 1
        }
    }
}
