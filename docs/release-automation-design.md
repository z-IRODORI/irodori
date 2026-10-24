# iOS リリース自動化 設計（fastlane をこの Mac で動かす）

作成: 2026-10-25 / 対象: IRODORI iOS（`irodori.xcodeproj`, scheme `irodori`, bundle ID `com.gmail.yuukirinnma.irodori`, チーム `BR3T8YBB5L`, 自動署名）

NoMuu（Nomiers）で導入済みの仕組み（`NoMuu/docs/release-automation-design.md`、`ios/NoMuu/fastlane/`）を土台にし、IRODORI で違うところだけ変える。

## 1. 目的と範囲

手作業の「ビルド番号を上げる → アーカイブ → Organizer からアップロード → App Store Connect で入力 → 審査に出す」を、コマンドで再現できるようにする。

| 段階 | コマンド | 自動でやること | 人がやること |
|---|---|---|---|
| 1 | `fastlane beta [version:3.6.0] [dry_run:true]` | 事前チェック → テスト → バージョン・ビルド番号 → アーカイブ → TestFlight → タグ | TestFlight で動作確認 |
| 2 | `fastlane submit` | ストア文言の反映 → 審査に提出（最後に確認を 1 回挟む） | 提出の承認、審査結果への対応 |
| 補助 | `fastlane metadata_pull` | App Store Connect の今の文言を `fastlane/metadata/` に取り込む（初回） | 取り込んだ文言の確認 |
| 補助 | `fastlane status` | API キーの確認、TestFlight の最大ビルド番号、次に使う番号 | なし |

範囲外: 審査で不承認になったときの返信、年齢区分・プライバシー申告の変更、スクリーンショットの自動撮影、API（Render）のデプロイ（main への push で自動デプロイ済み）。

## 2. 現状（2026-10-25 に確認）

| 項目 | 値 | 確認方法 |
|---|---|---|
| App Store のアプリ名 | IRODORI - コーディネートレビュー | App Store Connect API |
| 公開中のバージョン | 3.5.0（READY_FOR_SALE）、編集中のバージョンなし | 同上 |
| TestFlight の最大ビルド | 3.5.0 / 35000 | 同上 |
| API キー | NoMuu と同じチームのキー（Key ID TZ6Q33525V）で IRODORI も読めた | `latest_testflight_build_number` |
| ターゲット | 本体 3.5.0 / 35000、通知拡張 3.5.0 / 35000、テスト 2 つは 1.0 / 1 | project.pbxproj |
| テスト | `irodoriTests`（7 ファイル）。**scheme の TestAction にテスト対象が登録されていない**（自動生成のテストプラン） | irodori.xcscheme |
| 暗号化の申告 | `ITSAppUsesNonExemptEncryption` が Info.plist に無い（毎回質問される） | Info.plist |
| プッシュ通知 | entitlements は `aps-environment = development`（配布用の書き出しで production になるかを dry run で確認する） | irodori.entitlements |
| Crashlytics | SDK は入っているが dSYM のアップロード（Run Script）が無い → クラッシュが記号化されない | project.pbxproj |
| fastlane | 2.241.1（Homebrew。NoMuu と共用） | `fastlane --version` |

## 3. 全体の流れ

```
fastlane beta version:3.6.0
  ├─ preflight       main・未コミットなし・空き 20GB 以上・ほかの xcodebuild なし・本番 API が応答する
  ├─ test            irodoriTests を iPhone 16 Pro（共有端末 7AFD0EE9…）で、並列テストなし
  ├─ set_version     本体・通知拡張・テストの MARKETING_VERSION / CURRENT_PROJECT_VERSION を揃える
  ├─ set_build       ビルド番号を決める（§5）
  ├─ archive         Release でアーカイブ → .ipa（App Store 用）
  ├─ dsym            Crashlytics に dSYM を送る（§6）
  ├─ upload          TestFlight へ（処理完了を待つ・内部テスターのみ）
  └─ finish          バージョンのコミット → タグ ios/v3.6.0-36000 → push、.ipa を削除

fastlane submit
  ├─ preflight       TestFlight に該当バージョンのビルドがあること
  ├─ deliver         説明文・更新内容・審査メモを反映し、ビルドを選ぶ
  ├─ confirm         提出内容を表示して y/n（自動実行でも必ず止まる）
  └─ submit          審査に提出（承認後は自動公開・段階的リリース）
```

