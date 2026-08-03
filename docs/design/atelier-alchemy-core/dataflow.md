# データフロー図

作成日: 2026-08-04
準拠要件: [`../../spec/atelier-alchemy-core/requirements.md`](../../spec/atelier-alchemy-core/requirements.md)

## ゲーム全体のフロー

```mermaid
flowchart TD
    Start[ゲーム起動] --> LoadMaster[マスターデータ読み込み<br/>materials/recipes/ranks/upgrades/daily_orders]
    LoadMaster --> InitState[GameState初期化<br/>Gランク・初期ゴールド・空の庭/在庫]
    InitState --> MainLoop[ターンループへ]

    subgraph MainLoop[ターンループ]
        direction TB
        TurnStart[① 状況提示<br/>ランクHP・指定調合物・在庫・庭の状況・残りターン数] --> PlayerChoice
        PlayerChoice[② プレイヤーの選択<br/>庭: 植える/収穫する<br/>調合: 投入枠を組んで実行 or 見送り] --> Resolve
        Resolve{調合を実行した?}
        Resolve -->|Yes| Delivery[③ 結果反映: 自動納品<br/>ランクHP減少 / ゴールド獲得 / 指定合致ボーナス]
        Resolve -->|No| SkipDelivery[結果反映なし]
        Delivery --> Feedback[④ フィードバック表示]
        SkipDelivery --> Feedback
        Feedback --> EndTurn[ターンを終了する]
        EndTurn --> GrowGarden[庭の生育がターン経過分進む<br/>※調合の有無に関わらず毎ターン必ず実行]
    end

    GrowGarden --> CheckRank{制限ターン到達?}
    CheckRank -->|No| TurnStart
    CheckRank -->|Yes| CheckHp{ランクHP0?}

    CheckHp -->|Yes| PromotionExam[昇格試験へ<br/>庭なし・専用試験HP・超短期ターンで<br/>通常の調合/納品ループを流用]
    CheckHp -->|No| Demotion[降格<br/>同ランクに留まり再挑戦]

    Demotion --> CheckDemotionCount{規定回数連続降格?}
    CheckDemotionCount -->|No| TurnStart
    CheckDemotionCount -->|Yes| GameOver[ゲームオーバー]

    PromotionExam --> ExamResult{試験成功?}
    ExamResult -->|Yes| CheckMaxRank{最高ランクS?}
    ExamResult -->|No| Demotion

    CheckMaxRank -->|Yes| GameClear[ゲームクリア]
    CheckMaxRank -->|No| Workshop[工房強化画面<br/>恒久投資を選択]
    Workshop --> NextRank[次ランクへ昇格]
    NextRank --> TurnStart

    GameOver --> End([終了])
    GameClear --> End
```

🔵 全体フローは要件定義書§1「プレイサイクル」・§2「勝敗条件」の記述をそのまま図式化したもの。「昇格試験」ボックスの内部詳細は[`core-systems.md`](./core-systems.md) RankSystem節、および本文書「昇格試験のデータフロー」を参照。

## 調合実行のデータフロー（★ゲームの核心）

