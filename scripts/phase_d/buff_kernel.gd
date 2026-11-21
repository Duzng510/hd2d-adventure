class_name BuffKernel
extends RefCounted

## T-030: seeded offer/take kernel. Same seed reproduces the same offer order;
## a picked buff never appears again in the run.

var _pool: Array[Dictionary]
var _seed: int
var _rng := RandomNumberGenerator.new()
var _picked: Array[StringName] = []
var _pending: Array[Dictionary] = []


func _init(pool: Array[Dictionary], seed_value: int) -> void:
	_pool = pool
	_seed = seed_value
	_rng.seed = seed_value


func offer() -> Array[Dictionary]:
	if not _pending.is_empty():
		return _pending.duplicate()
	var remaining: Array[Dictionary] = []
	for entry in _pool:
		if not _picked.has(entry["id"]):
			remaining.append(entry)
	for i in range(remaining.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var swap: Dictionary = remaining[i]
		remaining[i] = remaining[j]
		remaining[j] = swap
	_pending = remaining.slice(0, mini(3, remaining.size()))
	return _pending.duplicate()


func take(id: StringName) -> Dictionary:
	for entry in _pending:
		if entry["id"] == id:
			_picked.append(id)
			_pending.clear()
			return entry
	return {}


func picked_ids() -> Array[StringName]:
	return _picked.duplicate()


func reset() -> void:
	_picked.clear()
	_pending.clear()
	_rng.seed = _seed
