import AVFoundation
import Foundation

/// IMPORTANTE: vídeo é apenas fonte de áudio. Não guarda quadros de vídeo.
@MainActor
extension LocalStore {
    func importMedia(from source: URL, keepAudio: Bool = false) async throws -> PendingImport {
        let ext = source.pathExtension.lowercased()
        if Self.videoExtensions.contains(ext) {
            return try await importVideoAudio(from: source, keepAudio: keepAudio)
        }
        return try importAudio(from: source, keepAudio: keepAudio)
    }

    private func importVideoAudio(from source: URL, keepAudio: Bool) async throws -> PendingImport {
        guard pending == nil else { throw MorvanError.pendingExists }
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }

        let item = PendingImport(
            id: UUID(), audioExtension: "m4a", contactName: "", phoneNumber: "",
            occurredAt: Date(), origin: .otherVideo, keepAudio: keepAudio,
            transcribedText: nil, hasSpeakerLabels: false)
        let output = temporaryURL(for: item)
        let asset = AVURLAsset(url: source)
        guard let exporter = AVAssetExportSession(
            asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw MorvanError.serverMessage("Este vídeo não contém áudio compatível com o iPhone.")
        }
        exporter.outputURL = output
        exporter.outputFileType = .m4a
        exporter.shouldOptimizeForNetworkUse = false
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                exporter.exportAsynchronously {
                    switch exporter.status {
                    case .completed:
                        continuation.resume()
                    case .cancelled:
                        continuation.resume(throwing: CancellationError())
                    default:
                        continuation.resume(throwing: exporter.error ??
                            MorvanError.serverMessage("Não foi possível extrair o áudio deste vídeo."))
                    }
                }
            }
            let size = try output.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size > 0 else { throw MorvanError.invalidAudio }
            guard size <= Self.maxAudioBytes else { throw MorvanError.audioTooLarge }
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.complete], ofItemAtPath: output.path)
            try setPending(item)
            return item
        } catch {
            try? FileManager.default.removeItem(at: output)
            throw error
        }
    }
}
