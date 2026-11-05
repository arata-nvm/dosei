# 動静

朝日新聞「首相動静」の文体で一日を記録し、[Nikky](https://nikky.slimalized.dev/) に投稿するための iPhone / Mac アプリ。

> 　午前７時４０分、起床。同８時４０分から同９時まで、自転車。同９時１分、大学。同１０時から午後０時まで、講義。……同１１時３０分、就寝。

- **時刻は自動**：入力欄に「やったこと」だけ書くと、その時刻で記録される
- **Swarm**：チェックインが場所の名前で自動で入る（着いたとき・途中・出るときのどれでもチェックインするので「着」は付けない。一言は入れない）
- **Spotify**：お気に入りの曲（Liked Songs）に追加した曲が「YOASOBI『夜に駆ける』」の形で入る。Nikky に投稿する文では、本文の下に曲の URL を段落を分けて並べる（Nikky で「埋め込み」を押すとプレーヤーになる）
- **Apple Watch**：起床・就寝（睡眠記録）とワークアウト（自転車・徒歩など）が自動で入る。iPhone でヘルスケアに記録が増えると、アプリを開いていなくても裏で取り込まれる（バックグラウンド配信）
- **同期**：iCloud で iPhone と Mac が同期。サーバーなし（記録は CloudKit、Swarm のトークンは iCloud キーチェーン、Nikky の ID・日付の区切り・Swarm の Client ID は iCloud のキー値ストア）
- **Siri / ショートカット / アクションボタン**：「動静に記録」でアプリを開かずに記録
- **Nikky に投稿**：上のバーのボタンで、その日の記録を首相動静の文体にしてコピーし、Nikky の投稿画面を開く

日付の区切りは午前4時（設定で変更可）。区切りより前の記録（深夜の就寝など）は前の日に入る。
設定に Nikky の ID を入れると、`https://nikky.slimalized.dev/@{ID}/posts/new` を開く（空ならトップ）。

一覧を左右にスワイプして日付を変える（Mac はトラックパッドの2本指）。行の操作（ここまで・削除・隠す）は長押し（Mac は右クリック）。Nikky は正午で日が切り替わるので、翌朝に前日分をまとめて投稿できる。

## セットアップ

```bash
brew install xcodegen
```

1. `xcodegen` を実行して `Dosei.xcodeproj` を開く
2. iCloud コンテナ `iCloud.dev.arata-nvm.dosei` は初回ビルド時に Xcode が作る（Signing & Capabilities で確認）
3. ターゲット `Dosei` の実行先を iPhone か My Mac にして実行

### Swarm

1. https://foursquare.com/developers/apps でアプリを作る
2. Redirect URI に `dosei://swarm` を登録
3. アプリの設定に Client ID を入れて「Swarm でログイン」
   （うまくいかなければ、取得したアクセストークンを直接貼る）

### Spotify

1. https://developer.spotify.com/dashboard でアプリを作る（Web API にチェック）
2. Redirect URI に `dosei://spotify` を登録
3. アプリの設定に Client ID を入れて「ログイン」（Client Secret は使わない。PKCE でログインする）

更新用のトークンは iCloud キーチェーンに保存され、Mac とも共有される。

## TestFlight で配る（Xcode Cloud）

`main` に push すると、Xcode Cloud が iPhone 版と Mac 版をビルドして TestFlight に上げる。
`.xcodeproj` は Git に入れていないので、`ci_scripts/ci_post_clone.sh` で XcodeGen を実行してから作る。

TestFlight の版は CloudKit の**本番**の環境を使う（Xcode から入れた版は開発用で、データは別）。

## 構成

```
Packages/DoseiCore          プラットフォームに依存しない部分（swift test でテストできる）
  DoseiFormatter.swift      首相動静の文体
  DiaryDay.swift            日記の「1日」（午前4時区切り）
  Sleep.swift               睡眠の区間から起床・就寝を求める
  ImportedRecord.swift      取り込んだ記録の共通の形と sourceID の付け方
  SwarmAPI.swift            Swarm の API（ログイン URL、チェックインの取得と読み取り）
  SpotifyAPI.swift          Spotify の API（PKCE のログイン、トークンの更新、お気に入りの曲の取得）

App/Shared                  iPhone / Mac 共通
  App/                      エントリポイント、Siri・ショートカット
  Model/                    Entry（SwiftData + CloudKit）、保存先、設定値
  Import/                   取り込み（RecordSource → Importer が Entry に保存）、Swarm のトークン
  Views/                    画面
  Support/                  プラットフォームごとの小物（クリップボード、Mac のスワイプ）
  Assets.xcassets           アプリのアイコン
App/iOS                     iPhone のみ：ヘルスケアの読み取りとバックグラウンド配信
App/Config                  entitlements と Info.plist（iPhone / Mac 別）
```

### 取り込み元を増やすとき

`RecordSource` に準拠した型を作り、その日の分を `ImportedRecord` で返す。`Importer.sources` に足せば、保存・重複の除去・手で直した行の保護は `Importer` が行う。
`sourceID` は保存済みのデータと対応するので、一度決めた形式は変えない（`SourceID` とテストで固定してある）。

首相動静の規則は `DoseiFormatter.swift` に書いてある。
`swift test`（`Packages/DoseiCore` で実行）で、その規則どおりに文章が組み立てられることを確かめている。

## 開発

```bash
xcrun swift-format -i -r App Packages      # 整形（設定は .swift-format）
xcrun swift-format lint --strict -r App Packages
cd Packages/DoseiCore && swift test        # 文体などのテスト
```

GitHub Actions（`.github/workflows/ci.yml`）で、push と PR のたびに次を確かめる。

- **Format**：`swift format lint --strict`（Linux、Swift 6.0.3）
- **Test**：DoseiCore の `swift test`（Linux）
- **Build**：`xcodegen` → iOS シミュレータ向けと Mac 向けに署名なしでビルド（macOS）

