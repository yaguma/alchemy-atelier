---
id: "009"
title: "GameState.deliver_pending_products()に試験中の納品分岐を統合する"
status: done
priority: 2
dependencies: ["006"]
estimated_complexity: medium
---

# Task: GameState.deliver_pending_products()に試験中の納品分岐を統合する

## Goal

`in_exam=true`の間の納品では、`daily_order`を`null`にして指定合致ボーナスを不適用にしつつ、貢献度の適用先を`_rank_state.quota`ではなく`_exam_state.exam_quota`に切り替える差分を既存メソッドに追加する。報酬（ゴールド）は試験中でも通常通り加算する。

## Interfaces

```gdscript
# autoload/game_state.gd（既存deliver_pending_products()への差分）

## in_examならdaily_order=nullでDeliveryResolver.resolveを呼び、final_contributionを
## _exam_state.exam_quotaへRankQuotaResolver.apply_contributionで適用する。
## final_rewardのgold加算は試験中/非試験中で分岐しない 🔵 FR-105, FR-106, FR-401
func deliver_pending_products() -> Result:
    pass
```

> 信号機: 🔵 `core-systems.md`L347-349・design phase確定。`RankQuotaResolver.apply_contribution`（既存関数）をノルマの入れ物が`_exam_state.exam_quota`である点以外は無変更で流用する。

## Test Strategy

- [ ] 正常系: `in_exam=true`かつ`_current_daily_order`が非nullでも、納品後は`exam_quota`のみ減算され`rank_state.quota`は変化しない
- [ ] 正常系（FR-106）: 試験中/非試験中で同一の調合物構成を納品した場合の`gold`加算量が一致する（報酬は試験の影響を受けない）
- [ ] 正常系（FR-401）: `in_exam=true`時、指定調合物と一致する`ProductInstance`を納品しても指定合致ボーナスが適用されない（`daily_order=null`で呼ばれることの確認）
- [ ] 異常系: `in_exam=false`時は従来通り`rank_state.quota`が減算され`exam_quota`は変化しない（回帰確認）
- [ ] 境界値: `exam_quota`が残り1件分の貢献度でちょうど0以下になっても負値にならずクランプされる（`RankQuotaResolver.apply_contribution`の既存クランプ挙動の確認）
- [ ] 異常系: 保留中の調合物が0件の場合、`in_exam`の値に関わらず空配列の`Result`が返り状態が変化しない

## Implementation Notes

- 参照すべき既存コード: `atelier/autoload/game_state.gd`の`deliver_pending_products()`（`DeliveryResolver.resolve`呼び出し・`gold`加算・`_rank_state.quota`更新箇所）、`atelier/features/rank/logic/rank_quota_resolver.gd`の`apply_contribution`
- 実装のヒント: design phase 2.4節の擬似コードをそのまま反映する。`order_for_delivery`変数で`_in_exam`時の`null`切り替えを一箇所に集約する
- 注意事項: `DeliveryResolver.resolve`のシグネチャは変更しない（既存guild plan実装への影響を避ける）

## Files

- 変更: `atelier/autoload/game_state.gd`
- テスト: `atelier/tests/integration/test_game_state_deliver_pending_products.gd`（既存ファイルへのテストケース追記）
