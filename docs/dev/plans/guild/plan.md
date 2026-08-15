# Plan: guild

## Requirements Summary

「Atelier」（Godot 4.x + GDScript）のPhase 2機能実装として、ギルド納品（GuildSystem）を実装する。庭（garden）・調合（alchemy）は既に`logic/`・`state/`・`resources/`・`GameState`統合まで完了しており、調合完了時に生成され`GameState._pending_products`へ積まれた`ProductInstance`を、プレイヤー操作なしで自動的にギルドへ納品・決算する一連の処理を本planで実装する。

**スコープに含む**: `features/guild/logic/`（`DeliveryResolver`/`DeliveryResult`）・`features/guild/resources/`（`DailyOrderMaster`）・`shared/constants/game_balance.gd`への定数追加・`GameState.deliver_pending_products`統合（`_pending_products`消費〜`_gold`加算〜`_accumulated_contribution`累積〜`delivered`シグナル発行まで）。
**スコープに含まない**: RankSystem本体（ランクノルマ管理・降格判定・昇格試験、rank plan）、`DailyOrderMaster`実データ（`.tres`）作成・ターン終了時の再抽選ロジック（別plan）、`features/guild/ui/`（別task）、昇格試験からの`daily_order=null`呼び出しパス自体（RankSystem側の責務）。

詳細: [requirements.md](requirements.md)（FR25件+NFR7件+CON10件、🔵27/🟡5/🔴10） | [user-stories.md](user-stories.md) | [acceptance-criteria.md](acceptance-criteria.md)（AC-001〜016、テストチェックリスト56件）

## Design Overview

既存の確定設計（`docs/design/atelier-alchemy-core/core-systems.md` GuildSystem節、`data-schema.md` DailyOrderMaster節）を正としてインターフェースを踏襲した。設計フェーズで判明した実装ギャップは、ヒアリングでユーザー確認済みの方針（赤信号10件は全件承認済み）に従う:

- **`DeliveryResult`を`features/guild/logic/`に配置**: core-systems.mdのクラス図では配置未確定だったが、参照元が`DeliveryResolver`（同一Featureの`logic/`）と`GameState`（Application層）に限られるため、alchemyの`ProductInstance`（`shared/entities/`昇格）とは異なり`shared/entities/`へ昇格する必要はないと判断した（CON-003）
- **`GameState`に`_accumulated_contribution: float`・`_current_daily_order: DailyOrderMaster`を新設**: RankSystem未実装・日次サイクル未実装のため、`_traits_unlocked`（alchemy CON-007）と同型の暫定フィールドパターンを踏襲した（CON-004, CON-010）。後続のrank plan・日次サイクルplanが正式な権威に置き換える想定
- **`deliver_pending_products()`は単一アトミック呼び出しに限定**: `_pending_products`を先頭から全件消費し`Array[DeliveryResult]`を返す設計とし、1件ずつ納品する逐次APIは提供しない（CON-009。alchemyの`execute_alchemy`と同方針）
- **`final_reward`は`roundi()`で`_gold`（int）へ丸めて即時加算**: float→int変換規則が既存設計文書になかったため、四捨五入を新規決定した（プレイヤー不利側への偏りを避けるため切り捨てを採用しない、CON-007）
- **`delivered(results: Array[DeliveryResult])`シグナルを新設**: core-systems.mdはGuildSystemのシグナルを規定していないが、`product_crafted`・`material_harvested`の既存パターンを踏襲し、将来のUI実装（別task）が件別の`order_matched`を購読できるようにした（FR-108, NFR-201）

### レイヤー構成

```
Presentation層  features/guild/ui/             対象外（本plan外、FR-406）
       ↓ (未実装。UI plan側でdeliveredシグナル購読を行う想定)
Application層   autoload/game_state.gd         deliver_pending_products
       ↓ (static call)
Domain層        features/guild/logic/          DeliveryResolver, DeliveryResult（副作用なし）
       ↓ (読み取り)
Infrastructure層 features/guild/resources/      DailyOrderMaster
                shared/entities/                Result, ProductInstance（既存、alchemy planが作成・変更なし）
                shared/constants/game_balance.gd（DAILY_ORDER_MATCH_BONUS_MULTIPLIER追記）
```

## Task Dependency Graph

トポロジカル順（001が最も基盤、番号順に実行すればすべての依存が解決済みになる）:

```
001 DeliveryResult型          （独立）
002 DailyOrderMaster型        （独立）
003 GameBalanceギルド定数      （独立）
001,002 └→ 004 DeliveryResolver [dep: 001,002]
002     └→ 005 GameState guild基盤（フィールド・get_state/reset_for_test拡張・テストAPI） [dep: 002]
004,005 └→ 006 GameState.deliver_pending_products [dep: 004,005]
```

実行順序の目安: **001〜003（並行可）→ 004・005（並行可、005は002のみに依存）→ 006**

## Cross-Plan Dependencies

- **`GameState._pending_products`（消費側）**: alchemy planが新設した未納品キューを、本planの`deliver_pending_products()`（タスク006）が唯一の消費者として実装する。`ProductInstance`のフィールド構成（`recipe_id`/`quality_score`/`activated_traits`/`contribution`/`reward`）は変更しない
- **`GameState._accumulated_contribution`（暫定フィールド）**: 本plan完了時点では`float`の単純な累積フィールドに留まる。後続のrank planが正式なランクノルマ管理（`quota_remaining`の減算・降格判定等）へ置き換える想定。rank plan側はこのフィールド名・型（`float`）を前提にした移行を検討すること
- **`GameState._current_daily_order`（暫定フィールド）**: 本plan完了時点では既定値`null`で固定（再抽選ロジックなし）。別plan（日次/ターンサイクル設計）が本フィールドの更新経路（毎ターン終了時の再抽選）を追加する想定
- **`features/guild/logic/delivery_result.gd`（`DeliveryResult`）**: 本plan内で新規作成する。RankSystem実装時に`_accumulated_contribution`の消費ロジックが本型を参照する可能性がある
- **`shared/constants/game_balance.gd`**: 本plan（タスク003）でギルド関連定数のみ追記する。他Feature（garden/alchemy）の既存定数は変更しない
- **`MainScene`統合・GuildScreen UI**: 本plan外。別task・別planで行う
