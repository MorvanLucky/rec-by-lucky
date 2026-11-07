import SwiftUI
import Speech

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    private var ptBRAvailable: Bool {
        SFSpeechRecognizer(locale: Locale(identifier: "pt-BR"))?.supportsOnDeviceRecognition == true
    }

    var body: some View {
        Form {
            Section("Gratuito e sem servidor") {
                Label("Não precisa de chave OpenAI, conta paga ou hospedagem.",
                      systemImage: "checkmark.shield")
                Text("Todas as transcrições ficam no iPhone. Nenhum arquivo é enviado ao GitHub.")
                Text("O processamento usa somente o reconhecimento de fala local da Apple, sem alternativa online.")
            }
            Section("Transcrição offline em português") {
                Label(ptBRAvailable
                      ? "O iPhone informa suporte ao reconhecimento local em pt-BR."
                      : "Este iPhone/iOS não informa suporte ao reconhecimento offline em pt-BR.",
                      systemImage: ptBRAvailable ? "checkmark.circle" : "exclamationmark.triangle")
                    .foregroundStyle(ptBRAvailable ? .green : .orange)
                Text("O suporte pode depender da versão do iOS e dos recursos de idioma instalados. Quando indisponível, o Rec by Lucky não enviará áudio a um serviço externo.")
            }
            Section("Resumos opcionais") {
                Text("Resumo, decisões e tarefas usam Apple Intelligence no próprio aparelho, quando disponível (iOS 26 ou superior). Se o recurso não estiver habilitado, o Rec by Lucky avisa sem cobrar nada.")
                Text("Confira sempre os resumos. Nenhuma decisão ou tarefa deve ser atribuída a pessoas sem confirmação.")
            }
            Section("Privacidade") {
                Text("Por padrão, o áudio é temporário e só é excluído depois de a transcrição ser salva com sucesso.")
                Text("O arquivo original, fora do Rec by Lucky, não é excluído.")
                Text("Sem serviço externo contratado, não há política de retenção de um provedor de transcrição. O processamento solicitado pelo Rec by Lucky é exclusivamente local.")
                Text("O Rec by Lucky não captura chamadas do WhatsApp, Google Meet ou aplicativo Telefone. Ele importa gravações autorizadas.")
            }
        }
        .navigationTitle("Configurações")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Concluir") { dismiss() }
            }
        }
    }
}