```mermaid
sequenceDiagram
    participant Player
    participant AlchemyUI as AlchemyScreen
    participant GameState
    participant AlchemyLogic as AlchemySystem(logic)
    participant GuildLogic as GuildSystem(logic)
    participant RankLogic as RankSystem(logic)

    Player->>AlchemyUI: 解禁済みレシピから1つを選択
    AlchemyUI->>GameState: set_selected_recipe(recipe_id)
    Note over AlchemyUI,GameState: 事前選択方式（🔵2026-08-04ヒアリングで確定）

    Player->>AlchemyUI: 在庫から素材を投入枠にドラッグ/選択
    AlchemyUI->>GameState: get_state().inventory を参照
    GameState-->>AlchemyUI: 在庫一覧

    Player->>AlchemyUI: 「調合を実行する」を押下
    AlchemyUI->>GameState: execute_alchemy(selected_recipe_id, slot_materials)

    GameState->>AlchemyLogic: SlotState.can_execute()
    AlchemyLogic-->>GameState: true（レシピ選択済み・1個以上投入済み）

    GameState->>AlchemyLogic: QualityCalculator.calculate_quality(materials)
    AlchemyLogic-->>GameState: quality_score

    GameState->>AlchemyLogic: TraitActivation.resolve_traits(materials)
    AlchemyLogic-->>GameState: activated_traits

    GameState->>AlchemyLogic: ProductValueCalculator.calculate_contribution/reward(...)
    AlchemyLogic-->>GameState: ProductInstance(quality, traits, contribution, reward)

    GameState->>GuildLogic: DeliveryResolver.resolve(product, daily_order)
    GuildLogic-->>GameState: DeliveryResult(final_contribution, final_reward, order_matched)

    GameState->>RankLogic: RankHpResolver.apply_contribution(current_hp, final_contribution)
    RankLogic-->>GameState: new_hp

    GameState->>GameState: 在庫から投入素材を消費<br/>ゴールドに final_reward を加算<br/>ランクHPを new_hp に更新

    GameState-->>AlchemyUI: signal alchemy_completed(product, delivery_result)
    AlchemyUI-->>Player: ④フィードバック表示（貢献度ダメージ演出・報酬獲得・指定合致ボーナス・HPバー変化）
```

🔵 要件定義書§1「③結果反映」の内容をシーケンス図化。呼び出し順序（品質計算→特性発現→価値算出→納品判定→HP反映）は本文書での設計判断（🟡）だが、各ステップの計算式自体は要件定義書に明記された式（L117-118）に忠実。

## 庭（栽培）のデータフロー

```mermaid
sequenceDiagram
    participant Player
    participant GardenUI as GardenScreen
    participant GameState
    participant GardenLogic as GardenSystem(logic)
    participant RngService

    Player->>GardenUI: 種を選んで植える
    GardenUI->>GameState: plant_seed(seed_id)
    GameState->>GardenLogic: Planting.can_plant(garden_state, slot_limit)
    GardenLogic-->>GameState: true/false
    GameState-->>GardenUI: 成功/失敗（スロット満杯時は失敗）

    Note over GameState,GardenLogic: ターン終了時に毎回実行（調合の有無に関わらず）
    GameState->>GardenLogic: Harvest.advance_growth(plant_state, 1)
    GardenLogic-->>GameState: 更新後のPlantState

    Player->>GardenUI: 収穫可能な株を収穫する
    GardenUI->>GameState: harvest(plant_id)
    GameState->>GardenLogic: Harvest.is_dead(plant_state, master)
    GardenLogic-->>GameState: false（枯死していない）
    GameState->>RngService: get_random_value()
    RngService-->>GameState: rng_roll
    GameState->>GardenLogic: Harvest.harvest(plant_state, rng_roll)
    GardenLogic->>GardenLogic: TraitRoll.roll_trait(seed_master, rng_roll2)
    GardenLogic-->>GameState: MaterialInstance(quality, trait)
    GameState->>GameState: 在庫にMaterialInstanceを追加
    GameState-->>GardenUI: signal material_harvested(material)
```

🔵 要件定義書§3「庭（仕込み層）」の操作をシーケンス図化。

## 昇格試験のデータフロー（🔵2026-08-04ヒアリングで確定）

昇格試験は「調合実行のデータフロー」と同一の呼び出し列を流用する。差分は❶庭を経由しない、❷`daily_order`を渡さない、❸反映先が`RankState.rank_hp`ではなく`ExamState.exam_hp`である点のみ。

