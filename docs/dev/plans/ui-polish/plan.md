# Plan: ui-polish

## Requirements Summary

`docs/design/atelier-alchemy-core/ui-design/screens/*.md` のアニメーション表で🟡TBDのまま残っている演出・フィードバックを実装する。対象は5画面（庭/調合/ギルド納品/昇格試験/工房強化）。

- 対象に含む: 画面遷移・操作フィードバック演出、未実装UI細部（ボタン反応・エラー表示等）、昇格試験の成功/失敗確定演出（新規設計）
- 対象外: キーボード操作対応・フォーカス表示（5画面共通で🟡TBDだが別Plan）、バランス数値・面白さの検証（balance-tuning-cycle担当）
- 演出の秒数・イージング・トースト文言は本Plan内で確定させず、実装時に既存の先行例を踏襲してtdd-implementerが決定し`UiTheme`に定数化する

## Design Overview

### 前提調査で判明した重要事項

1. **`atelier/`配下にTween演出は現状ゼロ**（`create_tween()`使用箇所なし）。今回が完全新規実装であり、既存パターンとの後方互換は考慮不要。
2. **一覧系コンポーネントは全て「全破棄→再生成」方式**（garden/alchemy/guild/workshopの`_rebuild_*()`は`remove_child()+queue_free()`後に`instantiate()`）。ノードの位置を跨ぐ演出（アイコン飛翔・カードスライド）は実ノードをTweenできないため、共通の「複製（ゴースト）を飛ばす」パターンで対応する。
3. **🔴昇格試験の成功/失敗演出は、現在のシグナル配線のままでは描画されない**。`GameState.exam_outcome_confirmed`を`AlchemyScreen`と`MainScene`が両方直接購読しており、ノード生成順（子→親）により`AlchemyScreen`側ハンドラが先に走った直後、同じ同期呼び出しの中で`MainScene`側が`GameState.set_phase()`を呼んで`AlchemyScreen`自体を`visible=false`にする。演出を仕込んでもフレーム描画前に親ごと消える。タスク013でシグナル配線を是正する（`GuildDeliveryScreen`の「続ける」ボタン起点の中継シグナルと同型）。
4. **配置方針（ユーザー決定）**: 新設する`ExamOutcomeOverlay`は`features/rank/ui/`に置く（アーキテクチャルール「他Featureの`ui/`への直接参照禁止」を厳守）。`AlchemyScreen`は`ExamOutcomeOverlay`を直接知らず、確定シグナルを発行するのみとし、`scenes/main.gd`（Feature外のルートシーン、複数Featureを組み合わせる責務を元々持つ）が`AlchemyScreen`の確定シグナルと`ExamOutcomeOverlay`の両方を仲介する。既存の`GuildDeliveryScreen`埋め込み（alchemy内にguildのUIが同居）は既知の技術的負債として現状維持し、本Planでは新規追加分のみ正しいレイヤーに置く。
5. **指定合致時の「キラキラ」**: GPUParticles2Dではなく、ドット絵統一済みの既存デザインとの一貫性を優先し、Tween明滅+スケールパルスで代替する（ユーザー決定）。

### 共通基盤: UiEffects

`atelier/shared/ui/ui_effects.gd`（新規, `class_name UiEffects`, static funcのみ）。`ButtonStyleApplier`/`PixelBackdropApplier`と同じ「状態を持たないstatic適用クラス」パターン。

```gdscript
class_name UiEffects

static func play_pop_in(target: Control, duration: float, ease_type: Tween.EaseType) -> Tween  # 🔵
static func fly_ghost(overlay_layer: Control, source: Control, to_global_position: Vector2, duration: float) -> Tween  # 🟡
static func play_wither_fade(target: Control, duration: float) -> Tween  # 🟡
static func animate_progress_value(bar: ProgressBar, to_value: float, duration: float) -> Tween  # 🔵
static func play_highlight_pulse(target: Control, color: Color, duration: float) -> Tween  # 🟡（特性発現・指定合致キラキラ共用）
```

