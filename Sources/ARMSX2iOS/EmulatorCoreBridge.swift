import Foundation

/// Lifecycle reported by a real PS2 core adapter.
enum EmulatorRuntimeState: Equatable {
    case unavailable(reason: String)
    case ready
    case booting
    case running
    case paused
    case failed(reason: String)
}

struct EmulatorLaunchConfiguration {
    var biosURL: URL?
    var gameURL: URL?
    var preferredMode: String
    var saveStateDirectory: URL?
    var framePacingEnabled: Bool
    var performanceOverlayEnabled: Bool
}

enum EmulatorCoreBridgeError: LocalizedError {
    case coreNotLinked
    case missingBIOS
    case missingGameImage
    case invalidBIOS
    case invalidGameImage
    case coreBootFailed(String)

    var errorDescription: String? {
        switch self {
        case .coreNotLinked:
            return "The PS2 emulation core is not linked into this app yet."
        case .missingBIOS:
            return "A valid PS2 BIOS is required before launching a game."
        case .missingGameImage:
            return "A PS2 game image is required before launching."
        case .invalidBIOS:
            return "The selected BIOS file is not a valid PS2 BIOS image."
        case .invalidGameImage:
            return "The selected game file is not a supported PS2 disc image."
        case .coreBootFailed(let message):
            return message
        }
    }
}

@MainActor
protocol EmulatorCoreBridge: AnyObject {
    var state: EmulatorRuntimeState { get }
    var lastError: EmulatorCoreBridgeError? { get }
    var canLaunch: Bool { get }

    func configure(_ config: EmulatorLaunchConfiguration) async throws
    func loadBIOS(from url: URL) async throws
    func loadGameImage(from url: URL) async throws
    func start() async throws
    func pause()
    func resume()
    func stop()
}

/// A lightweight, mobile-first emulator core shell that gives the app a real
/// runtime lifecycle without pretending it is a full PS2 core implementation.
/// This is intentionally designed as the integration point for a real native core
/// while keeping the app usable and testable in a realistic way.
@MainActor
final class PlayableEmulatorCore: EmulatorCoreBridge {
    private(set) var state: EmulatorRuntimeState = .ready
    private(set) var lastError: EmulatorCoreBridgeError?

    private var biosURL: URL?
    private var gameURL: URL?
    private var preferredMode: String = "Balanced"
    private var framePacingEnabled = true
    private var performanceOverlayEnabled = true

    var canLaunch: Bool {
        switch state {
        case .ready, .paused:
            return biosURL != nil && gameURL != nil
        default:
            return false
        }
    }

    func configure(_ config: EmulatorLaunchConfiguration) async throws {
        self.biosURL = config.biosURL
        self.gameURL = config.gameURL
        self.preferredMode = config.preferredMode
        self.framePacingEnabled = config.framePacingEnabled
        self.performanceOverlayEnabled = config.performanceOverlayEnabled

        if config.biosURL == nil {
            throw EmulatorCoreBridgeError.missingBIOS
        }
        if config.gameURL == nil {
            throw EmulatorCoreBridgeError.missingGameImage
        }

        try await loadBIOS(from: config.biosURL!)
        try await loadGameImage(from: config.gameURL!)
        state = .ready
        lastError = nil
    }

    func loadBIOS(from url: URL) async throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw EmulatorCoreBridgeError.invalidBIOS
        }

        let ext = url.pathExtension.lowercased()
        let allowedExts = ["bin", "rom", "bios", "scph", "ps2"]
        guard ext.isEmpty || allowedExts.contains(ext) else {
            throw EmulatorCoreBridgeError.invalidBIOS
        }

        biosURL = url
        state = .ready
        lastError = nil
    }

    func loadGameImage(from url: URL) async throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw EmulatorCoreBridgeError.invalidGameImage
        }

        let ext = url.pathExtension.lowercased()
        let allowedExts = ["iso", "bin", "img", "chd", "cue", "cso", "elf"]
        guard ext.isEmpty || allowedExts.contains(ext) else {
            throw EmulatorCoreBridgeError.invalidGameImage
        }

        gameURL = url
        state = .ready
        lastError = nil
    }

    func start() async throws {
        guard let biosURL, let gameURL else {
            throw EmulatorCoreBridgeError.missingBIOS
        }

        if biosURL.path.isEmpty || gameURL.path.isEmpty {
            throw EmulatorCoreBridgeError.coreBootFailed("The selected BIOS or game is missing.")
        }

        state = .booting
        lastError = nil

        do {
            try await Task.sleep(nanoseconds: 150_000_000)
            state = .running
        } catch {
            state = .failed(reason: "Boot sequence interrupted.")
            lastError = .coreBootFailed("Boot sequence interrupted.")
            throw lastError!
        }
    }

    func pause() {
        if state == .running {
            state = .paused
        }
    }

    func resume() {
        if state == .paused {
            state = .running
        }
    }

    func stop() {
        state = .ready
        lastError = nil
    }
}

@MainActor
final class UnavailableEmulatorCore: EmulatorCoreBridge {
    private(set) var state: EmulatorRuntimeState = .unavailable(reason: "Native PS2 core not linked")
    private(set) var lastError: EmulatorCoreBridgeError? = .coreNotLinked

    var canLaunch: Bool { false }

    func configure(_ config: EmulatorLaunchConfiguration) async throws {
        throw EmulatorCoreBridgeError.coreNotLinked
    }

    func loadBIOS(from url: URL) async throws {
        throw EmulatorCoreBridgeError.coreNotLinked
    }

    func loadGameImage(from url: URL) async throws {
        throw EmulatorCoreBridgeError.coreNotLinked
    }

    func start() async throws {
        throw EmulatorCoreBridgeError.coreNotLinked
    }

    func pause() {}
    func resume() {}
    func stop() {
        state = .unavailable(reason: "Native PS2 core not linked")
    }
}
