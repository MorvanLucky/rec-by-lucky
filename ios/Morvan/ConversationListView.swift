import SwiftUI
import UniformTypeIdentifiers

struct ConversationListView: View {
    @ObservedObject var app: MorvanController
    @State private var filter = ""
    @State private var importing = false
    @State private var showingPending = false
    @State private var showingSettings = false

    private var results: [Conversation] {
        guard !filter.isEmpty else { return app.conversations }
        return app.conversations.filter {
            $0.contactName.localizedCaseInsensitiveContains(filter)
            || $0.phoneNumber.localizedCaseInsensitiveContains(filter)
            || $0.transcript.localizedCaseInsensitiveContains(filter)
            || $0.origin.rawValue.localizedCaseInsensitiveContains(filter)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if app.pending != nil {
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Áudio temporário pendente", systemImage: "waveform.badge.exclamationmark")
                                .font(.title3.bold())
                            Text("Você pode tentar novamente ou excluir o áudio temporário.")
                            Button("Abrir gravação pendente") { showingPending = true }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                        }
                        .padding(.vertical, 8)
                    }
                }
                Section("Transcrições salvas") {
                    if results.isEmpty {
                        ContentUnavailableView(
                            "Nenhuma conversa",
                            systemImage: "text.bubble",
                            description: Text("Importe uma gravação de áudio ou vídeo para criar sua primeira transcrição."))
                    }
                    ForEach(results) { item in
                        NavigationLink {
                            ConversationDetailView(app: app, conversation: item)
                        } label: {
                            VStack(alignment: .leading, spacing: 7) {
                                Text(item.displayName).font(.title3.bold())
                                Text(item.origin.rawValue).font(.body)
                                Text(item.occurredAt.formatted(date: .abbreviated, time: .shortened))
                                    .foregroundStyle(.secondary)
                                    .font(.subheadline)
                                Text(item.transcript)
                                    .lineLimit(2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 10)
                        }
                        .swipeActions {
                            Button("Excluir", role: .destructive) { app.delete(item) }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $filter, prompt: "Buscar no texto, contato ou telefone")
            .navigationTitle("Rec by Lucky")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Label("Configurações", systemImage: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if app.pending != nil { showingPending = true }
                        else { importing = true }
                    } label: {
                        Label("Importar áudio ou vídeo", systemImage: "plus")
                    }
                    .disabled(app.isBusy)
                }
            }
            .overlay {
                if app.isBusy {
                    ProgressView("Processando…")
                        .padding(25)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !app.isBusy && app.pending == nil {
                    Button {
                        importing = true
                    } label: {
                        Label("Importar gravação", systemImage: "square.and.arrow.down")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
            .fileImporter(isPresented: $importing,
                          allowedContentTypes: [.audio, .movie, .mpeg4Movie, .video, .data]) { response in
                switch response {
                case .success(let url):
                    Task {
                        await app.importMedia(url)
                        if app.pending != nil { showingPending = true }
                    }
                case .failure(let error):
                    app.errorMessage = error.localizedDescription
                }
            }
            .sheet(isPresented: $showingPending) {
                if let pending = app.pending {
                    PendingImportView(app: app, initial: pending)
                }
            }
            .sheet(isPresented: $showingSettings) {
                NavigationStack { SettingsView() }
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
}