## 4. ファイル構成

```
irodori/                              # iOS リポジトリのルート
├── fastlane/
│   ├── Appfile                       # bundle ID・チーム ID（秘密情報なし）
│   ├── Fastfile                      # レーン（NoMuu の Fastfile を移植し、§9 の差分を入れる）
│   ├── metadata/ja/                  # ストア文言（初回は metadata_pull で取り込む）
│   │   ├── release_notes.txt         # 今回の更新内容（beta の前に書き換える）
│   │   └── description.txt / keywords.txt / promotional_text.txt / …
│   ├── metadata/review_information/  # 審査の連絡先・デモアカウント（.gitignore）
│   └── README.md
├── build/                            # .ipa の一時置き場（.gitignore 済み。アップロード後に消す）
└── docs/release-automation-design.md # この文書

~/.appstoreconnect/                   # リポジトリの外（600）
├── AuthKey_TZ6Q33525V.p8             # NoMuu と共用（同じチームのキー）
└── irodori.env                       # ASC_KEY_ID / ASC_ISSUER_ID / ASC_KEY_PATH / 審査用デモの電話番号・確認コード
```

キーは同じものを使い、`irodori.env` は審査用デモアカウントだけ IRODORI のものにする（NoMuu の env を書き換えない）。

## 5. バージョンとビルド番号

これまでの決まりは「各桁をつなげた値 + 下 2 桁の通し番号」（1.1.6 → 11600、2.2.0 → 22003・22004、2.3.0 → 23001、3.0.0 → 30001、3.5.0 → 35000）。再提出のたびに下 2 桁を手で上げていた。

- 基準値 = `MAJOR` + `MINOR` + `PATCH` + `00`（3.6.0 → `36000`、3.6.1 → `36100`）。MINOR / PATCH が 10 以上になったら 2 桁にする（3.10.0 → `310000`）。数が増える方向なので、App Store の「前より大きいこと」は守られる。
- 実際の番号 = max(基準値, そのバージョンで TestFlight にある最大のビルド番号 + 1)。再アップロードは 36000 → 36001 と自動で上がる。
- 書き込み先は本体・通知拡張・テスト 2 つの全部（テストだけ 1.0 / 1 のままなのを揃える）。
- `version:` を省略すると今のバージョンのまま、ビルド番号だけ上げる（作り直し用）。

## 6. IRODORI だけの対応

1. **テストを scheme に登録する**: `irodori.xcscheme` の TestAction に `irodoriTests` を入れる（今は空で、`run_tests` が「テスト対象なし」で失敗する）。初回の dry run で、今のテストがすべて通るかを確かめる。
2. **暗号化の申告**: 通信は HTTPS（Firebase・自前 API）だけで独自の暗号は使っていない想定 → `ITSAppUsesNonExemptEncryption = NO` を Info.plist に入れる（**要確認**）。
3. **Crashlytics の dSYM**: アーカイブ後に `upload_symbols_to_crashlytics(gsp_path: GoogleService-Info.plist)` を呼ぶ。今までのリリースはクラッシュが記号化されていない。
4. **プッシュ通知の環境**: 書き出した .ipa の entitlements が `aps-environment = production` になっているか、dry run で `codesign -d --entitlements` で確かめる（玄関カメラの通知が本番で届かない事故を防ぐ）。
5. **本番 API との順序**: iOS は本番 API（`irodori-api.onrender.com`）の新しいエンドポイントに依存することが多い。preflight で `/health` が 200 を返すことを確かめる。依存する API が main に入っているかは、リリースノートを書くときに人が確認する。
6. **開発用の画面**: 改善案・Sandbox・リニューアル体験の入口は `#if DEBUG` で囲ってあり、Release には出ない。Release ビルドで入口が出ないことを、TestFlight での確認項目に入れる。
7. **作業中のファイル**: preflight は「未コミットなし」を求める。手元に作業中の変更（ホームの 2 ファイル）がある間は beta が止まるので、stash するかコミットしてから流す（勝手に stash はしない）。
8. **ブランチの決まり**: IRODORI は feature ブランチで作業して main に入れる運用。リリースのバージョン上げだけは、レーンが main に直接コミット・タグ・push する（NoMuu と同じ）。

## 7. 審査への提出（submit）

