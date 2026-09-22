---
id: "010"
title: "ギルド納品画面の表示演出（フェードイン+完成品ポップ）を追加する"
status: done
priority: 2
dependencies: ["001"]
estimated_complexity: medium
---

# Task: ギルド納品画面の表示演出（フェードイン+完成品ポップ）を追加する

## Goal

ギルド納品画面表示時にフェードイン+完成品アイコンのポップ演出を追加する（`guild-delivery.md` L69）。表示トリガーは`AlchemyScreen._deliver_and_display()`内の`_guild_delivery_screen.visible = true`の1箇所のみで、他画面のようなフェーズ遷移の競合は無い。

## Interfaces

```gdscript
# atelier/features/guild/ui/guild_delivery_screen.gd への追加
func show_with_animation() -> void  # 🔵 modulate.a: 0→1 のフェードイン後、各結果行に UiEffects.play_pop_in() を順次適用
```

```gdscript
# atelier/features/alchemy/ui/alchemy_screen.gd の _deliver_and_display() を変更
# 変更: _guild_delivery_screen.visible = true の直書きを _guild_delivery_screen.show_with_animation() に置換
#      （show_with_animation()内部で visible = true を含めて処理する）
```

## Test Strategy

- [ ] `show_with_animation()`呼び出し直後、`visible`が`true`になり`modulate.a`が0から1へ向けて変化を開始する
- [ ] 各結果行（`GuildDeliveryResultRow`）に対して`play_pop_in()`相当の演出が順次適用される
- [ ] 演出完了後、画面は完全に不透明（`modulate.a == 1.0`）で全結果行が表示されている
- [ ] エッジケース: 結果行が0件（該当ケースがあれば）でもフェードイン自体はクラッシュせず完了する

## Implementation Notes

- 参照すべき既存コード: `atelier/features/alchemy/ui/alchemy_screen.gd`の`_deliver_and_display()`, `atelier/features/guild/ui/guild_delivery_screen.gd`
- 「各結果行に順次適用」は`Tween`のchain（`tween.tween_callback()`等）や`await get_tree().create_timer()`によるオフセットが選択肢（🟡tdd-implementer裁量）

## Files

- 変更: `atelier/features/guild/ui/guild_delivery_screen.gd`, `atelier/features/alchemy/ui/alchemy_screen.gd`
- テスト: `atelier/tests/integration/test_guild_delivery_screen_show_animation.gd`
