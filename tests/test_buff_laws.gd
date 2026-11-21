extends SceneTree

## T-030 DG2 (spec §6.1/§8): after every possible buff combination the tempo law
## still holds — fatigue_decay < fatigue_max (D-019) and every frame/cap getter
## stays >= 1. One check per 1-buff and 2-buff combination, plus a mutation proof
## that the same predicate can report a broken law (so the gate cannot go green
## vacuously).

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	var pool := BuffPool.pool()
	for a in pool.size():
		_check_combo([pool[a]] as Array[Dictionary])
	for a in pool.size():
		for b in range(a + 1, pool.size()):
			_check_combo([pool[a], pool[b]] as Array[Dictionary])

	# Mutation proof: pushing decay to the cap must fail the very predicate the
	# combinations above rely on.
	var broken := PlayerStats.new(CombatTuning.new())
	broken.add_modifier(&"bad_law", {&"fatigue_decay_frames_add": 12.0})
	_check(not _laws_hold(broken),
		"mutation: decay at the cap is rejected by the same law predicate")

	if _failures == 0:
		print("PASS test_buff_laws: %d checks" % _checks)
		quit(0)
	else:
		print("FAIL test_buff_laws: %d/%d checks failed" % [_failures, _checks])
		quit(1)


func _check_combo(combo: Array[Dictionary]) -> void:
	var stats := PlayerStats.new(CombatTuning.new())
	var ids: Array[String] = []
	for entry in combo:
		stats.add_modifier(entry["id"], entry["ops"])
		ids.append(str(entry["id"]))
	_check(_laws_hold(stats), "law holds after %s" % "+".join(ids))


func _laws_hold(stats: PlayerStats) -> bool:
	if stats.fatigue_decay_frames() >= stats.fatigue_max_frames():
		return false
	var frames := [
		stats.light_startup_frames(), stats.light_active_frames(),
		stats.light_recovery_frames(), stats.combo_window_frames(),
		stats.fatigue_free_swings(), stats.fatigue_step_frames(),
		stats.fatigue_max_frames(), stats.fatigue_decay_frames(),
		stats.dodge_total_frames(), stats.dodge_iframe_frames(),
	]
	return not frames.any(func(value: int) -> bool: return value < 1)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("FAIL: ", label)
