# データフロー図

準拠要件: [`../../spec/atelier-alchemy-core/requirements.md`](../../spec/atelier-alchemy-core/requirements.md)
関連: [`architecture.md`](architecture.md) / [`core-systems.md`](core-systems.md)

> **信頼性レベル凡例**: 🔵 要件/コンセプト準拠 ／ 🟡 妥当な推測 ／ 🔴 新規推測

---

## ゲーム全体のフロー

🔵 セーブ/ロードはスコープ外のため、起動時は常に新規ゲーム状態を生成する。

```mermaid
flowchart TD
    Start[ゲーム起動] --> LoadMaster[マスターデータ .tres 一括ロード]
    LoadMaster --> NewGame[新規ゲーム状態生成（Gランク・特性封印）]
    NewGame --> RankStart[ランク開始（HP満タン・残ターン設定）]
    RankStart --> TurnLoop[ターンループ]
    TurnLoop --> TurnEnd{制限ターン到達?}
    TurnEnd -->|No| TurnLoop
    TurnEnd -->|Yes| HpCheck{ランクHP == 0?}
    HpCheck -->|Yes| Exam[昇格試験 🟡TBD]
    HpCheck -->|No| Demote[降格＝同ランク再挑戦]
    Exam -->|成功 かつ Sランク| Cleared[ゲームクリア]
    Exam -->|成功| Workshop[工房強化画面（恒久投資）]
    Exam -->|失敗| Demote
    Workshop --> NextRank[次ランクへ]
    NextRank --> RankStart
    Demote --> DemoteCount{降格回数 >= 上限?}
    DemoteCount -->|Yes| GameOver[ゲームオーバー]
    DemoteCount -->|No| RankStart
    Cleared --> End[GameEndScene]
    GameOver --> End
```

---

## ターンループのフロー（1ターン）

🔵 [`requirements.md`](../../spec/atelier-alchemy-core/requirements.md) 1章のプレイサイクルに準拠。主戦場は②調合。

```mermaid
flowchart TD
    T0["① 状況提示<br>ランクHP・指定調合物・在庫・庭・残ターン"] --> T1{プレイヤーの選択}
    T1 -->|庭| G1[種を植える / 収穫する / 種を指名買い]
    T1 -->|調合| A1[投入枠に素材配置 → 調合を実行]
    T1 -->|消耗投資| S1[触媒・種を購入]
    A1 --> A2["③ 結果反映：自動納品<br>貢献度→ランクHP減少 / 報酬→ゴールド / 指定合致ボーナス"]
    A2 --> A3["④ フィードバック<br>ダメージ演出・報酬表示・HPバー変化"]
    G1 --> TE
    S1 --> TE
    A3 --> TE[ターンを終了する]
    TE --> Growth[庭の生育がターン分進行（毎ターン必ず）]
    Growth --> T0
```

> 🔵 庭の生育は「調合を実行したかどうかに関わらず、ターン終了で毎ターン必ず」進行する（[`requirements.md`](../../spec/atelier-alchemy-core/requirements.md) 1章③）。

---

## 調合〜納品のシーケンス（★核心）

🔵 UI（Presentation）→ GameState（Application）→ logic（Domain）→ signal でのUI更新、という往復。

```mermaid
sequenceDiagram
    participant Player
    participant AlchemyUI as AlchemyPhaseUI
    participant GS as GameState
    participant QL as quality_logic
    participant TL as trait_logic
    participant CRL as contribution_reward_logic
    participant HUD as RankHUD

    Player->>AlchemyUI: 投入枠に素材を配置
    AlchemyUI->>GS: place_material(slot, instance_id)
    GS->>QL: average_quality(materials)
    QL-->>GS: 平均品質
    GS->>TL: resolve_traits(materials)
    TL-->>GS: 発現特性リスト
    GS-->>AlchemyUI: プレビュー更新（品質・特性）
    Player->>AlchemyUI: 「調合を実行」
    AlchemyUI->>GS: execute_craft()
    Note over GS: can_craft() 検証（最低1個）
    GS->>QL: quality_multiplier(avg)
    GS->>CRL: calc_contribution / calc_reward / is_spec_matched
    CRL-->>GS: 貢献度・報酬・合致フラグ
    Note over GS: HP減算（0クランプ）・ゴールド加算・在庫消費
    GS-->>HUD: signal rank_hp_changed / gold_changed
    GS-->>AlchemyUI: signal product_delivered
    AlchemyUI-->>Player: ④フィードバック演出
```

