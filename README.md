# 動静

朝日新聞「首相動静」の文体で一日を記録し、[Nikky](https://nikky.slimalized.dev/) に投稿するための iPhone / Mac アプリ。

> 　午前７時４０分、起床。同８時４０分から同９時まで、自転車。同９時１分、大学着。同１０時から午後０時まで、講義。……同１１時３０分、就寝。

- **時刻は自動**：入力欄に「やったこと」だけ書くと、その時刻で記録される
- **Swarm**：チェックインが「〇〇着」として自動で入る
- **Apple Watch**：起床・就寝（睡眠記録）とワークアウト（自転車・徒歩など）が自動で入る（iPhone のみ）
- **同期**：iCloud（CloudKit）で iPhone と Mac が同期。サーバーなし
- **Siri / ショートカット / アクションボタン**：「動静に記録」でアプリを開かずに記録
- **まとめ**：その日の記録を首相動静の文体にして、コピー → Nikky を開く

日付の区切りは午前4時（設定で変更可）。Nikky は正午で日が切り替わるので、翌朝に前日分をまとめて投稿できる。

## セットアップ

```bash
brew install xcodegen
```

1. `project.yml` の `DEVELOPMENT_TEAM`（Team ID）と `BUNDLE_ID` を自分のものに変える
2. `xcodegen` を実行して `Dosei.xcodeproj` を開く
3. iCloud コンテナ `iCloud.<BUNDLE_ID>` は初回ビルド時に Xcode が作る（Signing & Capabilities で確認）
4. `Dosei-iOS` を実機で、`Dosei-macOS` を Mac で実行

### Swarm

1. https://foursquare.com/developers/apps でアプリを作る
2. Redirect URI に `dosei://swarm` を登録
3. アプリの設定に Client ID を入れて「Swarm でログイン」
   （うまくいかなければ、取得したアクセストークンを直接貼る）

## 構成

```
Packages/DoseiCore   文体の組み立て・日付の区切り・睡眠の判定（プラットフォーム非依存、テストあり）
App/Shared            SwiftUI（iPhone / Mac 共通）、SwiftData + CloudKit、Swarm
App/iOS               HealthKit
```

首相動静の規則は `DoseiFormatter.swift` に書いてある。
`swift test`（`Packages/DoseiCore` で実行）で、その規則どおりに文章が組み立てられることを確かめている。
