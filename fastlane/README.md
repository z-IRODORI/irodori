fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios status

```sh
[bundle exec] fastlane ios status
```

キーの確認と、TestFlight にある最新のビルド番号

### ios beta

```sh
[bundle exec] fastlane ios beta
```

テスト → バージョン・ビルド番号 → アーカイブ → dSYM → TestFlight（dry_run:true ならアップロードしない）

### ios submit

```sh
[bundle exec] fastlane ios submit
```

ストア文言を反映し、TestFlight の最新ビルドで審査に提出する（確認あり。通過後は自動公開）

### ios metadata_pull

```sh
[bundle exec] fastlane ios metadata_pull
```

App Store Connect の現在の文言を metadata/ に取り込む（スクリーンショットは取り込まない）

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
