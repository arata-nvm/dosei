import SwiftUI
import AuthenticationServices

struct SettingsView: View {
    @AppStorage(AppSettings.subjectKey) private var subject = ""
    @AppStorage(AppSettings.boundaryHourKey) private var boundaryHour = 4
    @AppStorage(AppSettings.swarmClientIDKey) private var clientID = ""
    @Environment(\.webAuthenticationSession) private var webAuth
    @Environment(\.dismiss) private var dismiss

    @State private var token = Keychain.get(SwarmClient.tokenAccount) ?? ""
    @State private var authError: String?

    var body: some View {
        Form {
            Section {
                TextField("名前", text: $subject)
                Picker("日付の区切り", selection: $boundaryHour) {
                    ForEach(0...8, id: \.self) { Text("午前\($0)時").tag($0) }
                }
            }

            Section("Swarm") {
                TextField("Client ID", text: $clientID)
                SecureField("アクセストークン", text: $token)
                    .onSubmit { Keychain.set(token, for: SwarmClient.tokenAccount) }
                Button("ログイン") { Task { await login() } }
                    .disabled(clientID.isEmpty)
                if let authError {
                    Text(authError).foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("設定")
        .onDisappear { Keychain.set(token, for: SwarmClient.tokenAccount) }
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

    private func login() async {
        guard let url = SwarmClient.authorizeURL(clientID: clientID) else { return }
        do {
            let callback = try await webAuth.authenticate(using: url, callbackURLScheme: SwarmClient.callbackScheme)
            if let t = SwarmClient.token(fromCallback: callback) {
                token = t
                Keychain.set(t, for: SwarmClient.tokenAccount)
                authError = nil
            } else {
                authError = "ログインできませんでした"
            }
        } catch {
            authError = error.localizedDescription
        }
    }
}
