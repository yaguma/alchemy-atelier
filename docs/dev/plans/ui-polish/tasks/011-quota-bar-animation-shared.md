---
id: "011"
title: "ランクノルマバーの減少アニメーションをguild/rank_hud共通で追加する"
status: done
priority: 2
dependencies: ["001"]
estimated_complexity: medium
---

# Task: ランクノルマバーの減少アニメーションをguild/rank_hud共通で追加する

## Goal

ギルド納品画面の貢献度反映時にランクノルマバーが滑らかに減少するアニメーションを追加する（`guild-delivery.md` L70）。`RankHud`（常時表示の共通UI）にも同じノルマバーがあるため、共通化して実装する。タスク015（昇格試験の試験ノルマ演出）がこの実装を流用する前提。

## Interfaces

```gdscript
# atelier/features/guild/ui/guild_delivery_screen.gd の既存 _refresh_rank_quota() を変更
func _refresh_rank_quota(animate: bool = false) -> void
# animate=false: 従来通り瞬時反映（_ready()からの初期呼び出し用）
# animate=true:  UiEffects.animate_progress_value() を使い滑らかに変化（display_results()から呼ぶ）
```

```gdscript
# atelier/shared/ui/rank_hud.gd の該当ノルマバー更新メソッドにも同様の animate 引数を追加（既存メソッド名に合わせる）
```

## Test Strategy

- [ ] `_refresh_rank_quota(animate=false)`は即座に`ProgressBar.value`を目標値に設定する（既存動作を維持）
- [ ] `_refresh_rank_quota(animate=true)`は即座には目標値にならず、`Tween.finished`後に目標値と一致する
- [ ] `RankHud`側の同名メソッドも同様に`animate`引数で挙動が切り替わる
- [ ] エッジケース: 目標値が現在値と同じ場合、アニメーションなしで即完了扱いになる（0秒Tweenでもクラッシュしない）

## Implementation Notes

- 参照すべき既存コード: `atelier/features/guild/ui/guild_delivery_screen.gd`の`_refresh_rank_quota()`, `atelier/shared/ui/rank_hud.gd`
- タスク001の`UiEffects.animate_progress_value()`を両箇所で共用する
- `RankHud`はAutoloadではなく共有UIコンポーネントのため、`GameState`シグナル購読パターン（`.claude/rules/state-management.md`）に従い、既存の購読箇所から`animate`の要否を判断する

## Files

- 変更: `atelier/features/guild/ui/guild_delivery_screen.gd`, `atelier/shared/ui/rank_hud.gd`
- テスト: `atelier/tests/integration/test_guild_delivery_screen_quota_bar_animation.gd`, `atelier/tests/integration/test_rank_hud_quota_bar_animation.gd`
