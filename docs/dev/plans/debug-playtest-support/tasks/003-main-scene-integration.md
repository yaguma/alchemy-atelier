---
id: "003"
title: "MainSceneにDebugPanelを組み込む"
status: done
priority: 3
dependencies: ["002"]
estimated_complexity: low
---

# Task: MainSceneにDebugPanelを組み込む

## Goal

`main.tscn`に`DebugPanel`を常時最前面の子ノードとして追加し、庭・調合・工房・結果のいずれの画面上でも操作できるようにする。

## Interfaces

```
# atelier/scenes/main.tscn（変更）
# 既存の %SettingsOverlayLayer よりさらに後ろの子として %DebugPanel を配置する
# （描画順で最前面になる。main.gd L38-39のコメント「4画面より後ろの子として配置しているため、
# 描画順で常に最前面になる」と同じ理屈を踏襲）
```

```gdscript
# atelier/scenes/main.gd
# 🟡 DebugPanelは自己完結（OS.is_debug_build()で自ら queue_free() する）ため、
# MainScene側に新規publicメソッドやシグナル購読を追加する必要はない想定。
# ただし実装時にDebugPanelの操作がGameState signal経由で他画面に正しく反映されるかを
# 目視確認すること（例: 次ランクへジャンプ後にRankHud・TabBarの表示が追随するか）
```

## Test Strategy

- [ ] `main.tscn`をロードすると`%DebugPanel`が存在する
- [ ] （通常のテスト実行環境=`OS.is_debug_build()`がtrueの前提で）`%DebugPanel`が`visible`である
- [ ] `%DebugPanel`が他の4画面（GardenScreen/AlchemyScreen/WorkshopScreen/ResultScreen）のいずれの`visible`状態でも操作可能な位置（Zオーダー/描画順）にあることを、子ノード順序（`get_children()`の末尾に近い）で確認する
- [ ] エッジケース: `%DebugPanel`経由で`GameState.debug_jump_to_next_rank()`を呼んだ後、`%RankHud`の表示（現在ランク名等）が更新されること（既存の`GameState`シグナル購読の仕組みがそのまま機能することの確認。新規シグナルは追加しない）

## Implementation Notes

- 参照すべき既存コード: `atelier/scenes/main.tscn`（`%SettingsOverlayLayer`の配置箇所）、`atelier/shared/ui/rank_hud.gd`（ランク表示がどのGameState signalを購読しているか）
- 実装のヒント: シーンファイル（`.tscn`）へのノード追加はGodotエディタで行うか、既存の`.tscn`のテキスト構造（`ext_resource`/`node`ブロック）を直接編集する。他の`shared/ui`コンポーネント（例: `RankHud`）が`main.tscn`にどう組み込まれているかを参考にする。
- 注意事項: `%DebugPanel`は`main.tscn`のuniqueノード名として登録すること（`unique_name_in_owner = true`）。既存の`%SettingsOverlayLayer`等と同じ設定方法に揃える。

## Files

- 変更: `atelier/scenes/main.tscn`
- テスト: `atelier/tests/integration/test_main_scene_debug_panel.gd`
