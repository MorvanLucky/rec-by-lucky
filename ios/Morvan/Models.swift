import Foundation

enum ConversationOrigin: String, Codable, CaseIterable, Identifiable {
    case whatsapp = "WhatsApp"
    case phone = "Ligação normal"
    case inPerson = "Conversa presencial"
    case whatsappVideo = "Videochamada WhatsApp"
    case googleMeet = "Videochamada Google Meet"
    case otherVideo = "Outro vídeo"

    var id: String { rawValue }
}

struct Conversation: Identifiable, Codable, Equatable {
    var id: UUID
    var contactName: String
    var phoneNumber: String
    var occurredAt: Date
    var origin: ConversationOrigin
    var transcript: String
    var audioFileName: String?
    var hasSpeakerLabels: Bool
    var summary: String?
    var decisions: [String]
    var tasks: [String]
    var createdAt: Date
    var updatedAt: Date

    var displayName: String {
        contactName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        ? "Contato não informado" : contactName
    }

    func asTXT() -> String {
        let timestamp = DateFormatter.localizedString(
            from: occurredAt, dateStyle: .full, timeStyle: .short)
        var body = """
        Rec by Lucky — Transcrição de Conversas
        Contato: \(displayName)
        Telefone: \(phoneNumber.isEmpty ? "Não informado" : phoneNumber)
        Origem informada: \(origin.rawValue)
        Data e horário: \(timestamp)

        TRANSCRIÇÃO

        \(transcript)
        """
        if let summary, !summary.isEmpty {
            body += "\n\nRESUMO\n\n\(summary)"
            body += "\n\nDECISÕES\n"
            body += decisions.isEmpty ? "Nenhuma identificada." : decisions.map { "• \($0)" }.joined(separator: "\n")
            body += "\n\nTAREFAS\n"
            body += tasks.isEmpty ? "Nenhuma identificada." : tasks.map { "• \($0)" }.joined(separator: "\n")
        }
        return body + "\n"
    }
}

struct PendingImport: Identifiable, Codable, Equatable {
    let id: UUID
    let audioExtension: String
    var contactName: String
    var phoneNumber: String
    var occurredAt: Date
    var origin: ConversationOrigin
    var keepAudio: Bool
    var transcribedText: String?
    var hasSpeakerLabels: Bool
    var identifySpeakers: Bool = false
}

struct TranscriptionResult: Decodable {
    let text: String
    let speakerLabels: Bool
}

struct AnalysisResult: Decodable {
    let summary: String
    let decisions: [String]
    let tasks: [String]
}

enum MorvanError: LocalizedError {
    case invalidAudio
    case audioTooLarge
    case pendingExists
    case noPending
    case invalidConfiguration
    case serverMessage(String)
    case emptyText

    var errorDescription: String? {
        switch self {
        case .invalidAudio:
            return "Formato inválido. Use áudio M4A, MP3, WAV, CAF ou vídeo MP4, MOV e M4V."
        case .audioTooLarge:
            return "O arquivo de áudio para transcrição deve ter até 100 MB. Para gravações longas, divida-o antes de importar."
        case .pendingExists:
            return "Resolva primeiro a gravação temporária pendente."
        case .noPending:
            return "Não há áudio temporário para processar."
        case .invalidConfiguration:
            return "Esta versão não usa servidor, token ou API paga."
        case .serverMessage(let message):
            return message
        case .emptyText:
            return "Digite uma transcrição antes de salvar."
        }
    }
}
