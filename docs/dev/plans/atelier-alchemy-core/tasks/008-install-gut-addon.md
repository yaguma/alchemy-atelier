---
id: "008"
title: "GUTアドオンをAssetLib経由で導入する（手動手順）"
status: pending
priority: 2
dependencies: ["001"]
estimated_complexity: low
---

# Task: GUTアドオンをAssetLib経由で導入する（手動手順）

## Goal

GUT（Godot Unit Test）アドオンをGodotエディタのAssetLib経由でインストールする。CON-002によりCLIでの完全自動化は行わず、ユーザーによるGUI手動操作を前提とする。Claude Codeが担当できるのは手順書の提示とインストール後の動作確認までである。

## Interfaces

このタスクはコード実装を伴わない（Directモード、かつ手動操作を含む）。

## Test Strategy

- [ ] Godotエディタで `AssetLib` タブから「Gut」を検索しインストールする（ユーザー手動操作）
- [ ] `Project > Project Settings > Plugins` で GUT プラグインを有効化する（ユーザー手動操作）
- [ ] `atelier-alchemy/addons/gut/` が存在することを確認する
- [ ] インストール後、`godot --headless --path atelier-alchemy -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -ginclude_subdirs -gexit` を実行し、テスト0件でもエラーなく終了する（FR-107前提、この時点ではまだ009のテストが無いため「0 tests, 0 failures」で正常終了することを確認する）

## Implementation Notes

- 参照すべき既存文書: `.claude/rules/bash-commands.md`「Godot / GUT 実行ルール」節
- **手動ステップの明記**: このタスクの一部（AssetLibからのインストール、プラグイン有効化）はユーザーがGodotエディタのGUIで行う必要があり、Claude Codeからは自動化できない（CON-002）。Claude Codeは (1) 手順の提示、(2) インストール完了後の動作確認コマンド実行、を担当する
- ユーザーに手順を案内する際は、Godotエディタを開いた状態で `AssetLib` タブ → 検索窓に "Gut" → インストール、という具体的な操作列を伝える

## Files

- 新規: `atelier-alchemy/addons/gut/`（AssetLib経由でユーザーが導入。Claude Codeによる直接作成対象外）
- 変更: `atelier-alchemy/project.godot`（プラグイン有効化設定、GUI操作で自動反映）
- テスト: なし
