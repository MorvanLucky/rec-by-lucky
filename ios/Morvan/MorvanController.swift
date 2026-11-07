import Foundation
import Combine

@MainActor
final class MorvanController: ObservableObject {
    @Published private(set) var conversations: [Conversation] = []
    @Published private(set) var pending: PendingImport?
    @Published var isBusy = false
    @Published var errorMessage: String?

    private let storage: LocalStore?

    init() {
        do {
            storage = try LocalStore()
            refresh()
        } catch {
            storage = nil
            errorMessage = "Falha ao abrir o armazenamento privado: \(error.localizedDescription)"
        }
    }

    func refresh() {
        conversations = storage?.conversations.sorted(by: { $0.occurredAt > $1.occurredAt }) ?? []
        pending = storage?.pending
    }

    func importMedia(_ url: URL) async {
        guard !isBusy, let storage else { return }
        isBusy = true
        defer { isBusy = false; refresh() }
        do {
            _ = try await storage.importMedia(from: url, keepAudio: false)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updatePending(_ updated: PendingImport) throws {
        guard !isBusy, let storage else {
            throw MorvanError.serverMessage("Aguarde o processamento e tente novamente.")
        }
        try storage.setPending(updated)
        refresh()
    }

    func transcribePending() async -> Bool {
        guard !isBusy, let storage, var item = storage.pending else { return false }
        isBusy = true
        defer { isBusy = false; refresh() }
        do {
            if item.transcribedText == nil {
                let result = try await OfflineSpeechService().transcribe(
                    audioURL: storage.temporaryURL(for: item))
                guard !result.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                else { throw MorvanError.emptyText }
                item.transcribedText = result.text
                item.hasSpeakerLabels = result.speakerLabels
                try storage.setPending(item) // registro da transcrição antes da exclusão
            }
            _ = try storage.finalizePending() // commit JSON → delete áudio
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func discardPending() {
        guard !isBusy else { return }
        do { try storage?.discardPending(); refresh() }
        catch { errorMessage = error.localizedDescription }
    }

    func update(_ conversation: Conversation) {
        do {
            guard let storage else { return }
            var edited = conversation
            if let previous = storage.conversations.first(where: { $0.id == edited.id }),
               previous.transcript != edited.transcript {
                // A análise antiga não é válida após editar a transcrição.
                edited.summary = nil
                edited.decisions = []
                edited.tasks = []
            }
            try storage.upsert(edited)
            refresh()
        } catch { errorMessage = error.localizedDescription }
    }

    func delete(_ conversation: Conversation) {
        do { try storage?.deleteConversation(conversation); refresh() }
        catch { errorMessage = error.localizedDescription; refresh() }
    }

    func deleteAudio(_ conversation: Conversation) {
        do { try storage?.deleteAudio(for: conversation); refresh() }
        catch { errorMessage = error.localizedDescription; refresh() }
    }

    func localAudioURL(for conversation: Conversation) -> URL? {
        guard let url = storage?.retainedURL(for: conversation),
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    func analyze(_ conversation: Conversation) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let result = try await OfflineAnalysisService().analyze(text: conversation.transcript)
            guard var current = storage?.conversations.first(where: { $0.id == conversation.id })
            else { return }
            // Evita associar um resumo de versão antiga após mudanças no texto.
            guard current.transcript == conversation.transcript else { return }
            current.summary = result.summary
            current.decisions = result.decisions
            current.tasks = result.tasks
            try storage?.upsert(current)
            refresh()
        } catch { errorMessage = error.localizedDescription }
    }
}
