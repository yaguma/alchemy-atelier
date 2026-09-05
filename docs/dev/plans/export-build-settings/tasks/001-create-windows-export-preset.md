---
id: "001"
title: "Windows Desktop向けexport_presets.cfgを作成する"
status: done
priority: 1
dependencies: []
estimated_complexity: low
---

# Task: Windows Desktop向けexport_presets.cfgを作成する

## Goal

`atelier/export_presets.cfg`を新規作成し、Godotエディタの「プロジェクト > エクスポート」機能およびCLI（`godot --headless --path atelier --export-debug "Windows Desktop" <output>`）からWindows Desktop向けDebugビルドが実行できる状態にする。

## Interfaces

Godotの`export_presets.cfg`はGDScriptコードではなくINI形式の設定ファイル。「インターフェース」としてプリセットが満たすべきキーと値を以下に示す（実際のファイルはGodotエディタでプリセットを作成した際の出力形式に厳密に従うこと。手打ちでキー抜けがあるとエディタ/CLIがプリセットを認識しない可能性があるため、可能であれば一度Godotエディタの「プロジェクト > エクスポート > 追加 > Windows Desktop」でプリセットを作成し生成された内容をベースに調整することを推奨する）。

```ini
[preset.0]

name="Windows Desktop"                          # 🔵 ヒアリング確定（対象プラットフォーム: Windows Desktopのみ）
platform="Windows Desktop"                       # 🔵 Godot標準のプラットフォーム識別子
runnable=true                                     # 🔵 ローカル実行可能にする
export_filter="all_resources"                     # 🟡 現状全機能実装済みのため全リソースを含める妥当な選択
export_path="build/windows/atelier-alchemy.exe"   # 🟡 出力先パス・ファイル名は本タスクでの命名決定（プロジェクト内に前例なし）
encrypt_pck=false                                 # 🟡 個人開発・配布未定のため暗号化不要と判断

[preset.0.options]

binary_format/embed_pck=true                      # 🔵 単一exeで配布できるようにする一般的な設定
debug/export_console_wrapper=1                    # 🟡 Debugビルドではコンソール出力を確認したいため有効化
application/product_name="Atelier Alchemy"        # 🔵 project.godotのconfig/nameと一致させる
application/icon=""                                # 🔵 ヒアリング確定（カスタムアイコン未用意、デフォルトのまま）
```

> 🔴 上記は主要キーの抜粋であり、Godot 4.7が実際に要求する完全なキー一覧（`codesign/*`, `ssh_remote_deploy/*`等）はGodotのバージョンに依存する。dev-impl時は上記の意図を踏まえつつ、Godotエディタでプリセットを1つ作成してエクスポートしたファイルの実物を正とすること。

## Test Strategy

本タスクは設定ファイル作成のみのため`implement-workflow.md`のDirectモード対象（TDD対象外）。以下をチェックリストとして手動確認する。

- [ ] `atelier/export_presets.cfg`がリポジトリに追加され、`[preset.0]`セクションに`platform="Windows Desktop"`が設定されている
- [ ] Godotエディタで`atelier/`プロジェクトを開き、「プロジェクト > エクスポート」ダイアログに"Windows Desktop"プリセットが1件表示される（プリセットの構文が壊れていないことの確認）
- [ ] `export_path`が`atelier/build/windows/atelier-alchemy.exe`を指しており、タスク002で`.gitignore`に追加する`build/`パターンと一致している
- [ ] リリース用（`export-release`）の設定・コード署名関連キーを追加していない（今回のスコープはDebugビルドのみ）

## Implementation Notes

- 参照すべき既存ファイル: `atelier/project.godot`（`config/name="Atelier Alchemy"`, `config/features=PackedStringArray("4.7")`）
- エクスポートテンプレート（Godot 4.7系）がローカル未インストールのため、本タスク完了時点では実際の`--export-debug`実行確認はできない（実行確認はタスク004、テンプレート導入はユーザーの環境構築作業として別途行う）
- `docs/dev/context.md`のBuild & Run表に「🔴 export_presets.cfg未作成のため現時点では未実装」と記載されている行を、本タスク完了後に更新する（`docs/dev/context.md`は`/dev-context`再実行で更新するのが望ましいが、軽微な追記であれば直接編集でも可）

## Files

- 新規: `atelier/export_presets.cfg`
