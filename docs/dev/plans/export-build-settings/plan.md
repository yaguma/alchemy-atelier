# Plan: export-build-settings

## Requirements Summary

Godotプロジェクト（`atelier/`）にはこれまで`export_presets.cfg`が存在せず、`godot --headless --path atelier --export-release/--export-debug`が実行できない状態だった（`CLAUDE.md`「次のステップ」・`docs/dev/context.md` Build & Runで既知の未着手項目として記録済み）。

ヒアリングで確定したスコープ:

- 対象プラットフォーム: **Windows Desktopのみ**（他OS/Webは将来拡張）
- ビルド種別: **Debugビルドのみ**（配布用Releaseは対象外）
- CI（GitHub Actions）連携: **対象外**（別Planで扱う）
- アプリアイコン: **Godotデフォルトアイコンのまま**（カスタムアイコン作成は別タスク）

前提調査で判明した事実:

- `atelier/project.godot`に`config/icon`指定なし（デフォルトアイコンのまま運用中）
- ローカル環境（`%APPDATA%/Godot/export_templates/`）に**Godot 4.7系のエクスポートテンプレートが未インストール**。これはダウンロード（数百MB〜1GB超）を伴う環境セットアップであり、本Planのタスクとしては実装しない。テンプレート未導入の状態でも`export_presets.cfg`自体は作成・コミット可能（テンプレート導入後に初めてエクスポート実行が成功する）
- `atelier/.gitignore`は現状`.godot/`と`reports/`のみ除外。エクスポート成果物の出力先を除外する設定がない

## Design Overview

3ファイルの変更で完結する設定作業（Directモード、TDD対象外）。

1. **`atelier/export_presets.cfg`（新規）**: `platform="Windows Desktop"`のプリセットを1つ定義。`export_path`はビルド成果物を`atelier/build/windows/atelier-alchemy.exe`に出力する設定とする。Release用オプション（コード署名等）は今回設定しない。
2. **`atelier/.gitignore`（変更）**: `build/`を追加し、エクスポート成果物（バイナリ）がコミット対象に混入しないようにする。
3. **`README.md`（変更）**: 「開発環境セットアップ」節にエクスポートテンプレート導入の前提条件を追記し、エクスポート実行コマンド例（`godot --headless --path atelier --export-debug "Windows Desktop" build/windows/atelier-alchemy.exe`）を記載する。

エクスポートテンプレート自体のダウンロード・インストールはタスク化しない（大容量ダウンロードを伴う環境構築のため、ユーザー自身がGodotエディタの「エディタ > エクスポートテンプレートの管理」またはREADME記載の手順で行う）。

## Task Dependency Graph

```
001 (export_presets.cfg作成)
  └─→ 002 (.gitignoreにbuild/追加)
  └─→ 003 (README更新)
       └─→ 004 (ローカルでのエクスポート実行確認・手動検証)
```

- 001は002・003より先に完了させる（`export_path`の値をgitignoreパターン・README記載コマンドの両方が参照するため）
- 002と003は001完了後、互いに独立して並行実装可能
- 004はエクスポートテンプレート導入（ユーザーの環境構築作業、本Plan範囲外）が完了していることが前提。テンプレート未導入のままでは004は実行不能なため、004は「ブロックされた状態」から開始する想定

## Cross-Plan Dependencies

なし（他Featureのロジック・状態・UIに依存しない、ビルド設定のみのPlan）。将来CI連携Planを作る場合、本Planの`export_presets.cfg`のプリセット名（`"Windows Desktop"`）をGitHub Actionsワークフローから参照することになる。