---

## 庭の仕込み〜収穫のシーケンス

```mermaid
sequenceDiagram
    participant Player
    participant GardenUI as GardenPhaseUI
    participant GS as GameState
    participant GL as garden_logic
    participant RNG as RngService

    Player->>GardenUI: 種を植える（スロット選択）
    GardenUI->>GS: plant_seed(slot, seed_id)
    Note over GS: can_plant() 検証（スロット上限）
    GS-->>GardenUI: 植付反映

    Player->>GardenUI: ターンを終了する
    GardenUI->>GS: end_turn()
    GS->>GL: advance_growth(plots, 1)
    GL-->>GS: 生育・枯死反映後スロット

    Player->>GardenUI: 収穫する（成熟スロット）
    GardenUI->>GS: harvest(slot)
    GS->>RNG: next_float()
    RNG-->>GS: roll（分散乱数）
    GS->>GL: resolve_harvest_quality(plot, roll)
    GS->>GL: roll_trait(seed, roll)
    GL-->>GS: 品質(1〜5) ＋ 特性(0〜2個)
    Note over GS: MaterialInstance を在庫へ追加
    GS-->>GardenUI: 在庫更新
```

> 🔵 収穫時の特性付与は「分散のみ・期待値不動」の乱数（[`requirements.md`](../../spec/atelier-alchemy-core/requirements.md) 4章、`atelier-concept.md` L205）。乱数は `RngService` が供給し、`garden_logic` は純粋関数のまま。

---

## 状態遷移図（ゲームフェーズ）

🟡 庭/調合/納品はシーンではなくメインゲームシーン内のフェーズUI表示切替。フェーズは自由に行き来でき（v7.0は固定順序の依頼フローを廃止）、ターン終了で次ターンへ。

```mermaid
stateDiagram-v2
    [*] --> Garden: ランク開始
    Garden --> Alchemy: 調合へ
    Alchemy --> Garden: 庭へ
    Alchemy --> Delivery: 調合実行（自動納品）
    Delivery --> Garden: 次の操作へ
    Delivery --> Alchemy: 続けて調合
    Garden --> TurnEnd: ターン終了
    Alchemy --> TurnEnd: ターン終了
    TurnEnd --> Garden: 次ターン（HP>0 かつ 残ターン>0）
    TurnEnd --> [*]: 制限ターン到達（ランク結末判定へ）
```

---

## データの所有と流れ

🔵 唯一の可変状態は `GameState`。Domain（`logic/`）は状態を持たず入出力のみ。Infrastructure（`.tres`）は読み取り専用。

```mermaid
graph LR
    Master[(MasterData .tres<br>読み取り専用)] -->|定義参照| GS[GameState<br>唯一の可変状態]
    Balance[(game_balance.gd<br>定数)] -->|パラメータ| Logic[logic 純粋関数]
    GS -->|入力値| Logic
    Logic -->|計算結果| GS
    GS -->|signal| UI[各UI]
    UI -->|操作メソッド| GS
    RNG[RngService<br>シード管理] -->|乱数値| GS
```

| データ種別 | 所有者 | 可変性 | ロードタイミング |
|-----------|--------|--------|-----------------|
| マスターデータ（素材・レシピ・特性） | `.tres`（Infrastructure） | 不変 | BootScene起動時に一括 🔵 |
| バランス定数 | `game_balance.gd` | 不変（コード定義） | 起動時 🔵 |
| ゲーム進行状態 | `GameState`（Autoload） | 可変 | 新規ゲーム時に生成 🔵 |
| 素材インスタンス（収穫物・在庫） | `GameState` 内 | 可変 | 収穫・購入で生成 🟡 |
| セーブデータ | — | — | **スコープ外**（未実装）🔵 |
