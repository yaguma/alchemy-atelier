# 🔵 工房強化の購入確認ダイアログに表示する効果説明文を生成する純粋関数群。
# 副作用なし、Node非継承、GameState・UI層への参照禁止（Functional Core原則）。
class_name UpgradeEffectDescriber


## 🔵 effect_typeに応じた日本語の効果説明文を返す。effect_valueの型は呼び出し元が
## PurchaseValidator.is_valid_effect()で検証済みである前提のため、ここで型ガードを
## 重複させない（_apply_upgrade_effect()と同じ設計判断）。
## 🟡 recipe_unlock/seed_name_purchaseはeffect_valueのIDを人間可読名に解決せず汎用文言を返す
## （他Featureのマスターデータ参照を避けるため）。
## 🟡 未知のeffect_typeは空文字列を返す（事前に弾かれる想定の防御的分岐。
## 呼び出し元は空文字列時に説明欄を非表示/空表示にする）
static func describe(upgrade: UpgradeMaster) -> String:
	match upgrade.effect_type:
		&"alchemy_slot_increase":
			return "調合の投入枠が%d増えます" % (upgrade.effect_value as int)
		&"garden_slot_increase":
			return "庭の仕込み枠が%d増えます" % (upgrade.effect_value as int)
		&"catalyst_stock":
			# 🔵 _apply_upgrade_effect()が常に触媒素材を1個生成する仕様に対応した固定文言
			return "触媒素材を1個獲得します"
		&"recipe_unlock":
			return "新しいレシピが解放されます"
		&"seed_name_purchase":
			return "新しい種を購入できるようになります"
		_:
			return ""
