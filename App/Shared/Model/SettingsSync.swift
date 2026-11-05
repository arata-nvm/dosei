import Foundation

/// 設定値を iCloud のキー値ストアで iPhone と Mac にそろえる。
///
/// 画面は今までどおり @AppStorage（UserDefaults）を読み書きし、ここで UserDefaults と
/// キー値ストアの差を双方向に埋める。値が同じなら書かないので、通知が行き来し続けることはない。
enum SettingsSync {
    static let keys = [
        AppSettings.Key.nikkyID,
        AppSettings.Key.boundaryHour,
        AppSettings.Key.swarmClientID,
        AppSettings.Key.spotifyClientID,
    ]

    private static var observers: [NSObjectProtocol] = []

    static func start() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers = [
            // 別の端末で変わった
            center.addObserver(
                forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: cloud, queue: .main
            ) { _ in pull() },
            // この端末で変わった
            center.addObserver(
                forName: UserDefaults.didChangeNotification,
                object: local, queue: .main
            ) { _ in push() },
        ]
        cloud.synchronize()
        pull()  // iCloud にある値を先に反映
        push()  // iCloud にまだない値を上げる
    }

    private static var cloud: NSUbiquitousKeyValueStore { .default }
    private static var local: UserDefaults { .standard }

    private static func pull() {
        for key in keys {
            guard let value = cloud.object(forKey: key), !same(value, local.object(forKey: key)) else { continue }
            local.set(value, forKey: key)
        }
    }

    private static func push() {
        for key in keys {
            guard let value = local.object(forKey: key), !same(value, cloud.object(forKey: key)) else { continue }
            cloud.set(value, forKey: key)
        }
    }

    private static func same(_ a: Any?, _ b: Any?) -> Bool {
        switch (a as? NSObject, b as? NSObject) {
        case (nil, nil): true
        case (let x?, let y?): x.isEqual(y)
        default: false
        }
    }
}