`fly_ghost()`/`play_wither_fade()`は対象ノードを複製（`duplicate()`）して自壊させる。呼び出し元の実ノードが直後の`_rebuild_*()`で破棄される前提のため、複製後は元ノードの破棄タイミングを気にしなくてよい。

### UiTheme新規定数（プレースホルダー、値はtdd-implementer決定）

```
UiTheme.ANIM_DURATION_POP_IN
UiTheme.ANIM_DURATION_FLY_GHOST
UiTheme.ANIM_DURATION_WITHER_FADE
UiTheme.ANIM_DURATION_QUOTA_BAR
UiTheme.ANIM_DURATION_FADE_SCREEN
UiTheme.ANIM_DURATION_HIGHLIGHT_PULSE
UiTheme.ANIM_EASE_DEFAULT  # Tween.EaseType
UiTheme.COLOR_WITHER_FADE_TARGET
UiTheme.COLOR_TOAST_WARNING
UiTheme.COLOR_TRAIT_HIGHLIGHT
UiTheme.COLOR_ORDER_MATCHED_HIGHLIGHT
```

バランスに無関係な純粋演出値のため、GameBalanceではなくUiThemeに集約する（`.claude/rules/coding-style.md`の判断基準に一致）。

### データフロー概要

```
GameState signal ─→ Screen._on_xxx() ─→ [状態更新/refresh()] ─→ UiEffects.xxx() ─→ Tween.finished ─→ (テスト用await地点)
```

例外（昇格試験のみ）:
```
AlchemyScreen._on_exam_outcome_confirmed(outcome)
  → SUCCESS/FAILURE: exam_result_pending(outcome) を emit（画面は消さない）
  → MainScene が exam_result_pending を購読 → ExamOutcomeOverlay.show_outcome(outcome)
  → プレイヤー確認操作 → ExamOutcomeOverlay.acknowledged
  → MainScene が GameState.set_phase() を実行（従来 AlchemyScreen 内で完結していた分岐を MainScene 側に移設）
```

## Task Dependency Graph

```
001 (UiEffects新設+UiTheme演出定数)  ── 全演出タスクの前提
  ├→ 002 (庭: 植付ポップイン)
  ├→ 003 (庭: 収穫フライング)
  ├→ 004 (庭: 枯死フェード)
  ├→ 006 (調合: 投入スライド)
  ├→ 007 (調合: 特性発現ハイライト)
  ├→ 008 (調合: 完成品生成演出)
  ├→ 010 (ギルド納品: フェードイン+ポップ)
  ├→ 011 (ノルマバー減少アニメ共通化・guild/rank_hud)
  │    └→ 012 (ギルド納品: 指定合致キラキラ)
  ├→ 016 (工房: ゴールドカウントダウン)
  └→ 017 (工房: 画面表示フェードイン)

013 (昇格試験: シグナル配線是正)  ── 独立着手可・複雑度high
  └→ 014 (昇格試験: 結果演出コンポーネント, ← 001にも依存)
       └→ 015 (昇格試験: 試験ノルマ減少演出の流用確認, ← 011にも依存)

005 (庭: スロット満杯トースト文言修正)  ── 独立
009 (調合: 空状態表示)  ── 独立
018 (工房: 価格警告色)  ── 独立
```

001と013は並行着手可能。005/009/018は他タスクの完了を待たずいつでも着手できる。

## Cross-Plan Dependencies

- `docs/dev/plans/rank-up/` のRankState/ExamState設計、`docs/dev/plans/garden-alchemy-visual-refresh/`のbackdrop/ドット絵基盤（`PixelBackdropApplier`, `ButtonStyleApplier`）に依存（変更はしない、参照のみ）
- タスク013は既存のGdUnit4フェーズ遷移テスト（試験成功/失敗時の画面遷移を検証するテスト群）の改修を伴う。対象テストファイルはタスク013実装時にtdd-implementerが`atelier/tests/integration/`配下から特定する
- キーボード操作対応・フォーカス表示は別Planとして切り出し予定（本Planのスコープ外）
