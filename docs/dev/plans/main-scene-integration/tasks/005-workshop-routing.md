---
id: "005"
title: "MainSceneに工房への往復ルーティングを実装する"
status: done
priority: 2
dependencies: ["002"]
estimated_complexity: low
---

# Task: MainSceneに工房への往復ルーティングを実装する

## Goal

`GardenScreen`/`AlchemyScreen`の既存`shop_requested` signalを`MainScene`が購読し工房強化画面へ切り替え、`WorkshopScreen.screen_closed`受信時に工房を開く直前のフェーズへ復帰させる。

## Interfaces

```gdscript
# atelier/scenes/main.gd への追加
var _phase_before_workshop: StringName = &"garden"
# 🟡 例外的にGameStateと二重保持する一時変数（requirements.md AC-004の許容例外）。
# GameStateにこの情報を持たせる新規フィールドは追加しない（FR-404）

# _ready()に追加:
#   _garden_screen.shop_requested.connect(_on_shop_requested)
#   _alchemy_screen.shop_requested.connect(_on_shop_requested)
#   _workshop_screen.screen_closed.connect(_on_workshop_closed)

func _on_shop_requested() -> void:  # 🔵 FR-104
	_phase_before_workshop = GameState.get_state()["current_phase"]
	GameState.set_phase(&"workshop")

func _on_workshop_closed() -> void:  # 🔵 FR-105
	GameState.set_phase(_phase_before_workshop)
```

## Test Strategy

- [ ] garden フェーズ表示中に `GardenScreen.shop_requested` を発行させると `workshop` フェーズへ切り替わる
- [ ] alchemy フェーズ表示中に `AlchemyScreen.shop_requested` を発行させると `workshop` フェーズへ切り替わる
- [ ] `WorkshopScreen.screen_closed` 発行後、工房を開く直前が garden なら garden へ、alchemy なら alchemy へ復帰する
- [ ] **異常系**: 直前フェーズの記録が無い状態（例えば `_phase_before_workshop` の初期値である `&"garden"` のまま）で `screen_closed` を受けた場合、既定の `&"garden"` へ復帰する
- [ ] **境界値**: workshop 表示中に再度 `shop_requested` を受けても `_phase_before_workshop` が `&"workshop"` に上書きされない（`current_phase`が既に`workshop`の場合は記録を更新しない）

## Implementation Notes

- 参照すべき既存コード: `atelier/features/workshop/ui/workshop_screen.gd:151-154`（`_on_close_pressed()`が`GameState.close_workshop()` → `_refresh()` → `screen_closed.emit()`の順で呼ぶ既存実装。本タスクでは`workshop_screen.gd`自体は変更しない）
- 実装のヒント: `_on_shop_requested()`内で`current_phase`が既に`&"workshop"`の場合は`_phase_before_workshop`を更新しない（境界値ケースの対応）。これにより「workshop表示中の二重shop_requested」で記録が破壊されない。
- 注意事項: `GardenScreen`/`AlchemyScreen`は無改修（CON-003）。両者とも既存の`shop_requested`シグナルをそのまま利用するだけでよい。

## Files

- 変更: `atelier/scenes/main.gd`
- テスト: `atelier/tests/integration/test_main_scene_workshop_routing.gd`（新規）
