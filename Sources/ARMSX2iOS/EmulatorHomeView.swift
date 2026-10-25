import SwiftUI
import UniformTypeIdentifiers

/// Initial iOS front-end shell for the ARMSX2/PCSX2-based emulator.
/// The emulation core must be linked and wired into this view before games can run.
struct EmulatorHomeView: View {
    @State private var showingBIOSPicker = false
    @State private var showingGamePicker = false
    @State private var biosName: String?
    @State private var gameName: String?
    @State private var statusMessage = "Emulation core is not connected yet."
    @State private var isShowingStatus = false

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
                        Label("Controls", systemImage: "gamecontroller")
                            .font(.headline)
                        Text("Touch controls and external controllers will be enabled when the emulation core is integrated.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
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
                        Text("Game launching is intentionally unavailable until CPU, GS graphics, audio, DMA and BIOS boot are connected and tested.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
                .padding()
            }
            .navigationTitle("ARMSX2")
            .navigationBarTitleDisplayMode(.inline)
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

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(.tint)
            Text("PlayStation 2 Emulator")
                .font(.title2.bold())
            Text("iPhone front-end • ARM64")
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
        UTType(filenameExtension: "chd") ?? .data
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
            } else {
                gameName = destination.lastPathComponent
            }
            statusMessage = "\(category) imported into the app's private storage. The emulator core is still required to use it."
            isShowingStatus = true
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
