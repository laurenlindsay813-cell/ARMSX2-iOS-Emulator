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

/// Narrow boundary between the SwiftUI app and a separately integrated
/// ARMSX2/PCSX2-derived native core. Implementations must be backed by a real
/// emulator core; this protocol is not itself an emulator.
@MainActor
protocol EmulatorCoreBridge: AnyObject {
    var state: EmulatorRuntimeState { get }
    func loadBIOS(from url: URL) async throws
    func loadGameImage(from url: URL) async throws
    func start() async throws
    func pause()
    func resume()
    func stop()
}

enum EmulatorCoreBridgeError: LocalizedError {
    case coreNotLinked

    var errorDescription: String? {
        switch self {
        case .coreNotLinked:
            return "The PS2 emulation core is not linked into this app yet."
        }
    }
}

/// Safe default used until a real native core adapter is linked. This prevents
/// the UI from claiming a game has started when no CPU/GS/audio runtime exists.
@MainActor
final class UnavailableEmulatorCore: EmulatorCoreBridge {
    private(set) var state: EmulatorRuntimeState =
        .unavailable(reason: "Native PS2 core not linked")

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
    func stop() {}
}
