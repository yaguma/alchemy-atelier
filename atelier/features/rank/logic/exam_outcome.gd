# 🔵 昇格試験の結果3値を表す列挙（requirements.md FR-005）。
# 🔵 RankOutcomeとは判定対象（ランク進行 vs 試験）が異なるため統合せず独立した型として定義する。
class_name ExamOutcome
extends RefCounted

## 🔵 昇格試験の判定結果。CONTINUE=試験継続、SUCCESS=試験合格、FAILURE=試験失敗。
enum Value { CONTINUE, SUCCESS, FAILURE }
