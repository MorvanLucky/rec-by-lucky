import Foundation

/// Armazenamento local. Nenhuma transcrição é enviada à nuvem do aplicativo.
/// Dados e áudios são excluídos do backup e usam FileProtection completo.
@MainActor
final class LocalStore {
    static let supportedExtensions: Set<String> = [
        "m4a", "mp3", "wav", "caf"
    ]
    static let maxAudioBytes = 100 * 1024 * 1024
    static let videoExtensions: Set<String> = ["mp4", "mov", "m4v"]

    private let manager = FileManager.default
    private let root: URL
    private let pendingDir: URL
    private let retainedDir: URL
    private let conversationsURL: URL
    private let pendingRecordURL: URL

    private(set) var conversations: [Conversation] = []
    private(set) var pending: PendingImport?

    init(rootURL: URL? = nil) throws {
        let appSupport = try manager.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true)
        root = rootURL ?? appSupport.appendingPathComponent("Morvan", isDirectory: true)
        pendingDir = root.appendingPathComponent("Temporarios", isDirectory: true)
        retainedDir = root.appendingPathComponent("Audios", isDirectory: true)
        conversationsURL = root.appendingPathComponent("conversas.json")
        pendingRecordURL = root.appendingPathComponent("pendente.json")

        for dir in [root, pendingDir, retainedDir] {
            try manager.createDirectory(at: dir, withIntermediateDirectories: true)
            try manager.setAttributes(
                [.protectionKey: FileProtectionType.complete],
                ofItemAtPath: dir.path)
        }
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableRoot = root
        try mutableRoot.setResourceValues(values)
        conversations = try readJSON([Conversation].self, from: conversationsURL) ?? []
        pending = try readJSON(PendingImport.self, from: pendingRecordURL)
        // Recupera arquivos órfãos após interrupções.
        try purgeOrphanRetainedAudio()
        try purgeOrphanTemporaryAudio()
    }

    private func readJSON<T: Decodable>(_ type: T.Type, from url: URL) throws -> T? {
        guard manager.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }

    private func writeJSON<T: Encodable>(_ content: T, to url: URL) throws {
        let data = try JSONEncoder().encode(content)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        try manager.setAttributes([.protectionKey: FileProtectionType.complete],
                                  ofItemAtPath: url.path)
    }

    private func writeConversations(_ values: [Conversation]) throws {
        try writeJSON(values, to: conversationsURL)
        // Confirma o conteúdo efetivamente legível antes de liberar a limpeza.
        guard let saved = try readJSON([Conversation].self, from: conversationsURL),
              saved == values else {
            throw MorvanError.serverMessage("Não foi possível confirmar o texto salvo. O áudio temporário foi preservado.")
        }
        conversations = values
    }

    func setPending(_ value: PendingImport?) throws {
        if let value {
            try writeJSON(value, to: pendingRecordURL)
        } else if manager.fileExists(atPath: pendingRecordURL.path) {
            try manager.removeItem(at: pendingRecordURL)
        }
        pending = value
    }

    func temporaryURL(for pending: PendingImport) -> URL {
        pendingDir.appendingPathComponent("\(pending.id.uuidString).\(pending.audioExtension)")
    }

    func retainedURL(for conversation: Conversation) -> URL? {
        guard let filename = conversation.audioFileName else { return nil }
        return retainedDir.appendingPathComponent(filename)
    }

    func importAudio(from externalURL: URL, keepAudio: Bool) throws -> PendingImport {
        guard pending == nil else { throw MorvanError.pendingExists }
        let ext = externalURL.pathExtension.lowercased()
        guard Self.supportedExtensions.contains(ext) else { throw MorvanError.invalidAudio }

        let scoped = externalURL.startAccessingSecurityScopedResource()
        defer { if scoped { externalURL.stopAccessingSecurityScopedResource() } }
        let fileSize = try externalURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard fileSize > 0 else { throw MorvanError.invalidAudio }
        guard fileSize <= Self.maxAudioBytes else { throw MorvanError.audioTooLarge }

        let item = PendingImport(
            id: UUID(), audioExtension: ext, contactName: "",
            phoneNumber: "", occurredAt: Date(), origin: .inPerson,
            keepAudio: keepAudio, transcribedText: nil, hasSpeakerLabels: false)
        let destination = temporaryURL(for: item)
        try manager.copyItem(at: externalURL, to: destination)
        do {
            try manager.setAttributes([.protectionKey: FileProtectionType.complete],
                                      ofItemAtPath: destination.path)
            try setPending(item)
        } catch {
            try? manager.removeItem(at: destination)
            throw error
        }
        return item
    }

    /// Depois que o texto foi persistido, o áudio temporário é excluído.
    /// Uma falha de exclusão mantém o registro pendente para nova tentativa.
    @discardableResult
    func finalizePending() throws -> Conversation {
        guard let item = pending else { throw MorvanError.noPending }
        guard let text = item.transcribedText, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { throw MorvanError.emptyText }

        if let previous = conversations.first(where: { $0.id == item.id }) {
            guard let saved = try readJSON([Conversation].self, from: conversationsURL),
                  saved.contains(previous) else {
                throw MorvanError.serverMessage("Não foi possível confirmar a transcrição salva. Tente novamente; o áudio temporário foi preservado.")
            }
            try cleanupPendingFile()
            return previous
        }

        let source = temporaryURL(for: item)
        let retainedName = "\(item.id.uuidString).\(item.audioExtension)"
        let destination = retainedDir.appendingPathComponent(retainedName)
        if item.keepAudio && !manager.fileExists(atPath: destination.path) {
            // Copia antes de persistir: se a gravação do JSON falhar, o original
            // temporário continua disponível para tentar novamente.
            try manager.copyItem(at: source, to: destination)
            try manager.setAttributes([.protectionKey: FileProtectionType.complete],
                                      ofItemAtPath: destination.path)
        }

        let now = Date()
        let value = Conversation(
            id: item.id, contactName: item.contactName,
            phoneNumber: item.phoneNumber, occurredAt: item.occurredAt,
            origin: item.origin, transcript: text,
            audioFileName: item.keepAudio ? retainedName : nil,
            hasSpeakerLabels: item.hasSpeakerLabels,
            summary: nil, decisions: [], tasks: [],
            createdAt: now, updatedAt: now)
        // Em falha, preserva as cópias: a escrita pode ter ocorrido mesmo
        // quando a confirmação falha. Órfãos são limpos na reabertura.
        try writeConversations(conversations + [value])
        try cleanupPendingFile()
        return value
    }

    func cleanupPendingFile() throws {
        guard let item = pending else { return }
        let source = temporaryURL(for: item)
        if manager.fileExists(atPath: source.path) {
            try manager.removeItem(at: source)
        }
        try setPending(nil)
    }

    /// Somente para falha/cancelamento antes de persistir o texto, ou para
    /// concluir a limpeza de uma transcrição já persistida.
    func discardPending() throws {
        try cleanupPendingFile()
    }

    func upsert(_ conversation: Conversation) throws {
        var copy = conversations
        var updated = conversation
        updated.updatedAt = Date()
        if let position = copy.firstIndex(where: { $0.id == updated.id }) {
            copy[position] = updated
        } else {
            copy.append(updated)
        }
        try writeConversations(copy)
    }

    func deleteAudio(for conversation: Conversation) throws {
        guard let url = retainedURL(for: conversation) else { return }
        var updated = conversation
        updated.audioFileName = nil
        try upsert(updated)
        // Se a remoção falhar, um arquivo órfão será eliminado na inicialização.
        try manager.removeItem(at: url)
    }

    func deleteConversation(_ conversation: Conversation) throws {
        try writeConversations(conversations.filter { $0.id != conversation.id })
        if let url = retainedURL(for: conversation),
           manager.fileExists(atPath: url.path) {
            try manager.removeItem(at: url)
        }
    }

    func purgeOrphanTemporaryAudio() throws {
        let activeName = pending.map { "\($0.id.uuidString).\($0.audioExtension)" }
        for file in try manager.contentsOfDirectory(
            at: pendingDir, includingPropertiesForKeys: nil) where file.lastPathComponent != activeName {
            try manager.removeItem(at: file)
        }
    }

    func purgeOrphanRetainedAudio() throws {
        let names = Set(conversations.compactMap(\.audioFileName))
        for file in try manager.contentsOfDirectory(
            at: retainedDir, includingPropertiesForKeys: nil) where !names.contains(file.lastPathComponent) {
            try manager.removeItem(at: file)
        }
    }
}
