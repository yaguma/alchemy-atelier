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
        TurnStart[① 状況提示<br/>ランクノルマ・指定調合物・在庫・庭の状況・残りターン数] --> PlayerChoice
        PlayerChoice[② プレイヤーの選択<br/>庭: 植える/収穫する<br/>調合: 投入枠を組んで実行 or 見送り] --> Resolve
        Resolve{調合を実行した?}
        Resolve -->|Yes| Delivery[③ 結果反映: 自動納品<br/>ランクノルマ減少 / ゴールド獲得 / 指定合致ボーナス]
        Resolve -->|No| SkipDelivery[結果反映なし]
        Delivery --> Feedback[④ フィードバック表示]
        SkipDelivery --> Feedback
        Feedback --> EndTurn[ターンを終了する]
        EndTurn --> GrowGarden[庭の生育がターン経過分進む<br/>※調合の有無に関わらず毎ターン必ず実行]
        GrowGarden --> Wither[枯死判定・スロット解放<br/>Harvest.resolve_withering]
        Wither --> UpdateOrder[日替わり指定調合物を再抽選]
    end

    UpdateOrder --> CheckRank{制限ターン到達?}
    CheckRank -->|No| TurnStart
    CheckRank -->|Yes| CheckQuota{ランクノルマ0?}

    CheckQuota -->|Yes| PromotionExam[昇格試験へ<br/>庭なし・専用試験ノルマ・超短期ターンで<br/>通常の調合/納品ループを流用]
    CheckQuota -->|No| Demotion[降格<br/>同ランクに留まり再挑戦]

    Demotion --> ResetRankRetry[ランクノルマ/残りターンをリセット<br/>庭・在庫・ゴールド・恒久投資は維持<br/>RankQuotaResolver.reset_for_retry]
    ResetRankRetry --> CheckDemotionCount{規定回数連続降格?}
    CheckDemotionCount -->|No| TurnStart
    CheckDemotionCount -->|Yes| GameOver[ゲームオーバー]

    PromotionExam --> ExamResult{試験成功?}
    ExamResult -->|Yes| CheckMaxRank{最高ランクS?}
    ExamResult -->|No| Demotion

    CheckMaxRank -->|Yes| GameClear[ゲームクリア]
    CheckMaxRank -->|No| Workshop[工房強化画面<br/>恒久投資を選択（購入は任意）]
    Workshop --> NextRank[次ランクへ昇格<br/>降格回数カウンタを0にリセット]
    NextRank --> TurnStart

    GameOver --> End([終了])
    GameClear --> End
```

🔵 全体フローは要件定義書§1「プレイサイクル」・§2「勝敗条件」の記述をそのまま図式化したもの。「昇格試験」ボックスの内部詳細は[`core-systems.md`](./core-systems.md) RankSystem節、および本文書「昇格試験のデータフロー」を参照。

🔴 **2026-08-06追加（実装レディネス監査対応）**: `EndTurn`ノードは、庭画面・調合画面の`btn-end-turn`（[`ui-design/screens/garden.md`](./ui-design/screens/garden.md)・[`ui-design/screens/alchemy.md`](./ui-design/screens/alchemy.md) 参照）押下で呼ばれる`GameState.end_turn()`に対応する。`end_turn()`は`GrowGarden`（`Harvest.advance_growth`）→`Wither`（`Harvest.resolve_withering`）→`UpdateOrder`（`daily_order`再抽選）→`CheckRank`（`TurnLimitResolver.is_turn_limit_reached`）以降の分岐までを1回の呼び出しで同期的に実行する。旧版はこの呼び出し元（UIのどの操作がこの一連の処理をトリガーするか）が全設計文書から欠落していた。

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

    GameState->>RankLogic: RankQuotaResolver.apply_contribution(current_quota, final_contribution)
    RankLogic-->>GameState: new_quota

    GameState->>GameState: 在庫から投入素材を消費<br/>ゴールドに final_reward を加算<br/>ランクノルマを new_quota に更新

    GameState-->>AlchemyUI: signal alchemy_completed(product, delivery_result)
    AlchemyUI-->>Player: ④フィードバック表示（貢献度反映演出・報酬獲得・指定合致ボーナス・ノルマバー変化）
```

