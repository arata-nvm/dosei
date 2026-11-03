import SwiftUI
import DoseiCore
import AuthenticationServices

struct SettingsView: View {
    @AppStorage(AppSettings.Key.subject) private var subject = ""
    @AppStorage(AppSettings.Key.boundaryHour) private var boundaryHour = AppSettings.defaultBoundaryHour
    @AppStorage(AppSettings.Key.swarmClientID) private var clientID = ""
    @Environment(\.webAuthenticationSession) private var webAuth
    @Environment(\.dismiss) private var dismiss

    @State private var token = SwarmAccount.token ?? ""
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
                    .onSubmit { SwarmAccount.token = token }
                Button("ログイン") { Task { await login() } }
                    .disabled(clientID.isEmpty)
                if let authError {
                    Text(authError).foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("設定")
        .onDisappear { SwarmAccount.token = token }
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
        guard let url = SwarmAPI.authorizeURL(clientID: clientID) else { return }
        do {
            let callback = try await webAuth.authenticate(using: url, callbackURLScheme: SwarmAPI.callbackScheme)
            if let t = SwarmAPI.token(fromCallback: callback) {
                token = t
                SwarmAccount.token = t
                authError = nil
            } else {
                authError = "ログインできませんでした"
            }
        } catch {
            authError = error.localizedDescription
        }
    }
}
