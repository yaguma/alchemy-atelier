---
id: "009"
title: "BootScene/MainSceneへセーブロードフローを結線する"
status: done
priority: 4
dependencies: ["007", "008"]
estimated_complexity: medium
---

# Task: BootScene/MainSceneへセーブロードフローを結線する

## Goal

`BootScene`の遷移先を`SlotSelectScreen`に変更し、`MainScene._enter_tree()`の末尾でマスターデータロード後に保留復元を適用することで、起動→スロット選択→ゲーム再開/新規開始のフローをエンドツーエンドで成立させる。

## Interfaces

```gdscript
# atelier/scenes/boot.gd の変更
func _ready() -> void:
	_apply_theme()
	_status_label.text = "アトリエ 起動確認"
	if not MasterDataLoader.validate_references([]):
		push_error("マスターデータのID相互参照が解決できません")
		return
	# 変更点: 遷移先をslot_select_screen.tscnに変更する（🔵 既存のcall_deferred遅延パターンは維持）
	get_tree().change_scene_to_file.call_deferred("res://features/save_load/ui/slot_select_screen.tscn")
```

```gdscript
# atelier/scenes/main.gd の _enter_tree() の変更（末尾に1行追記）
func _enter_tree() -> void:
	GameState.load_garden_master_data()
	GameState.load_alchemy_master_data()
	GameState.load_workshop_master_data()
	GameState.load_rank_master_data()
	GameState.load_daily_order_master_data()
	SaveService.apply_pending_restore()  # 🔵 新規追記。マスターデータロード完了後に限定する（plan.md参照）
```

## Test Strategy

- [ ] `BootScene`をシーンとして起動すると、`res://features/save_load/ui/slot_select_screen.tscn`への遷移が呼ばれる（`scene_runner()`で`change_scene_to_file`呼び出しを検証、または遷移後のシーンルートのクラス名を確認）
- [ ] **E2Eラウンドトリップ（新規開始）**: 新規スロットを選択→`main.tscn`到達後、`GameState.get_state()`が初期状態（`gold == 0`, `current_phase == "garden"`）のままである
- [ ] **E2Eラウンドトリップ（続きから）**: 事前に`SaveService.save_to_slot(n)`で`gold=500`等の状態を保存→スロット選択画面で同じスロットを選択→`main.tscn`到達後、`GameState.get_state()["gold"] == 500`が復元されている
- [ ] **回帰確認**: 既存の`atelier/tests/integration/test_main_scene_*.gd`群（`main.tscn`を`scene_runner()`で直接起動し`BootScene`を経由しない）が全てGreenのままである（`SaveService.active_slot`が既定値`-1`のままのため`apply_pending_restore()`が空振りし、既存の初期状態前提のテストに影響しないことを確認する）
- [ ] 指定依頼を含む状態（`current_daily_order`が非null）を保存→復元した場合、`main.tscn`到達後の`GameState.resolve_daily_order_for_delivery()`が正しいDailyOrderMasterを返す（マスターデータ参照解決の順序問題が実際に解消されていることの確認、plan.md「マスターデータ参照解決の順序問題と対策」節の検証）

## Implementation Notes

- 参照すべき既存コード: `atelier/scenes/boot.gd`, `atelier/scenes/main.gd`の`_enter_tree()`（既存の5行の`load_*_master_data()`呼び出し順序は変更しないこと。指定依頼の初回抽選がランクマスターロード後である必要があるという既存コメントの制約に従う）
- 実装のヒント: E2Eテストは`scene_runner("res://scenes/boot.tscn")`から開始し、`await`で複数フレーム進めてシーン遷移を待つ（`.claude/rules/testing.md`「E2E相当のテスト」参照）。もしくは`BootScene`と`MainScene`を別々に検証し、`SaveService`経由の状態受け渡し部分のみを結合確認する分割アプローチでもよい
- 注意事項: 本タスク完了時点で`.claude/rules/implement-workflow.md`のコミット前チェックリスト（全テスト・gdlint・gdformat --check）を必ず実行し、既存テストの回帰がないことを最終確認する。あわせて`CLAUDE.md`の「セーブ/ロード機能は設計スコープ外」という記載を更新するかはこのPlanの範囲外（ドキュメント更新は別途ユーザーに確認する）

## Files

- 変更: `atelier/scenes/boot.gd`
- 変更: `atelier/scenes/main.gd`
- テスト: `atelier/tests/integration/test_boot_to_slot_select_flow.gd`
- 回帰確認対象（変更しない）: `atelier/tests/integration/test_main_scene_*.gd`（既存ファイル群）