🔵 要件定義書§1「③結果反映」の内容をシーケンス図化。呼び出し順序（品質計算→特性発現→価値算出→納品判定→ノルマ反映）は本文書での設計判断（🟡）だが、各ステップの計算式自体は要件定義書§4「調合物（Product）」に明記された式に忠実。指定合致ボーナスは`ProductValueCalculator`ではなく`DeliveryResolver.resolve`が一手に適用する（🔵2026-08-05修正、PRレビューCritical#4対応。[`core-systems.md`](./core-systems.md) AlchemySystem節参照）。

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
    GameState->>GardenLogic: Harvest.resolve_withering(garden_state, masters)
    GardenLogic-->>GameState: 枯死株を除去したGardenState（🔵2026-08-05追加、PRレビューCritical#11対応。プレイヤーが収穫しなくても自動でスロットが解放される）

    Player->>GardenUI: 収穫可能な株を収穫する
    GardenUI->>GameState: harvest(plant_id)
    GameState->>GardenLogic: Harvest.is_dead(plant_state, master)
    GardenLogic-->>GameState: false（枯死していない。真の場合は既にresolve_witheringで除去済みのため収穫UIに現れない）
    GameState->>RngService: get_random_value()
    RngService-->>GameState: rng_roll_quality
    GameState->>RngService: get_random_value()
    RngService-->>GameState: rng_roll_trait
    Note over GameState,RngService: 品質上昇判定用と特性選択用の乱数は別個に払い出す<br/>（🔵2026-08-05修正、PRレビューWarning対応。旧版はDomain層内部で2つ目の乱数値を自己生成する読み取りが可能だった）
    GameState->>GardenLogic: Harvest.harvest(plant_state, rng_roll_quality, rng_roll_trait)
    GardenLogic->>GardenLogic: TraitRoll.roll_trait(seed_master, rng_roll_trait)
    GardenLogic-->>GameState: Result（成功時 MaterialInstance(quality, trait)）
    GameState->>GameState: 在庫にMaterialInstanceを追加
    GameState-->>GardenUI: signal material_harvested(material)
