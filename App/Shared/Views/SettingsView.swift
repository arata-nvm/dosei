import SwiftUI
import DoseiCore
import AuthenticationServices

struct SettingsView: View {
    @AppStorage(AppSettings.Key.nikkyID) private var nikkyID = ""
    @AppStorage(AppSettings.Key.boundaryHour) private var boundaryHour = AppSettings.defaultBoundaryHour
    @AppStorage(AppSettings.Key.swarmClientID) private var clientID = ""
    @Environment(\.webAuthenticationSession) private var webAuth
    @Environment(\.dismiss) private var dismiss

    /// トークンは iCloud キーチェーンで共有されるので、別の端末でログインしていればログイン済みになる
    @State private var isLoggedIn = SwarmAccount.token != nil
    @State private var tokenDraft = ""
    @State private var authError: String?

    var body: some View {
        Form {
            Section {
                TextField("Nikky の ID", text: $nikkyID)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                Picker("日付の区切り", selection: $boundaryHour) {
                    ForEach(0...8, id: \.self) { Text("午前\($0)時").tag($0) }
                }
            }

            Section("Swarm") {
                if isLoggedIn {
                    Label("ログイン済み", systemImage: "checkmark.circle")
                    Button("ログアウト", role: .destructive) {
                        SwarmAccount.token = nil
                        isLoggedIn = false
                    }
                } else {
                    TextField("Client ID", text: $clientID)
                    Button("ログイン") { Task { await login() } }
                        .disabled(clientID.isEmpty)
                    SecureField("アクセストークン", text: $tokenDraft)
                        .onSubmit(saveTokenDraft)
                }
                if let authError {
                    Text(authError).foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("設定")
        .onDisappear(perform: saveTokenDraft)
        #if os(iOS)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("完了") { dismiss() }
            }
        }
        #else
        .frame(width: 520)
        .padding()
        #endif
    }

    /// トークンを直接貼ったとき
    private func saveTokenDraft() {
        let t = tokenDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        SwarmAccount.token = t
        tokenDraft = ""
        isLoggedIn = true
    }

    private func login() async {
        guard let url = SwarmAPI.authorizeURL(clientID: clientID) else { return }
        do {
            let callback = try await webAuth.authenticate(using: url, callbackURLScheme: SwarmAPI.callbackScheme)
            if let t = SwarmAPI.token(fromCallback: callback) {
                SwarmAccount.token = t
                isLoggedIn = true
                authError = nil
            } else {
                authError = "ログインできませんでした"
            }
        } catch {
            authError = error.localizedDescription
        }
    }
}