- 公開方法: 審査通過後に**自動で公開**する（`automatic_release: true`）。段階的リリース（7 日かけて自動アップデートの対象を広げる）は有効のまま（`phased_release: true`）。不具合が見つかったら App Store Connect で段階的リリースを一時停止できる（2026-10-25 決定。NoMuu は手動公開）。
- ログインは電話番号認証（Firebase）。審査用に **Firebase のテスト用電話番号と確認コード**を用意し、`irodori.env` から審査メモに差し込む（リポジトリに書かない）。
- 審査メモ（`review_information/notes.txt`）: ログイン手順、ホームの 3 案・カメラ・相棒画面の見方。玄関カメラ（ラズパイ）は実機が無いと試せないので「任意の機能」と書く。
- スクリーンショット: 変更があるときだけ `metadata/` に置いて渡す（通常は `skip_screenshots`）。
- 広告 ID: 広告 SDK・ATT はコードに無い（2026-10-25 確認）ので `add_id_info_uses_idfa: false`。

## 8. 安全装置

- **審査提出と TestFlight の外部配布は外部への公開にあたる。Claude は利用者の明示の指示なしに `submit` を実行しない。** IRODORI の CLAUDE.md に明記し、レーン側でも y/n を必須にする（省略手段は作らない）。
- preflight で止める条件: main 以外、未コミットあり、空き 20GB 未満、ほかの xcodebuild が実行中、本番 API が応答しない。
- ビルドは既存の DerivedData を使い（`derived_data_path` を指定しない）、テストは `parallel_testing: false`（`~/.claude/CLAUDE.md`）。
- 途中で失敗したらバージョンの書き換えを元に戻す。アップロード後の失敗はタグを打たずに止める。

## 9. NoMuu の Fastfile からの差分

| 項目 | NoMuu | IRODORI |
|---|---|---|
| PROJECT / SCHEME | `nomuu.xcodeproj` / `nomuu` | `irodori.xcodeproj` / `irodori` |
| テスト | `nomuuTests`、iPhone 17 | `irodoriTests`、iPhone 16 Pro（7AFD0EE9-870F-4C7A-A502-466A490F7499） |
| env | `nomiers.env` | `irodori.env`（キーは共用） |
| ビルド番号 | MAJOR + MINOR(2 桁) + PATCH(2 桁) | MAJOR + MINOR + PATCH + 通し番号 2 桁（§5） |
| 公開方法 | 審査通過後に手動公開 | 審査通過後に自動公開（段階的リリースあり） |
| 追加の処理 | — | Crashlytics の dSYM、本番 API の確認、entitlements の確認 |
| タグ | `ios/v1.12.0-11200` | `ios/v3.6.0-36000` |

## 10. 導入手順

| # | 作業 | 担当 |
|---|---|---|
| 1 | §11 の確認事項に答える | 利用者 |
| 2 | Firebase に審査用のテスト電話番号を登録し、番号とコードを伝える（または Claude が `irodori.env` の雛形を作り、利用者が書き込む） | 利用者 |
| 3 | Appfile・Fastfile・`irodori.env` の雛形・.gitignore を作る。scheme にテストを登録、Info.plist に暗号化の申告 | Claude |
| 4 | `fastlane status` でキーと番号を確認、`fastlane metadata_pull` でストア文言を取り込む | Claude → 利用者が文言を確認 |
| 5 | `fastlane beta dry_run:true` でテスト・アーカイブ・署名・entitlements まで確認（アップロードしない） | Claude |
| 6 | 次のリリース（3.6.0）で `fastlane beta` を通しで実行し、TestFlight に届くことを確認 | 利用者の指示で Claude |
| 7 | `fastlane submit` で審査に提出（初回は利用者の立ち会いのもと） | 利用者の指示で Claude |

## 11. 確認事項（決めてほしいこと）

決まったこと: 公開方法は審査通過後の自動公開（2026-10-25）。


1. 次のバージョン: **3.6.0**（ビルド 36000）でよいか。
2. TestFlight: 内部テスターのみ（外部配布なし）でよいか。
3. 暗号化: HTTPS のみ（独自の暗号なし）として `ITSAppUsesNonExemptEncryption = NO` を入れてよいか。
4. 審査用デモアカウント: Firebase のテスト用電話番号を新しく用意するか、既にあるものを使うか。
5. Crashlytics の dSYM アップロードを beta に入れてよいか。
