---
id: "001"
title: "UiEffects共通演出ヘルパーとUiTheme演出定数を新設する"
status: done
priority: 1
dependencies: []
estimated_complexity: medium
---

# Task: UiEffects共通演出ヘルパーとUiTheme演出定数を新設する

## Goal

以降の全演出タスク（002, 003, 004, 006, 007, 008, 010, 011, 014, 016, 017）が共通利用する`UiEffects`静的ヘルパーと、`UiTheme`への演出用定数群を追加する。

## Interfaces

```gdscript
# atelier/shared/ui/ui_effects.gd (新規)
class_name UiEffects

## 既存ノードをscale 0→1でポップイン表示する
static func play_pop_in(target: Control, duration: float, ease_type: Tween.EaseType) -> Tween  # 🔵 create_tween()の標準パターン

## sourceの見た目を複製(duplicate())してoverlay_layerに乗せ、from_global(sourceの現在位置)→to_globalへ飛ばして完了後に複製ノードを自壊する。
## 呼び出し元は複製後の元ノードの破棄タイミングを気にしなくてよい（このAPIが複製の寿命を完結して管理する）
static func fly_ghost(overlay_layer: Control, source: Control, to_global_position: Vector2, duration: float) -> Tween  # 🟡 一覧の全破棄再生成方式への対応として新設

## targetをグレー(UiTheme.COLOR_WITHER_FADE_TARGET)へself_modulateし、透明度を0へフェードしてから自壊する
static func play_wither_fade(target: Control, duration: float) -> Tween  # 🟡

## ProgressBar.valueをtween_property()で滑らかにto_valueへ変化させる
static func animate_progress_value(bar: ProgressBar, to_value: float, duration: float) -> Tween  # 🔵

## targetのself_modulateをcolorへ→元の色へ、を往復させるパルス演出（特性発現ハイライト・指定合致キラキラで共用）
static func play_highlight_pulse(target: CanvasItem, color: Color, duration: float) -> Tween  # 🟡
```

```gdscript
# atelier/shared/theme/theme.gd への追加定数（値はこのタスクで仮決定し、後続タスクで使用実績を見て調整可）
const ANIM_DURATION_POP_IN: float = ...        # 🟡 tdd-implementer決定
const ANIM_DURATION_FLY_GHOST: float = ...     # 🟡
const ANIM_DURATION_WITHER_FADE: float = ...   # 🟡
const ANIM_DURATION_QUOTA_BAR: float = ...     # 🟡
const ANIM_DURATION_FADE_SCREEN: float = ...   # 🟡
const ANIM_DURATION_HIGHLIGHT_PULSE: float = ... # 🟡
const ANIM_EASE_DEFAULT: Tween.EaseType = ...  # 🟡
const COLOR_WITHER_FADE_TARGET: Color = ...    # 🟡
const COLOR_TOAST_WARNING: Color = ...         # 🟡
const COLOR_TRAIT_HIGHLIGHT: Color = ...       # 🟡
const COLOR_ORDER_MATCHED_HIGHLIGHT: Color = ... # 🟡
```

## Test Strategy

- [ ] `play_pop_in()`を呼ぶと戻り値が有効な`Tween`であり、`target.scale`が`(0,0)`から`(1,1)`へ向けて変化を開始する
- [ ] `fly_ghost()`を呼ぶと`overlay_layer`の子ノード数が1増える（複製が追加される）
- [ ] `fly_ghost()`の`Tween.finished`後、`overlay_layer`の子ノード数が呼び出し前と同じに戻る（複製が自壊している）
- [ ] `play_wither_fade()`を呼ぶと`target.modulate.a`が1.0から0.0へ向けて変化を開始する
- [ ] `animate_progress_value()`を呼ぶと`bar.value`が即座にはto_valueにならず、`Tween.finished`後にto_valueと一致する
- [ ] `play_highlight_pulse()`を呼ぶと`target.self_modulate`が変化し、`Tween.finished`後に元の色へ戻っている
- [ ] エッジケース: `duration <= 0.0`を渡した場合でもクラッシュせず即完了する

## Implementation Notes

- 参照すべき既存コード: `atelier/shared/theme/button_style_applier.gd`, `atelier/shared/ui/pixel_backdrop_applier.gd`（同種のstatic適用クラスパターン）
- `.claude/rules/godot-best-practices.md`「リソース破棄」参照: `create_tween()`はノードにアタッチされ自動停止するため、`fly_ghost()`内で生成するTweenは複製ノードにアタッチする（`duplicate_node.create_tween()`）
- `fly_ghost()`の複製ノードは`overlay_layer.add_child()`後、`global_position`を`source`の現在位置に合わせてから`tween_property(dup, "global_position", to_global_position, duration)`し、`tween.finished`で`dup.queue_free()`する
- GameBalance/UiThemeの判断基準（`.claude/rules/coding-style.md`）に従い、演出値はすべてUiTheme側に定義する

## Files

- 新規: `atelier/shared/ui/ui_effects.gd`
- 変更: `atelier/shared/theme/theme.gd`
- テスト: `atelier/tests/unit/shared/test_ui_effects.gd`
