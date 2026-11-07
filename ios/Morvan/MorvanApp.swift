import SwiftUI
import LocalAuthentication

@main
struct MorvanApp: App {
    @StateObject private var controller = MorvanController()
    @Environment(\.scenePhase) private var phase
    @State private var unlocked = false
    @State private var authenticating = false
    @State private var unlockError: String?

    var body: some Scene {
        WindowGroup {
            Group {
                if unlocked {
                    ConversationListView(app: controller)
                } else {
                    VStack(spacing: 22) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(Color.accentColor)
                        Text("Rec by Lucky")
                            .font(.largeTitle.bold())
                        Text("Transcrição de Conversas")
                            .font(.title3)
                        Text("Suas conversas ficam protegidas neste iPhone.")
                            .multilineTextAlignment(.center)
                        Button("Desbloquear com Face ID ou código") { authenticate() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        if let unlockError {
                            Text(unlockError)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(28)
                }
            }
            .onAppear { authenticate() }
            .onChange(of: phase) { newValue in
                if newValue == .background {
                    unlocked = false
                } else if newValue == .active && !unlocked {
                    authenticate()
                }
            }
        }
    }

    private func authenticate() {
        guard !unlocked && !authenticating else { return }
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            unlockError = "Configure um código de desbloqueio no iPhone. O Rec by Lucky não abre sem ele."
            return
        }
        authenticating = true
        context.evaluatePolicy(.deviceOwnerAuthentication,
                               localizedReason: "Acessar transcrições privadas do Rec by Lucky") { success, error in
            Task { @MainActor in
                authenticating = false
                unlocked = success
                unlockError = success ? nil : (error?.localizedDescription ?? "Autenticação necessária.")
            }
        }
    }
}
