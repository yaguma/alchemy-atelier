# Plan: integration-playthrough-verify

## Requirements Summary

CLAUDE.md「次のステップ」に記載の「5機能を通した結合プレイ（庭→調合→ギルド納品→ランク進行→工房強化のループが実機で通しで回るか）の確認はまだ行われていない」を解消する。

既存のGdUnit4結合テスト（`test_main_scene_happy_path.gd`, `test_main_scene_exam_flow.gd`, `test_main_scene_exam_and_result_routing.gd`, `test_main_scene_workshop_routing.gd`等）は「通常ターン1周」「工房往復」「試験開始〜合否分岐」を**個別のシナリオとして**カバー済みだが、「ランク昇格を跨いで工房強化を挟みながら複数サイクル連続でプレイが破綻しないか」という**通しの結合**は検証されていない。

本Planではこのギャップを埋める、G→F→Eの2段階連続昇格＋工房強化購入を1本の結合テストとして通す `atelier/tests/integration/test_main_scene_full_loop_playthrough.gd` を新規作成する（ユーザー判断: 自動テスト拡充、複数ランク連続）。

バランス数値の妥当性検証（面白さ・難易度）はスコープ外（`balance-tuning-cycle`スキルの担当）。本Planは「UI配線・状態遷移がロングランで壊れないこと」の保証に限定する。

## Design Overview

### 対象ファイル

- 新規: `atelier/tests/integration/test_main_scene_full_loop_playthrough.gd`

### シナリオ設計（1本の結合テスト関数として実装し、途中で分断しない）

```
[rank_g] 庭で植付 → 調合タブ → レシピ選択・素材投入・調合実行 → EndTurnButton
  → 納品決算でノルマ消化 → PROMOTION_ELIGIBLE → exam_started（試験開始）
  → 試験中に調合1回（自動納品） → AdvanceExamTurnButton → SUCCESS確定
  → current_rank_id: rank_g → rank_f、workshop画面へ自動遷移
[workshop] UpgradeItemList越しに実データ upgrade_alchemy_slot を購入
  → ゴールド減算・GameState._alchemy_slot_count加算を確認 → CloseButton
[rank_f] （工房から復帰した画面で）再度植付〜納品ループ → PROMOTION_ELIGIBLE
  → exam_started → 試験1回消化 → SUCCESS確定
  → current_rank_id: rank_f → rank_e、workshop画面へ自動遷移
[最終確認] シーン開始時に控えたMainScene/4画面のインスタンスIDが最後まで不変（NFR-001踏襲、
  change_scene_to_file()による再生成が起きていないこと）
```

### 既存パターンの踏襲（🔵 test_main_scene_exam_flow.gd, test_main_scene_happy_path.gd で確認済み）

- `GameState.reset_for_test()` / `_set_rank_masters_for_test()` / `_set_current_rank_id_for_test()` / `_set_rank_state_for_test()` / `_set_recipe_masters_for_test()` / `_set_unlocked_recipe_ids_for_test()` / `_inject_material_for_test()` / `_inject_pending_product_for_test()` — テスト専用の低ノルマ・低試験難度フィクスチャ注入APIとして既存2ファイルで確立済み
- `RankMaster.quota_max` / `exam_turn_limit` / `exam_difficulty_coefficient` を小さく設定し、少ない操作回数で確実にSUCCESSへ到達させる（既存パターン、🔵）
- ランクをまたぐ都度、次ランクの`RankState`を`_set_rank_state_for_test()`で明示的に再注入する（rank_state.gdの`elapsed_turn`自動進行が未実装という既知ギャップを回避する確立済み手法、🟡 test_main_scene_exam_flow.gd L89-91のコメント参照）
- 工房購入: `GameState.load_workshop_master_data()`で実データ読込 → `UpgradeItemList`内の`UpgradeItem_{upgrade_id}`ノード配下`%PurchaseButton`を押下（🔵 upgrade_item_list.gd L61, upgrade_item_row.gd L18で命名規則確認済み）

## Task Dependency Graph

```
001 (共通フィクスチャ・ヘルパー雛形)
  → 002 (G→F昇格シナリオ前半)
    → 003 (工房購入・効果反映)
      → 004 (F→E昇格シナリオ後半 + 最終アサーション)
        → 005 (品質ゲート: 全体通し実行・gdlint・gdformat)
```

直列依存（1本のテスト関数を段階的に組み立てるため、並行実施は不可）。

## Cross-Plan Dependencies

- `docs/dev/plans/rank-up/` のRankState/ExamState設計・GameStateのcommit_exam_outcome等に依存（変更はしない、参照のみ）
- `docs/dev/plans/workshop/` のUpgradeMaster/apply_upgrade設計に依存（変更はしない、参照のみ）
- 既存の`test_main_scene_exam_flow.gd`とヘルパー関数が重複するため、共通化するか個別ファイル内に複製するかはタスク001実装時にtdd-implementerが判断する（🟡 過度な共通化はテストの独立性を損なうため、複製を許容する）
