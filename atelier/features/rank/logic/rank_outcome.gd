# 🔵 ランク結果の3値を表す列挙（core-systems.md L305-310クラス図）。
# 🔴 TurnLimitResolverとGameStateの両方から参照されるため、state/ではなく
# features/rank/logic/に単独ファイルとして配置する（CON-003）。
class_name RankOutcome
extends RefCounted

## 🔵 ランク進行の判定結果。CONTINUE=継続、PROMOTION_ELIGIBLE=昇格試験挑戦可、DEMOTION=降格。
enum Value { CONTINUE, PROMOTION_ELIGIBLE, DEMOTION }
