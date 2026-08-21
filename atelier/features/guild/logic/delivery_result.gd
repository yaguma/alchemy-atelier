# 🔵 納品1件の決算結果を表すランタイム値（core-systems.md L200-205クラス図）。
# 🔴 features/guild/logic/に配置する（CON-003）。
# 🔴 コードレビュー指摘対応（2026-08-21）。当初はDeliveryResolverと同一Feature内のみが
# 利用元という前提で配置したが、AlchemyScreen（features/alchemy/ui/）がライブプレビュー用に
# DeliveryResolver.resolve()を直接呼び出しDeliveryResultを消費するようになったため、この前提は
# もう成立しない。architecture.mdの「他Featureから参照してよいのはlogic/*.gdとresources/*.gdのみ」
# ルールには合致しており配置自体は変更不要だが、フィールド変更時はalchemy Feature側への影響も
# 確認すること（guild Feature単体のテストでは検知できない）
class_name DeliveryResult
extends RefCounted

var final_contribution: float
var final_reward: float
var order_matched: bool


## 🔵 core-systems.mdのフィールド定義に従い各プロパティを設定する。
## 貢献度・報酬の算出および指定依頼の一致判定は呼び出し元（DeliveryResolver）の責務。
## 全フィールドがプリミティブ値型のため、clone()相当のディープコピーは不要
func _init(p_final_contribution: float, p_final_reward: float, p_order_matched: bool) -> void:
	final_contribution = p_final_contribution
	final_reward = p_final_reward
	order_matched = p_order_matched
