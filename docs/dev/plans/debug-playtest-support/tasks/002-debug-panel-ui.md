---
id: "002"
title: "DebugPanelシーン/スクリプトを実装する"
status: done
priority: 2
dependencies: ["001"]
estimated_complexity: medium
---

# Task: DebugPanelシーン/スクリプトを実装する

## Goal

デバッグビルド限定で画面上に常設表示される小さな操作パネル（ゴールド付与・ノルマ即達成・次ランクへジャンプの3ボタン）を、`GameState`のデバッグAPI（task 001）に接続する形で実装する。

## Interfaces

```gdscript
# atelier/shared/debug/debug_panel.gd（新規）
class_name DebugPanel
extends Control

# 🔵 godot-debug-tools.md「将来検討」欄の設計方針（OS.is_debug_build()ガード必須）に準拠。
# _ready()冒頭でOS.is_debug_build()が偽ならqueue_free()し、以降の初期化を一切行わない
func _ready() -> void

func _on_add_gold_pressed() -> void       # GameState.debug_add_gold()を呼ぶ
func _on_force_end_turn_pressed() -> void # GameState.debug_force_end_turn()を呼ぶ
func _on_jump_rank_pressed() -> void      # GameState.debug_jump_to_next_rank()を呼ぶ
```

```
# atelier/shared/debug/debug_panel.tscn（新規）
# Control（左上または右上隅に固定配置）
# └─ VBoxContainer
#     ├─ Button（%AddGoldButton、テキスト例: "G+1000"）
#     ├─ Button（%ForceEndTurnButton、テキスト例: "ノルマ即達成"）
#     └─ Button（%JumpRankButton、テキスト例: "次ランクへ"）
```

## Test Strategy

- [ ] `DebugPanel`をシーンツリーに追加すると（`OS.is_debug_build()`がtrueの通常のテスト実行環境では）3つのボタンが存在し、`visible`である
- [ ] `%AddGoldButton`を押すと`GameState.get_state()["gold"]`が増加する
- [ ] `%ForceEndTurnButton`を押すと、納品待ち（`pending_products`）がある状態でそれが処理される（task 001の`debug_force_end_turn()`が呼ばれたことを、`pending_products`が空になることで間接的に確認する）
- [ ] `%JumpRankButton`を押すと`GameState.get_state()["current_rank_id"]`が次ランクへ変わる
- [ ] エッジケース: ボタン押下がGameStateへの状態変更を素通りさせない設計になっているか（`Button.disabled`はコード経由のpressed発行を止めないため、GameState側のガード＝task 001が実際の可否を決めることを確認する。ゴールド付与ボタンには元々disabled条件が無いため、この観点は主に将来ボタンにdisabled条件を追加する場合の注意点としてコメントで残す）

## Implementation Notes

- 参照すべき既存コード:
  - `atelier/shared/ui/pause_menu.gd`（`Control`常設オーバーレイの実装パターン、`main.tscn`への組み込まれ方）
  - `atelier/features/garden/ui/garden_screen.gd`（ボタンpressed接続の書き方）
  - `.claude/rules/godot-debug-tools.md`「将来検討: 開発用デバッグコンソール」節（`OS.is_debug_build()`ガードの設計意図）
- 実装のヒント: 本パネルはQA専用でありプレイヤー向け画面ではないため、`design-guide.md`のボタンバリアント（PRIMARY/SECONDARY/DANGER/TERTIARY）やドット絵アセットには従わなくてよい。標準の`Button`をそのまま使い、視覚的に「デバッグ用」と分かる簡易な見た目（例: 半透明の黒背景パネル）で十分。
- 注意事項: `_ready()`で`queue_free()`する場合、`@onready`変数の解決や以降の`_ready()`処理（シグナル接続等）を実行してはならない。`OS.is_debug_build()`チェックを`_ready()`の最初の行に置き、偽の場合は即座に`return`すること。

## Files

- 新規: `atelier/shared/debug/debug_panel.gd`
- 新規: `atelier/shared/debug/debug_panel.tscn`
- テスト: `atelier/tests/integration/shared/test_debug_panel.gd`
