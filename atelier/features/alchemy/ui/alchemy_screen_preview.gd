class_name AlchemyScreenPreview

## AlchemyScreenのプレビュー計算・指定依頼表示に関するロジックを切り出したstatic適用クラス。
## AlchemyScreen本体が300行ルールを超過したための責務分割であり、振る舞いは分割前と同一。
## PixelBackdropApplier/AlchemyScreenEffectsと同型の「状態を持たずAlchemyScreen側の
## 状態を引数で受け取るstatic適用クラス」パターンに従う。


## 素材投入を決める前に現在の指定依頼を確認できるよう、daily_order_for_preview
## （🔵 AlchemyScreen._refresh()でキャッシュ済み。試験中はnull）の内容をラベルへ反映する。
## 🔵 倍率は表示するだけで乗算は一切行わない（プレビュー側との二重乗算防止）
static func update_daily_order_label(
	daily_order_label: Label,
	daily_order_for_preview: DailyOrderMaster,
	recipe_masters: Dictionary,
	none_text: String,
	item_format: String,
	trait_format: String
) -> void:
	if daily_order_label == null:
		return
	if daily_order_for_preview == null:
		daily_order_label.text = none_text
		return

	var order := daily_order_for_preview
	if order.condition_type == "trait":
		daily_order_label.text = trait_format % [order.target_trait, order.match_bonus_multiplier]
		return
	var recipe_name := resolve_recipe_display_name(recipe_masters, order.target_recipe_id)
	daily_order_label.text = item_format % [recipe_name, order.match_bonus_multiplier]


## recipe_idに対応するRecipeMasterの表示名を返す。🔴 マスター未ロード等で解決できない場合は
## 空欄にせずrecipe_id自体をフォールバック表示する（GardenScreenのSeedMaster欠落時と同方針）
static func resolve_recipe_display_name(recipe_masters: Dictionary, recipe_id: String) -> String:
	var master: Variant = recipe_masters.get(StringName(recipe_id))
	if master is RecipeMaster:
		return (master as RecipeMaster).name
	return recipe_id


## ProductProvisionalResolver（QualityCalculator -> TraitActivation -> ProductValueCalculator の
## 3段階パイプライン） -> DeliveryResolver を同期呼び出しし、AlchemyPreviewPanelへ結果を渡す。🔵 AC-007
## 🔴 コードレビュー指摘対応。GameStateAlchemyDelegate.execute_alchemy()と同一の
## ProductProvisionalResolverを経由することで両者の計算結果が乖離しないようにし、
## 指定依頼の判定にも呼び出し元がキャッシュ済みのdaily_order_for_preview（試験中はnull）を使う
## ことで、実際の納品処理（GameStateGuildDelegate.deliver_pending_products）と同じ扱いにする
## 🔵 戻り値はTraitActivation.resolve_traits()が確定した発現済みタグ配列（ProductInstance経由）。
## 新規発現ハイライト判定は、この戻り値を呼び出し元が前回結果と比較するだけであり、
## 判定ロジック自体はここでもUI層でも新規実装しない
static func recompute_preview(
	preview_panel: AlchemyPreviewPanel,
	recipe_masters: Dictionary,
	selected_recipe_id: StringName,
	daily_order_for_preview: DailyOrderMaster,
	materials: Array[MaterialInstance],
	market_rates: Dictionary = {}
) -> Array[StringName]:
	if preview_panel == null:
		return []
	var recipe: Variant = recipe_masters.get(selected_recipe_id)
	if materials.is_empty() or not (recipe is RecipeMaster):
		preview_panel.show_empty()  # 🔵 AC-007異常系。レシピ未選択・0投入では計算自体を行わない
		return []

	var traits_unlocked := GameState.is_current_rank_traits_unlocked()
	if (recipe as RecipeMaster).is_intermediate():
		return _recompute_intermediate_preview(
			preview_panel, recipe as RecipeMaster, materials, traits_unlocked
		)

	var provisional := ProductProvisionalResolver.resolve(
		materials, recipe as RecipeMaster, traits_unlocked
	)
	# 🔵 Issue #65。実際の納品と同じ相場倍率を掛け、プレビューと納品結果が食い違わないようにする
	var market_multiplier := MarketRateResolver.get_rate(market_rates, selected_recipe_id)
	var result := DeliveryResolver.resolve(provisional, daily_order_for_preview, market_multiplier)

	preview_panel.show_preview(
		provisional.quality_score,
		provisional.activated_traits,
		result.final_contribution,
		result.final_reward,
		result.order_matched
	)
	return provisional.activated_traits


## 🔵 Issue #66（FR-713）。中間素材レシピは実行時と同じIntermediateCrafterで組み立てた結果を表示する。
## 戻り値は特性ハイライト判定用の発現済みタグ（納品用と同じTraitActivationの結果）
static func _recompute_intermediate_preview(
	preview_panel: AlchemyPreviewPanel,
	recipe: RecipeMaster,
	materials: Array[MaterialInstance],
	traits_unlocked: bool
) -> Array[StringName]:
	var preview_material := IntermediateCrafter.craft(materials, recipe, traits_unlocked, "")
	preview_panel.show_intermediate_preview(
		preview_material.quality_score, preview_material.trait_tags
	)
	return TraitActivation.resolve_traits(materials, traits_unlocked)
