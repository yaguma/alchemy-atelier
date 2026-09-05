---
id: "004"
title: "ローカル環境でWindows Desktopエクスポートを実行し成果物を確認する"
status: done
priority: 3
dependencies: ["001", "002", "003"]
estimated_complexity: low
---

# Task: ローカル環境でWindows Desktopエクスポートを実行し成果物を確認する

## Goal

タスク001〜003で整備したエクスポート設定・ドキュメントが実際に機能することを、ローカル環境での`--export-debug`実行によって検証する。

## Interfaces

該当なし（検証タスクのため新規インターフェースはない）。実行コマンドはタスク003で追記した内容と同一。

```bash
godot --headless --path atelier --export-debug "Windows Desktop" build/windows/atelier-alchemy.exe
```

## Test Strategy

Directモード対象（TDD対象外、実行確認のみ）。

- [ ] **前提**: Godot 4.7系のエクスポートテンプレートがローカル環境（`%APPDATA%/Godot/export_templates/`）にインストール済みであること。未導入の場合はREADME記載の手順（タスク003）で先にインストールする
- [ ] 上記コマンドを実行し、終了コード0で完了する
- [ ] `atelier/build/windows/atelier-alchemy.exe`が生成されている
- [ ] 生成された`.exe`をダブルクリックまたはコマンドラインから起動し、`scenes/boot.tscn`起動→`main.tscn`遷移までクラッシュなく到達する（マスターデータ整合性検証を含む起動シーケンスが実行ファイル単体でも動作することの確認）
- [ ] `git status`で`atelier/build/`配下がuntracked/ignoredのいずれでも「コミット候補」として出てこない（タスク002の`.gitignore`が機能していることの再確認）

## Implementation Notes

- 参照すべき既存ファイル: `atelier/scenes/boot.gd`（起動時のマスターデータ検証ロジック。エクスポートビルドでリソースパスが解決できずに失敗するケースがないか特に確認する）
- 🔴 本タスク実行時点でエクスポートテンプレートが未導入の場合、このタスクは「ブロック」として扱い、テンプレート導入（ユーザーの環境構築作業）を待ってから実施する。テンプレート導入作業自体は本Planのタスクとして分解しない（大容量ダウンロードを伴う環境セットアップのため）
- 手動プレイテストの記録が必要な場合は`.claude/rules/godot-debug-tools.md`のスクリーンショット手順（`user://debug-screenshots/`）を参照。ただしエクスポートビルド（非headless実行）でのみ利用可能

## Files

- 変更なし（検証のみ、生成される`atelier/build/windows/atelier-alchemy.exe`はGit管理対象外）
- レポート: `docs/dev/plans/export-build-settings/reports/verify-<実行日>.md`（検証結果を記録する場合）
