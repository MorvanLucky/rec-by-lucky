import XCTest
@testable import Morvan

@MainActor
final class LocalStoreTests: XCTestCase {
    private func makeStore() throws -> (LocalStore, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MorvanTests-\(UUID().uuidString)", isDirectory: true)
        return (try LocalStore(rootURL: root), root)
    }

    private func makeAudio() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).m4a")
        try Data("audio de teste".utf8).write(to: url)
        return url
    }

    func testAudioDiscardLeavesOriginalUntouched() throws {
        let (store, folder) = try makeStore()
        let original = try makeAudio()
        defer {
            try? FileManager.default.removeItem(at: original)
            try? FileManager.default.removeItem(at: folder)
        }
        let pending = try store.importAudio(from: original, keepAudio: false)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.temporaryURL(for: pending).path))
        try store.discardPending()
        XCTAssertNil(store.pending)
        XCTAssertTrue(FileManager.default.fileExists(atPath: original.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.temporaryURL(for: pending).path))
    }

    func testDefaultDeletesAudioOnlyAfterTranscriptSaved() throws {
        let (store, folder) = try makeStore()
        let original = try makeAudio()
        defer {
            try? FileManager.default.removeItem(at: original)
            try? FileManager.default.removeItem(at: folder)
        }
        var pending = try store.importAudio(from: original, keepAudio: false)
        XCTAssertFalse(pending.keepAudio)
        pending.transcribedText = "Olá, esta é a transcrição."
        try store.setPending(pending)
        let conversation = try store.finalizePending()
        XCTAssertNil(conversation.audioFileName)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.temporaryURL(for: pending).path))
        XCTAssertEqual(store.conversations.count, 1)
        XCTAssertEqual(store.conversations.first?.transcript, pending.transcribedText)

        let reopened = try LocalStore(rootURL: folder)
        XCTAssertNil(reopened.pending)
        XCTAssertEqual(reopened.conversations.first?.transcript, pending.transcribedText)
    }

    func testKeepAudioThenDeleteOnlyAudio() throws {
        let (store, folder) = try makeStore()
        let original = try makeAudio()
        defer {
            try? FileManager.default.removeItem(at: original)
            try? FileManager.default.removeItem(at: folder)
        }
        var pending = try store.importAudio(from: original, keepAudio: true)
        pending.transcribedText = "Texto salvo sem perder o áudio."
        try store.setPending(pending)
        let conversation = try store.finalizePending()
        let savedURL = try XCTUnwrap(store.retainedURL(for: conversation))
        XCTAssertTrue(FileManager.default.fileExists(atPath: savedURL.path))
        try store.deleteAudio(for: conversation)
        XCTAssertFalse(FileManager.default.fileExists(atPath: savedURL.path))
        XCTAssertNil(store.conversations.first?.audioFileName)
        XCTAssertEqual(store.conversations.first?.transcript, conversation.transcript)
        XCTAssertTrue(FileManager.default.fileExists(atPath: original.path))
    }

    func testPendingCanBeRecoveredAfterRestart() throws {
        let (store, folder) = try makeStore()
        let original = try makeAudio()
        defer {
            try? FileManager.default.removeItem(at: original)
            try? FileManager.default.removeItem(at: folder)
        }
        var pending = try store.importAudio(from: original, keepAudio: false)
        pending.origin = .whatsappVideo
        pending.transcribedText = "Falante 1: Concordo."
        try store.setPending(pending)
        let reopened = try LocalStore(rootURL: folder)
        XCTAssertEqual(reopened.pending?.origin, .whatsappVideo)
        XCTAssertEqual(reopened.pending?.transcribedText, "Falante 1: Concordo.")
        _ = try reopened.finalizePending()
        XCTAssertNil(reopened.pending)
        XCTAssertEqual(reopened.conversations.count, 1)
    }

    func testExportTXTContainsOriginContactAndTranscript() {
        let value = Conversation(
            id: UUID(), contactName: "Maria", phoneNumber: "+55 84 99999-0000",
            occurredAt: Date(), origin: .googleMeet, transcript: "Reunião concluída.",
            audioFileName: nil, hasSpeakerLabels: false,
            summary: nil, decisions: [], tasks: [],
            createdAt: Date(), updatedAt: Date())
        let txt = value.asTXT()
        XCTAssertTrue(txt.contains("Maria"))
        XCTAssertTrue(txt.contains("+55 84 99999-0000"))
        XCTAssertTrue(txt.contains("Google Meet"))
        XCTAssertTrue(txt.contains("Reunião concluída."))
    }

    func testFormatAndSizeValidation() throws {
        let (store, folder) = try makeStore()
        let bad = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).exe")
        try Data("fake".utf8).write(to: bad)
        defer {
            try? FileManager.default.removeItem(at: bad)
            try? FileManager.default.removeItem(at: folder)
        }
        XCTAssertThrowsError(try store.importAudio(from: bad, keepAudio: false))
    }

    func testSectionParsingDoesNotInventSpeakers() {
        let value = AnalysisParsing.parse("""
        RESUMO:
        Houve uma conversa sobre a entrega.
        DECISÕES:
        - Enviar na sexta-feira.
        TAREFAS:
        - Revisar documento.
        """)
        XCTAssertEqual(value.summary, "Houve uma conversa sobre a entrega.")
        XCTAssertEqual(value.decisions, ["Enviar na sexta-feira."])
        XCTAssertEqual(value.tasks, ["Revisar documento."])
    }

    func testSummaryParsingWithoutDecisionsOrTasks() {
        let value = AnalysisParsing.parse("""
        RESUMO:
        Reunião breve.
        DECISÕES:
        - Nenhuma
        TAREFAS:
        - Nenhuma
        """)
        XCTAssertTrue(value.decisions.isEmpty)
        XCTAssertTrue(value.tasks.isEmpty)
    }

    func testNoSpeakerLabelsWhenAudioIsImported() throws {
        let (store, folder) = try makeStore()
        let original = try makeAudio()
        defer {
            try? FileManager.default.removeItem(at: original)
            try? FileManager.default.removeItem(at: folder)
        }
        let item = try store.importAudio(from: original, keepAudio: false)
        XCTAssertFalse(item.hasSpeakerLabels)
        XCTAssertFalse(item.keepAudio)
    }

    func testEmptyTranscriptPreservesTemporaryAudio() throws {
        let (store, folder) = try makeStore()
        let original = try makeAudio()
        defer {
            try? FileManager.default.removeItem(at: original)
            try? FileManager.default.removeItem(at: folder)
        }
        var item = try store.importAudio(from: original, keepAudio: false)
        item.transcribedText = "   \n "
        try store.setPending(item)
        XCTAssertThrowsError(try store.finalizePending())
        XCTAssertNotNil(store.pending)
        XCTAssertTrue(store.conversations.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.temporaryURL(for: item).path))
    }

    func testFailedSavePreservesAudioAndAllowsRetry() throws {
        let (store, folder) = try makeStore()
        let original = try makeAudio()
        defer {
            try? FileManager.default.removeItem(at: original)
            try? FileManager.default.removeItem(at: folder)
        }
        var item = try store.importAudio(from: original, keepAudio: false)
        item.transcribedText = "Texto que precisa ser preservado."
        try store.setPending(item)
        // Uma pasta no destino do JSON provoca uma falha real de escrita.
        let blocked = folder.appendingPathComponent("conversas.json")
        try FileManager.default.createDirectory(at: blocked, withIntermediateDirectories: false)
        XCTAssertThrowsError(try store.finalizePending())
        XCTAssertTrue(store.conversations.isEmpty)
        XCTAssertEqual(store.pending?.transcribedText, item.transcribedText)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.temporaryURL(for: item).path))
        try FileManager.default.removeItem(at: blocked)
        _ = try store.finalizePending()
        let reopened = try LocalStore(rootURL: folder)
        XCTAssertEqual(reopened.conversations.first?.transcript, item.transcribedText)
        XCTAssertNil(reopened.pending)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.temporaryURL(for: item).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: original.path))
    }
}
