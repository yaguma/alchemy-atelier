---
id: "003"
title: "GameBalanceにギルド納品関連定数を追加する"
status: done
priority: 1
dependencies: []
estimated_complexity: low
---

# Task: GameBalanceにギルド納品関連定数を追加する

## Goal

`shared/constants/game_balance.gd`に指定合致ボーナス倍率の既定値定数`DAILY_ORDER_MATCH_BONUS_MULTIPLIER`を追加する。マジックナンバーの直書きを避け、実データ作成時（別plan）の既定値として使用する（CON-006）。

## Interfaces

```gdscript
# shared/constants/game_balance.gd（既存ファイルへの追記）

const DAILY_ORDER_MATCH_BONUS_MULTIPLIER := 1.3  # 🔵 FR-004, CON-006（要件定義書(spec)§5「仮1.2〜1.5倍」の中間値として確定）
```

> 信号機: 🔵 ヒアリング結果スコープ確定事項3で1.3に確定済み

## Test Strategy

- [ ] 正常系: `GameBalance.DAILY_ORDER_MATCH_BONUS_MULTIPLIER == 1.3`であることを確認する
- [ ] 正常系: 定数が`float`型であることを確認する（`DailyOrderMaster.match_bonus_multiplier`との型整合）

## Implementation Notes

- 参照すべき既存コード: `atelier/shared/constants/game_balance.gd`の既存定数（`GARDEN_SLOT_COUNT`等）のコメント規約（信号機+根拠参照の付与）
- 実装のヒント: 既存の調合関連定数（alchemy planタスク003で追加済み）の直後など、論理的にまとまった位置に追記する
- 注意事項: この定数は`DeliveryResolver.resolve`から直接参照されるわけではない（`DeliveryResolver`は`DailyOrderMaster`インスタンス側の`match_bonus_multiplier`を使う、CON-006）。テストフィクスチャや将来の`.tres`実データ作成時の既定値としての役割に留まる

## Files

- 変更: `atelier/shared/constants/game_balance.gd`
- テスト: `atelier/tests/unit/shared/test_game_balance_guild.gd`