```mermaid
sequenceDiagram
    participant Player
    participant AlchemyUI as AlchemyScreen(試験モード)
    participant GameState
    participant AlchemyLogic as AlchemySystem(logic)
    participant GuildLogic as GuildSystem(logic)
    participant RankLogic as RankSystem(logic)

    Note over GameState,RankLogic: PromotionExamResolver.start_exam でExamState生成済み<br/>（exam_hp = rank_master.max_hp × exam_hp_multiplier）

    loop 試験制限ターン以内、exam_hp > 0の間
        Player->>AlchemyUI: レシピ選択 → 在庫から投入枠へ配置<br/>（庭は選択肢に出さない。新規収穫不可）
        Player->>AlchemyUI: 「調合を実行する」を押下
        AlchemyUI->>GameState: execute_alchemy(selected_recipe_id, slot_materials)

        GameState->>AlchemyLogic: QualityCalculator / TraitActivation / ProductValueCalculator
        AlchemyLogic-->>GameState: ProductInstance(quality, traits, contribution, reward)

        GameState->>GuildLogic: DeliveryResolver.resolve(product, null)
        Note right of GuildLogic: daily_orderにnullを渡す→matches_orderは常に偽<br/>（指定合致ボーナスは適用しない）
        GuildLogic-->>GameState: DeliveryResult(final_contribution, final_reward, order_matched=false)

        GameState->>RankLogic: RankHpResolver.apply_contribution(exam_state.exam_hp, final_contribution)
        RankLogic-->>GameState: new_exam_hp

        GameState->>GameState: exam_state.exam_hp = new_exam_hp<br/>exam_state.exam_elapsed_turn += 1

        GameState->>RankLogic: PromotionExamResolver.resolve_outcome(exam_state)
        RankLogic-->>GameState: ExamOutcome(CONTINUE/SUCCESS/FAILURE)
    end

    alt ExamOutcome == SUCCESS
        GameState-->>AlchemyUI: signal exam_succeeded
        AlchemyUI-->>Player: WorkshopScreenへ遷移（恒久投資、購入は任意）
    else ExamOutcome == FAILURE
        GameState-->>AlchemyUI: signal exam_failed
        AlchemyUI-->>Player: 降格回数+1、庭画面へ戻る（同ランク再挑戦）
    end
```

🔵 呼び出し順序は「調合実行のデータフロー」と同一（[`core-systems.md`](./core-systems.md) RankSystem節参照）。ループの終了条件（`exam_elapsed_turn >= exam_turn_limit`）は`PromotionExamResolver.resolve_outcome`が判定する。

## ランク進行・昇格試験の状態遷移

```mermaid
stateDiagram-v2
    [*] --> RankG

    state "通常ターンループ（各ランク共通）" as TurnLoop {
        [*] --> Playing
        Playing --> Playing: ターン終了（HP>0 かつ 制限ターン未到達）
    }

    RankG --> TurnLoop
    TurnLoop --> PromotionCheck: 制限ターン到達

    state PromotionCheck <<choice>>
    PromotionCheck --> PromotionExam: ランクHP == 0
    PromotionCheck --> Demotion: ランクHP > 0

    state PromotionExam2 <<choice>>
    PromotionExam --> PromotionExam2
    PromotionExam2 --> Workshop: 試験成功
    PromotionExam2 --> Demotion: 試験失敗

    Demotion --> DemotionCheck
    state DemotionCheck <<choice>>
    DemotionCheck --> TurnLoop: 降格回数 < 規定回数
    DemotionCheck --> GameOver: 降格回数 >= 規定回数

    Workshop --> RankNext: 恒久投資選択完了
    RankNext --> TurnLoop: 次ランクのターンループ開始

    RankNext --> GameClear: 直前のランクがSだった場合
    GameClear --> [*]
    GameOver --> [*]
```

🔵 要件定義書§2「勝敗条件」の「降格」定義（ランク文字は下がらず同一ランクに留まる）に忠実に、`Demotion`から`TurnLoop`へ戻る遷移（ランクは変わらない）として表現した。
