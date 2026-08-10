# 🔵 収穫時の特性選択ロジック（FR-402、core-systems.md L45-48, L69）。
# 乱数はRngServiceが払い出した値を引数で受け取り、自己生成しない。
class_name TraitRoll


## seed_master.trait_poolからrng_value（[0,1)想定）を用いて一様に1つ選択する
static func roll_trait(seed_master: SeedMaster, rng_value: float) -> StringName:
	var pool := seed_master.trait_pool
	var index := clampi(int(rng_value * pool.size()), 0, pool.size() - 1)
	return pool[index]
