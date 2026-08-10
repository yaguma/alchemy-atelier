extends Node

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func set_seed(seed: int) -> void:
	_rng.seed = seed


func randf() -> float:
	return _rng.randf()


func randf_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to)


func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)
