import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct MorvanTXTDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    var text: String

    init(text: String) { self.text = text }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let decoded = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = decoded
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

struct ConversationDetailView: View {
    @ObservedObject var app: MorvanController
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Conversation
    @State private var exportDocument: MorvanTXTDocument?
    @State private var exporting = false
    @State private var playing = false
    @State private var audioPlayer: AVPlayer?
    @State private var confirmAudioDeletion = false
    @State private var confirmConversationDeletion = false

    init(app: MorvanController, conversation: Conversation) {
        self.app = app
        _draft = State(initialValue: conversation)
    }

    var body: some View {
        Form {
            Section("Identificação") {
                TextField("Contato", text: $draft.contactName)
                    .font(.title3)
                TextField("Telefone", text: $draft.phoneNumber)
                    .keyboardType(.phonePad)
                Picker("Origem informada", selection: $draft.origin) {
                    ForEach(ConversationOrigin.allCases) { origin in
                        Text(origin.rawValue).tag(origin)
                    }
                }
                DatePicker("Data e horário", selection: $draft.occurredAt,
                           displayedComponents: [.date, .hourAndMinute])
                if draft.hasSpeakerLabels {
                    Label("Identificação por falantes, sem nomes atribuídos",
                          systemImage: "person.2")
                        .font(.subheadline)
                }
            }
            Section {
                TextEditor(text: $draft.transcript)
                    .font(.title3)
                    .frame(minHeight: 260)
                    .accessibilityLabel("Transcrição completa editável")
                Button("Salvar alterações") {
                    app.update(draft)
                }
                .font(.title3.bold())
                .disabled(draft.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } header: {
                Text("Transcrição — texto editável")
            } footer: {
                Text("A busca da tela inicial encontra palavras dentro das transcrições.")
            }

            if let audioURL = app.localAudioURL(for: draft) {
                Section("Áudio guardado") {
                    Button {
                        if playing {
                            audioPlayer?.pause()
                            playing = false
                        } else {
                            if audioPlayer == nil {
                                audioPlayer = AVPlayer(url: audioURL)
                            }
                            audioPlayer?.play()
                            playing = true
                        }
                    } label: {
                        Label(playing ? "Pausar áudio" : "Ouvir áudio",
                              systemImage: playing ? "pause.circle" : "play.circle")
                            .font(.title3)
                    }
                    Button("Excluir somente o áudio", role: .destructive) {
                        confirmAudioDeletion = true
                    }
                }
            }

            Section("Resumo, decisões e tarefas") {
                if let summary = draft.summary {
                    Text(summary).font(.body)
                    if !draft.decisions.isEmpty {
                        Text("Decisões").font(.headline)
                        ForEach(draft.decisions, id: \.self) { item in
                            Text("• \(item)")
                        }
                    }
                    if !draft.tasks.isEmpty {
                        Text("Tarefas").font(.headline)
                        ForEach(draft.tasks, id: \.self) { item in
                            Text("• \(item)")
                        }
                    }
                    if draft.decisions.isEmpty && draft.tasks.isEmpty {
                        Text("Nenhuma decisão ou tarefa explícita identificada.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("A análise é opcional e só será solicitada quando você tocar no botão abaixo.")
                        .foregroundStyle(.secondary)
                }
                Button("Gerar resumo, decisões e tarefas") {
                    app.update(draft)
                    if let saved = app.conversations.first(where: { $0.id == draft.id }) {
                        Task { await app.analyze(saved) }
                    }
                }
                .disabled(app.isBusy || draft.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Section("Exportar ou excluir") {
                Button {
                    app.update(draft)
                    exportDocument = MorvanTXTDocument(text: draft.asTXT())
                    exporting = true
                } label: {
                    Label("Exportar transcrição em TXT", systemImage: "square.and.arrow.up")
                        .font(.title3)
                }
                Button("Excluir conversa", role: .destructive) {
                    confirmConversationDeletion = true
                }
            }
        }
        .navigationTitle(draft.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { audioPlayer?.pause() }
        .onReceive(app.$conversations) { values in
            guard let saved = values.first(where: { $0.id == draft.id }),
                  saved.updatedAt != draft.updatedAt else { return }
            draft = saved
        }
        .fileExporter(isPresented: $exporting, document: exportDocument,
                      contentType: .plainText,
                      defaultFilename: "Rec-by-Lucky-\(draft.id.uuidString.prefix(8)).txt") { result in
            if case .failure(let error) = result { app.errorMessage = error.localizedDescription }
        }
        .confirmationDialog("Excluir somente o áudio guardado?",
                            isPresented: $confirmAudioDeletion, titleVisibility: .visible) {
            Button("Excluir áudio", role: .destructive) {
                audioPlayer?.pause()
                audioPlayer = nil
                playing = false
                app.deleteAudio(draft)
            }
        } message: {
            Text("A transcrição será mantida.")
        }
        .confirmationDialog("Excluir a transcrição desta conversa?",
                            isPresented: $confirmConversationDeletion, titleVisibility: .visible) {
            Button("Excluir conversa e áudio guardado", role: .destructive) {
                app.delete(draft)
                dismiss()
            }
        } message: {
            Text("Isso remove os dados locais do Rec by Lucky. Não elimina o arquivo original importado.")
        }
        .alert("Rec by Lucky", isPresented: Binding(
            get: { app.errorMessage != nil },
            set: { if !$0 { app.errorMessage = nil } }
        )) {
            Button("OK") { app.errorMessage = nil }
        } message: {
            Text(app.errorMessage ?? "")
        }
    }
}
