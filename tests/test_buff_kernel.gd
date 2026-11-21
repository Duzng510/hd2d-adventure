extends SceneTree

## T-030: the offer is seeded, never repeats a picked buff, and every op in the
## pool actually moves the stat it names (a wrong key would silently no-op).

var _checks: int = 0
var _failures: int = 0
var _negative: bool = false


func _initialize() -> void:
	_negative = OS.get_cmdline_user_args().has("negative")
	var kernel := BuffKernel.new(BuffPool.pool(), 4242)
	var first := kernel.offer()
	_check(first.size() == (2 if _negative else 3), "an offer holds exactly 3 buffs")
	_check(kernel.offer() == first, "asking twice before taking returns the same offer")

	var again := BuffKernel.new(BuffPool.pool(), 4242)
	_check(again.offer() == first, "the same seed reproduces the same offer")
	var other := BuffKernel.new(BuffPool.pool(), 4241)
	_check(other.offer() != first or _negative, "a different seed changes the offer")

	var picked: Dictionary = first[0]
	_check(kernel.take(&"no_such_buff").is_empty(), "taking an id that is not offered returns nothing")
	var taken := kernel.take(picked["id"])
	_check(taken.get("id", &"") == picked["id"]
		and (taken["ops"] as Dictionary).size() == (picked["ops"] as Dictionary).size(),
		"taking an offered id returns its entry")
	_check(kernel.take(picked["id"]).is_empty(), "a buff cannot be taken twice")
	_check(kernel.picked_ids() == [picked["id"]], "picked list records the id once")

	var second := kernel.offer()
	_check(second.size() == 3 and not second.any(func(e): return e["id"] == picked["id"]),
		"the next offer excludes the picked buff")

	kernel.reset()
	_check(kernel.picked_ids().is_empty(), "reset clears the picked list")
	_check(kernel.offer() == first, "reset rewinds the seeded sequence")

	for entry in BuffPool.pool():
		var stats := PlayerStats.new(CombatTuning.new())
		var before := _snapshot(stats)
		stats.add_modifier(entry["id"], entry["ops"])
		var after := _snapshot(stats)
		_check(after != before, "pool op '%s' moves at least one stat" % entry["id"])

	# T-030 final review: the entry-level check above only proves that *some* key
	# moved. A wrong key inside an entry would silently no-op, so each op is
	# applied alone and must move the getter it names.
	for entry in BuffPool.pool():
		var ops: Dictionary = entry["ops"]
		for op_key in ops:
			var single := PlayerStats.new(CombatTuning.new())
			var before: Variant = _read_op(single, op_key)
			single.add_modifier(entry["id"], {op_key: ops[op_key]})
			var after: Variant = _read_op(single, op_key)
			var moved := false
			if before != null and after != null:
				if typeof(before) == TYPE_FLOAT:
					moved = not is_equal_approx(float(after), float(before))
				else:
					moved = after != before
			_check(moved, "op '%s' in '%s' moves its own getter" % [op_key, entry["id"]])

	if _failures == 0:
		print("PASS test_buff_kernel: %d checks" % _checks)
		quit(0)
	else:
		print("FAIL test_buff_kernel: %d/%d checks failed" % [_failures, _checks])
		quit(1)


## Resolver for one pool op key: strips the _add/_mult suffix and reads exactly
## the getter the key names. Unknown keys return the null sentinel so a typo in
## the pool fails the per-op check instead of passing silently.
func _read_op(stats: PlayerStats, op_key: StringName) -> Variant:
	match str(op_key).trim_suffix("_add").trim_suffix("_mult"):
		"light_damage": return stats.light_damage()
		"player_max_hp": return stats.player_max_hp()
		"light_startup_frames": return stats.light_startup_frames()
		"light_recovery_frames": return stats.light_recovery_frames()
		"light_combo_hits": return stats.light_combo_hits()
		"combo_window_frames": return stats.combo_window_frames()
		"fatigue_free_swings": return stats.fatigue_free_swings()
		"fatigue_step_frames": return stats.fatigue_step_frames()
		"fatigue_max_frames": return stats.fatigue_max_frames()
		"fatigue_decay_frames": return stats.fatigue_decay_frames()
		"dodge_total_frames": return stats.dodge_total_frames()
		"dodge_iframe_frames": return stats.dodge_iframe_frames()
		"light_reach": return stats.light_reach()
		"player_move_speed": return stats.move_speed()
	return null


func _snapshot(stats: PlayerStats) -> Array:
	return [
		stats.light_damage(), stats.player_max_hp(), stats.light_startup_frames(),
		stats.light_active_frames(), stats.light_recovery_frames(),
		stats.light_combo_hits(), stats.combo_window_frames(), stats.light_reach(),
		stats.move_speed(), stats.dodge_total_frames(), stats.fatigue_free_swings(),
		stats.fatigue_decay_frames(),
	]


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("FAIL: ", label)
