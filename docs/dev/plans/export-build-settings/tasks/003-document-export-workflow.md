---
id: "003"
title: "READMEにエクスポートビルド手順を追記する"
status: done
priority: 2
dependencies: ["001"]
estimated_complexity: low
---

# Task: READMEにエクスポートビルド手順を追記する

## Goal

`README.md`「開発環境セットアップ」節に、エクスポートテンプレート導入の前提条件と、Windows Desktop向けDebugビルドのエクスポートコマンド例を追記し、次に作業する開発者（自分自身を含む）が迷わず実行できるようにする。

## Interfaces

Markdownドキュメントへの追記（コード変更なし）。追記位置は既存の「環境変数: `GODOT_BIN`」節の直後、「テスト実行」節の直前を想定。

```markdown
### エクスポートテンプレート（初回のみ）

Godotエディタのメニューから「エディタ > エクスポートテンプレートの管理」を開き、
使用中のGodotバージョン（4.7系）に対応するテンプレートをダウンロード・インストールする。
数百MB〜1GB程度のダウンロードを伴うため、CI等では別途キャッシュ戦略が必要（本READMEの対象外）。

## エクスポートビルド（Windows Desktop / Debug）

```bash
godot --headless --path atelier --export-debug "Windows Desktop" build/windows/atelier-alchemy.exe
```

出力先は `atelier/build/windows/atelier-alchemy.exe`（Git管理対象外）。
```

> 🟡 見出しレベル・節の挿入位置は既存README構成から妥当と推測したものであり、`README.md`の既存Markdown構造次第で調整すること。
> 🔴 CI用のテンプレートキャッシュ戦略は本Planのスコープ外（ヒアリングで「CI連携は含めない」と確定済み）。README上でも「本READMEの対象外」と明記し、別Planへの誘導は行うが手順自体は書かない。

## Test Strategy

Directモード対象（TDD対象外）。以下を手動確認する。

- [ ] `README.md`にエクスポートテンプレート導入の前提条件（初回のみ実施する旨）が記載されている
- [ ] `README.md`に記載したエクスポートコマンド例が、タスク001の`export_presets.cfg`の`name="Windows Desktop"`・`export_path`と一致している
- [ ] 既存の「環境変数: `GODOT_BIN`」節・「テスト実行」節の内容・リンクが壊れていない（追記による意図しない削除がないこと）

## Implementation Notes

- 参照すべき既存ファイル: `README.md`（「開発環境セットアップ」節、`GODOT_BIN`の説明パターンを踏襲する）
- タスク001・002の内容（プリセット名・出力パス）が確定してから執筆すること（先に書くと数値の食い違いが起きる）

## Files

- 変更: `README.md`
