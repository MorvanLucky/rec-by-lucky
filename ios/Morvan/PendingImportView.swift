import SwiftUI

struct PendingImportView: View {
    @ObservedObject var app: MorvanController
    @Environment(\.dismiss) private var dismiss
    @State private var draft: PendingImport
    @State private var confirmDelete = false

    init(app: MorvanController, initial: PendingImport) {
        self.app = app
        _draft = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Dados da conversa") {
                    Picker("Origem", selection: $draft.origin) {
                        ForEach(ConversationOrigin.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    TextField("Nome do contato (opcional)", text: $draft.contactName)
                        .textContentType(.name)
                    TextField("Telefone (opcional)", text: $draft.phoneNumber)
                        .keyboardType(.phonePad)
                    DatePicker("Data e horário",
                               selection: $draft.occurredAt,
                               displayedComponents: [.date, .hourAndMinute])
                }
                Section("Privacidade") {
                    Toggle("Guardar áudio junto da transcrição", isOn: $draft.keepAudio)
                    Text("Desativado por padrão. O áudio temporário só é excluído depois de salvar a transcrição localmente.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Identificação automática de falantes não disponível no reconhecimento offline desta versão. O Rec by Lucky não inventa falantes.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Processamento") {
                    Text(draft.transcribedText == nil
                         ? "A gravação ainda não foi transcrita. Você também pode digitar ou colar a transcrição."
                         : "Texto pronto para salvar. Revise antes de concluir.")
                    TextEditor(text: Binding(
                        get: { draft.transcribedText ?? "" },
                        set: { draft.transcribedText = $0.isEmpty ? nil : $0 }
                    ))
                    .font(.title3)
                    .frame(minHeight: 110)
                    .accessibilityLabel("Transcrição manual opcional")
                    Button {
                        do {
                            try app.updatePending(draft)
                            Task {
                                if await app.transcribePending() { dismiss() }
                                else if let recovered = app.pending { draft = recovered }
                            }
                        } catch { app.errorMessage = error.localizedDescription }
                    } label: {
                        HStack {
                            if app.isBusy { ProgressView() }
                            Text(draft.transcribedText == nil
                                 ? "Transcrever offline e salvar" : "Salvar texto e concluir")
                                .font(.title3.bold())
                        }
                    }
                    .disabled(app.isBusy)
                }
                Section {
                    Button("Excluir áudio temporário", role: .destructive) {
                        confirmDelete = true
                    }
                    .disabled(app.isBusy)
                } footer: {
                    Text("O arquivo original, fora do Rec by Lucky, não será apagado. Use gravações feitas com autorização dos participantes.")
                }
            }
            .disabled(app.isBusy)
            .navigationTitle("Nova transcrição")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Fechar") {
                        do {
                            try app.updatePending(draft)
                            dismiss()
                        } catch { app.errorMessage = error.localizedDescription }
                    }
                    .disabled(app.isBusy)
                }
            }
            .interactiveDismissDisabled()
            .confirmationDialog("Descartar o áudio temporário do Rec by Lucky?",
                                isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Excluir agora", role: .destructive) {
                    app.discardPending()
                    if app.pending == nil { dismiss() }
                }
            } message: {
                Text("Isso não exclui o arquivo original. Nenhum dado é enviado a provedores pelo Rec by Lucky gratuito.")
            }
            .alert("Erro", isPresented: Binding(
                get: { app.errorMessage != nil },
                set: { if !$0 { app.errorMessage = nil } }
            )) {
                Button("OK") { app.errorMessage = nil }
            } message: {
                Text(app.errorMessage ?? "")
            }
        }
    }
}