```

🔵 要件定義書§3「庭（仕込み層）」の操作をシーケンス図化。

## 昇格試験のデータフロー（🔵2026-08-04ヒアリングで確定）

昇格試験は「調合実行のデータフロー」と同一の呼び出し列を流用する。差分は❶庭を経由しない、❷`daily_order`を渡さない、❸反映先が`RankState.quota`ではなく`ExamState.exam_quota`である点のみ。

```mermaid
sequenceDiagram
    participant Player
    participant AlchemyUI as AlchemyScreen(試験モード)
    participant GameState
    participant AlchemyLogic as AlchemySystem(logic)
    participant GuildLogic as GuildSystem(logic)
    participant RankLogic as RankSystem(logic)

    Note over GameState,RankLogic: PromotionExamResolver.start_exam でExamState生成済み<br/>（exam_quota = (quota_max ÷ limit_turn) × exam_turn_limit × exam_difficulty_coefficient<br/>🔵2026-08-05修正、PRレビューCritical#5対応。旧式「quota_max×倍率」は成立しなかったため撤回）

    loop 試験制限ターン以内、exam_quota > 0の間
        alt 調合を実行する場合
            Player->>AlchemyUI: レシピ選択 → 在庫から投入枠へ配置<br/>（庭は選択肢に出さない。新規収穫不可）
            Player->>AlchemyUI: 「調合を実行する」を押下
            AlchemyUI->>GameState: execute_alchemy(selected_recipe_id, slot_materials)

            GameState->>AlchemyLogic: QualityCalculator / TraitActivation / ProductValueCalculator
            AlchemyLogic-->>GameState: ProductInstance(quality, traits, contribution, reward)

            GameState->>GuildLogic: DeliveryResolver.resolve(product, null)
            Note right of GuildLogic: daily_orderにnullを渡す→matches_orderは常にfalse<br/>（指定合致ボーナスは不適用。報酬系特性のボーナス自体は通常どおり計算される）
            GuildLogic-->>GameState: DeliveryResult(final_contribution, final_reward, order_matched=false)

            GameState->>RankLogic: RankQuotaResolver.apply_contribution(exam_state.exam_quota, final_contribution)
            RankLogic-->>GameState: new_exam_quota

            GameState->>GameState: exam_state.exam_quota = new_exam_quota<br/>player.gold += final_reward（🔵2026-08-05追加、PRレビュー対応。報酬は通常どおり獲得する）<br/>exam_state.exam_elapsed_turn += 1
        else 調合を実行せずターンだけ進める（🔵2026-08-05追加、PRレビューCritical#10対応）
            Player->>AlchemyUI: 「ターンを進める」を押下<br/>（在庫/解禁レシピが尽きて調合できない場合の脱出手段）
            AlchemyUI->>GameState: pass_exam_turn()
            GameState->>RankLogic: PromotionExamResolver.advance_turn(exam_state)
            RankLogic-->>GameState: exam_state（exam_elapsed_turnのみ+1）
        end

        GameState->>RankLogic: PromotionExamResolver.resolve_outcome(exam_state)
        RankLogic-->>GameState: ExamOutcome(CONTINUE/SUCCESS/FAILURE)
    end

    alt ExamOutcome == SUCCESS
        GameState->>GameState: demotion_count = 0（🔵2026-08-05追加、PRレビューCritical#3対応）
        GameState-->>AlchemyUI: signal exam_succeeded
        AlchemyUI-->>Player: WorkshopScreenへ遷移（恒久投資、購入は任意）
    else ExamOutcome == FAILURE
        GameState->>RankLogic: RankQuotaResolver.reset_for_retry(rank_master)
        RankLogic-->>GameState: リセット済みRankState（🔵2026-08-05追加、PRレビューCritical#3対応）
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
        Playing --> Playing: ターン終了（ノルマ>0 かつ 制限ターン未到達）
    }

    RankG --> TurnLoop
    TurnLoop --> PromotionCheck: 制限ターン到達

    state PromotionCheck <<choice>>
    PromotionCheck --> PromotionExam: ランクノルマ == 0
    PromotionCheck --> Demotion: ランクノルマ > 0

    state PromotionExam2 <<choice>>
    PromotionExam --> PromotionExam2
    PromotionExam2 --> GameClear: 試験成功 かつ 現ランク == S
    PromotionExam2 --> Workshop: 試験成功 かつ 現ランク != S
    PromotionExam2 --> Demotion: 試験失敗

    Demotion --> ResetRankRetry: ランクノルマ/残りターンをリセット<br/>（庭・在庫・ゴールド・恒久投資は維持）
    ResetRankRetry --> DemotionCheck
    state DemotionCheck <<choice>>
    DemotionCheck --> TurnLoop: 降格回数 < 規定回数
    DemotionCheck --> GameOver: 降格回数 >= 規定回数

    Workshop --> RankNext: 恒久投資選択完了（降格回数カウンタを0にリセット）
    RankNext --> TurnLoop: 次ランクのターンループ開始

    GameClear --> [*]
    GameOver --> [*]
```

🔵 要件定義書§2「勝敗条件」の「降格」定義（ランク文字は下がらず同一ランクに留まる）に忠実に、`Demotion`から`TurnLoop`へ戻る遷移（ランクは変わらない）として表現した。

🔵 **2026-08-05修正（PRレビューWarning対応）**: 旧版は「試験成功→常にWorkshop経由→RankNext→（Sランクだった場合のみ）GameClear」という経路になっており、全体フロー図（本文書冒頭）の「Sランクは工房強化を経由せず直接ゲームクリア」という経路と矛盾していた。次ランクが存在しないSランクで恒久投資画面を経由する意味がないため、`PromotionExam2`からの分岐時点でSランクなら`GameClear`へ直接遷移するよう修正した。あわせて降格時のランクノルマ/残りターンのリセット、昇格成功時の降格回数カウンタのリセットも明示した（[`core-systems.md`](./core-systems.md) RankSystem節参照）。
