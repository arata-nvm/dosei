import SwiftUI

struct SettingsView: View {
    @AppStorage(AppSettings.subjectKey) private var subject = ""
    @AppStorage(AppSettings.boundaryHourKey) private var boundaryHour = 4
    @AppStorage(AppSettings.swarmClientIDKey) private var clientID = ""
    @Environment(\.dismiss) private var dismiss

    @State private var token = Keychain.get(SwarmClient.tokenAccount) ?? ""
    @State private var authError: String?

    var body: some View {
        Form {
            Section {
                TextField("名前（「高市首相」の位置に入ります。空なら付けません）", text: $subject)
                Stepper("日付の区切り: 午前\(boundaryHour)時", value: $boundaryHour, in: 0...8)
            } header: {
                Text("日記")
            } footer: {
                Text("区切りより前の記録（深夜の就寝など）は前の日の日記に入ります。")
            }

            Section {
                TextField("Client ID", text: $clientID)
                Button("Swarm でログイン") { Task { await login() } }
                    .disabled(clientID.isEmpty)
                SecureField("アクセストークン（直接貼ることもできます）", text: $token)
                    .onSubmit { Keychain.set(token, for: SwarmClient.tokenAccount) }
                if let authError {
                    Text(authError).foregroundStyle(.red).font(.footnote)
                }
            } header: {
                Text("Swarm")
            } footer: {
                Text("Foursquare の開発者ページでアプリを作り、Redirect URI に \(SwarmClient.redirectURI) を登録してください。トークンは iCloud キーチェーンに保存され、Mac とも共有されます。")
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
            let callback = try await WebAuth.shared.authenticate(url: url, callbackURLScheme: SwarmClient.callbackScheme)
            if let t = SwarmClient.token(fromCallback: callback) {
                token = t
                Keychain.set(t, for: SwarmClient.tokenAccount)
                authError = nil
            } else {
                authError = "トークンを受け取れませんでした: \(callback.absoluteString)"
            }
        } catch {
            authError = error.localizedDescription
        }
    }
}
