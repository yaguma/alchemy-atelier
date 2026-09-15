---
id: "001"
title: "UiPanelStyleBox基盤クラスを新設する"
status: done
priority: 1
dependencies: []
estimated_complexity: high
---

# Task: UiPanelStyleBox基盤クラスを新設する

## Goal

縦グラデーション塗り・縁取り・内側ハイライト/内側下部シャドウ・外側ドロップシャドウを1つの`StyleBox`で表現できる、角丸対応のカスタム`StyleBox`クラスを新設する。以降のボタン/カードStyleBoxの描画基盤となる。

> 🔴 本タスクは`docs/dev/plans/screen-design-update/tasks/001-ui-panel-stylebox.md`と同一インターフェースで再実施するものである。当該Planはfrontmatterが`done`・検証レポートも全PASSを記録しているが、`git log --all`で確認した結果`atelier/shared/theme/ui_panel_stylebox.gd`はリポジトリのどのコミットにも存在しない（未実装）。本タスクは実際にファイルを作成し、コミット可能な状態にすることが目的。

## Interfaces

```gdscript
# shared/theme/ui_panel_stylebox.gd
class_name UiPanelStyleBox
extends StyleBox

@export var corner_radius: int = 10          # 🟡 design-guide.md未確定のため暫定値
@export var border_width: int = 2            # 🟡
@export var border_color: Color = Color.WHITE
@export var gradient_top_color: Color = Color.WHITE
@export var gradient_bottom_color: Color = Color.WHITE
@export var highlight_color: Color = Color(1, 1, 1, 0.75)      # 🟡 上端ハイライトのアルファ
@export var inner_shadow_color: Color = Color(0, 0, 0, 0.3)    # 🟡 下端の凹み影のアルファ
@export var draw_outer_shadow: bool = true
@export var outer_shadow_color: Color = Color(0, 0, 0, 0.16)   # 🟡
@export var outer_shadow_size: int = 5                          # 🟡

func _draw(to_canvas_item: RID, rect: Rect2) -> void: ...       # 🔴 Godot仕様上RenderingServer.canvas_item_add_polygon()を直叩き
func _get_minimum_size() -> Vector2: ...                        # 🔵 StyleBoxの既定オーバーライド（border_width*2を返す）

# 角丸ポリゴン頂点計算（ユニットテスト用に独立させる）
static func _build_rounded_rect_points(rect: Rect2, radius: float) -> PackedVector2Array: ...  # 🔴
```

`_draw()`内部の描画順序（信号機: 🔴 具体的な頂点計算・ポリゴン近似手法はAI裁量で決定）:
1. 外側ドロップシャドウ（`draw_outer_shadow`が真の場合、`outer_shadow_size`分オフセットした低アルファの角丸ポリゴンを先に描画）
2. 縁取り色の角丸矩形ポリゴン（フルサイズ、単色）
3. 内側（`border_width`分だけ内側にオフセット）に`gradient_top_color`→`gradient_bottom_color`の頂点カラー付き角丸ポリゴン（縦グラデーション本体）
4. 上端に`highlight_color`の半透明帯（薄い矩形またはポリゴン）
5. 下端に`inner_shadow_color`の半透明帯

角丸矩形は各コーナーを円弧サンプリング（例: 1コーナーあたり8〜12分割）してポリゴン近似する。

## Test Strategy

GdUnit4でのユニットテスト（`tests/unit/shared/theme/test_ui_panel_stylebox.gd`）:

- [ ] `_get_minimum_size()`が`border_width`に応じた最小サイズ（`Vector2(border_width*2, border_width*2)`）を返す
- [ ] `corner_radius=0`かつ矩形サイズが極小（例: `Rect2(0,0,4,4)`）でも`_build_rounded_rect_points()`がエラーなく完了する
- [ ] `_build_rounded_rect_points()`が返す頂点配列が矩形の4辺・4角を正しく囲む（境界チェック: 全頂点が`rect`を`outer_shadow_size`分広げた範囲内に収まる）
- [ ] `corner_radius`が矩形の短辺の半分を超える場合にクランプされる（境界値: 極端に小さい矩形に大きい角丸を指定してもはみ出ない）

## Implementation Notes

- 参照すべき既存コード: プロジェクト内に`StyleBox`継承のカスタムクラス例は存在しない（新規パターン）。`.claude/rules/coding-style.md`の静的型付け規約・命名規則（snake_case関数/変数、PascalCaseクラス）に従う
- 実装のヒント: `_draw(to_canvas_item: RID, rect: Rect2)`は`StyleBox`の仮想関数。`Control._draw()`と異なり`draw_polygon()`等の高レベルAPIは使えないため、`RenderingServer.canvas_item_add_polygon(to_canvas_item, points, colors, uvs, texture)`を直接呼ぶ。頂点計算部分（角丸ポリゴン生成）は独立した`static func`に切り出し、ユニットテスト可能にすること
- 注意事項: `_draw()`はGdUnit4のヘッドレス環境で直接検証しにくいため、描画ロジックの正しさは「頂点計算関数」側でテストする。実際の見た目確認はGodotエディタでの手動確認に委ねる（`.claude/rules/godot-debug-tools.md`参照）

## Files

- 新規: `atelier/shared/theme/ui_panel_stylebox.gd`
- テスト: `atelier/tests/unit/shared/theme/test_ui_panel_stylebox.gd`
