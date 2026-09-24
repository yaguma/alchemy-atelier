extends GdUnitTestSuite

## ui-polish Plan タスク010: ギルド納品画面表示時のフェードイン+完成品ポップ演出
## （ui-design/screens/guild-delivery.md L69）を検証する。show_with_animation()は
## visible=trueにしてからmodulate.aを0→1へフェードし、各結果行へUiEffects.play_pop_in()相当の
## 演出を順次適用する（呼び出し元AlchemyScreen._deliver_and_display()のvisible=true直書きを置換）。

const RECIPE_A: StringName = &"recipe_a"
const RECIPE_B: StringName = &"recipe_b"


func before_test() -> void:
	GameState.reset_for_test()
	var masters := {
		RECIPE_A: _make_recipe(RECIPE_A, "回復薬"),
		RECIPE_B: _make_recipe(RECIPE_B, "聖水"),
	}
	GameState._set_recipe_masters_for_test(masters)
	var rank := RankMaster.new()
	rank.id = "rank_test"
	rank.display_name = "見習い"
	rank.quota_max = 100.0
	GameState._set_rank_masters_for_test({&"rank_test": rank})
	GameState._set_current_rank_id_for_test(&"rank_test")


func _make_recipe(id: StringName, recipe_name: String) -> RecipeMaster:
	var recipe := RecipeMaster.new()
	recipe.id = id
	recipe.name = recipe_name
	return recipe


func _make_product(recipe_id: StringName, quality: int) -> ProductInstance:
	var no_tags: Array[StringName] = []
	return ProductInstance.new(recipe_id, quality, no_tags, 0.0, 0.0)


func _make_result(contribution: float, reward: float) -> DeliveryResult:
	return DeliveryResult.new(contribution, reward, false)


func _make_screen() -> GuildDeliveryScreen:
	var runner := scene_runner("res://features/guild/ui/guild_delivery_screen.tscn")
	return runner.scene() as GuildDeliveryScreen


func _find_row(screen: GuildDeliveryScreen, index: int) -> GuildDeliveryResultRow:
	return screen.find_child("DeliveryEntry_%d" % index, true, false) as GuildDeliveryResultRow


func _max_show_duration() -> float:
	return (
		UiTheme.ANIM_DURATION_FADE_SCREEN
		+ GuildDeliveryScreen.RESULT_ROW_POP_STAGGER * 2
		+ UiTheme.ANIM_DURATION_POP_IN
		+ 0.2
	)


# 正常系


func test_show_with_animation呼び出し直後にvisibleがtrueになりmodulateが0から変化し始める() -> void:
	var screen := _make_screen()
	screen.visible = false

	screen.show_with_animation()

	assert_bool(screen.visible).is_true()
	assert_float(screen.modulate.a).is_less(1.0)


func test_show_with_animation完了後にmodulateが完全に不透明へ収束する() -> void:
	var screen := _make_screen()
	screen.visible = false

	screen.show_with_animation()
	await get_tree().create_timer(_max_show_duration()).timeout

	assert_float(screen.modulate.a).is_equal_approx(1.0, 0.01)


func test_show_with_animation完了後に全結果行のscaleがONEへ収束する() -> void:
	var screen := _make_screen()
	var products: Array[ProductInstance] = [
		_make_product(RECIPE_A, 3),
		_make_product(RECIPE_B, 4),
	]
	var results: Array[DeliveryResult] = [
		_make_result(10.0, 5.0),
		_make_result(20.0, 6.0),
	]
	screen.display_results(products, results)
	screen.visible = false

	screen.show_with_animation()
	await get_tree().create_timer(_max_show_duration()).timeout

	for index in range(2):
		var row := _find_row(screen, index)
		assert_vector(row.scale).is_equal_approx(Vector2.ONE, Vector2(0.01, 0.01))


func test_結果行のポップ演出は順次適用され同時には発生しない() -> void:
	var screen := _make_screen()
	var products: Array[ProductInstance] = [
		_make_product(RECIPE_A, 3),
		_make_product(RECIPE_B, 4),
	]
	var results: Array[DeliveryResult] = [
		_make_result(10.0, 5.0),
		_make_result(20.0, 6.0),
	]
	screen.display_results(products, results)
	screen.visible = false

	screen.show_with_animation()
	# 🔴 コードレビュー指摘対応: 以前は「stagger前はscale ONE（未着手=フルサイズ表示）」を
	# 正としていたが、これは表示中に一瞬フルサイズで見えてしまうチラつきバグそのものだった。
	# 修正後の_play_result_row_pop_ins()は全行を事前にscale ZEROへ揃え、さらに
	# _entry_container（VBoxContainer）側の予約済みqueue_sort()（1フレーム後にscaleを
	# Vector2.ONEへ巻き戻すGodotの既知の挙動）をやり過ごすため内部で1フレーム待ってから
	# 改めてZEROへ揃え直す。stagger_tweenの生成自体もその内部待機の後になるため、
	# 実時間の僅かな差分（RESULT_ROW_POP_STAGGER - 数十ms等）に依存する検証は
	# テスト実行環境のフレーム時間のばらつきに弱くフレーキーになる。代わりに、
	# stagger_tween生成からほぼ間を置かない安全なタイミング（2フレーム後）で
	# 2件目（自分の番はRESULT_ROW_POP_STAGGER秒後まで来ない）がまだZEROのままであることを
	# 確認することで「順次」（同時に全行がポップインしない）を検証する
	await get_tree().process_frame
	await get_tree().process_frame

	var second_row := _find_row(screen, 1)
	# 🔵 Control.scaleはGodot内部でCMP_EPSILON（0.00001）未満のゼロ成分をクランプするため、
	# 他のscale検証（本ファイル内の他テスト）と同様にis_equal_approx()で比較する
	assert_vector(second_row.scale).is_equal_approx(Vector2.ZERO, Vector2(0.001, 0.001))


# 境界値


func test_結果行が0件でもクラッシュせずフェードインが完了する() -> void:
	var screen := _make_screen()
	screen.display_results([] as Array[ProductInstance], [] as Array[DeliveryResult])
	screen.visible = false

	screen.show_with_animation()
	await get_tree().create_timer(_max_show_duration()).timeout

	assert_float(screen.modulate.a).is_equal_approx(1.0, 0.01)
