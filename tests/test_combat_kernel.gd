extends SceneTree

const TUNING_PATH := "res://scripts/combat/combat_tuning.tres"

var _checks: int = 0
var _failures: int = 0
var _negative: bool = false


func _initialize() -> void:
	_negative = OS.get_cmdline_user_args().has("negative")
	var tuning: CombatTuning = load(TUNING_PATH)
	if tuning == null:
		print("FAIL: cannot load ", TUNING_PATH)
		quit(1)
		return
	_test_attack_timeline(tuning)
	_test_attack_fatigue(tuning)
	_test_combo_window()
	_test_input_buffer(tuning)
	_test_dodge()
	_test_health()
	_test_hitstop()
	_test_hit_registry()
	if _failures == 0:
		print("PASS test_combat_kernel: %d checks" % _checks)
		quit(0)
	else:
		print("FAIL test_combat_kernel: %d/%d checks failed" % [_failures, _checks])
		quit(1)


func _test_attack_timeline(tuning: CombatTuning) -> void:
	var s := tuning.light_startup_frames
	var a := tuning.light_active_frames
	var r := tuning.light_recovery_frames
	var atk := AttackState.new(s, a, r, tuning.combo_window_frames, tuning.light_combo_hits)
	atk.start(1)
	_check(atk.phase == AttackState.Phase.STARTUP, "start -> startup")
	_check(atk.action_frame == 1, "action_frame starts at 1")
	for frame in range(1, s + a + r + 1):
		_check(atk.action_frame == frame, "action_frame %d" % frame)
		var expected := AttackState.Phase.RECOVERY
		if frame <= s:
			expected = AttackState.Phase.STARTUP
		elif frame <= s + a:
			expected = AttackState.Phase.ACTIVE
		_check(atk.phase == expected, "phase at frame %d" % frame)
		_check(atk.is_active() == (frame > s and frame <= s + a), "hitbox window at frame %d" % frame)
		atk.tick()
	_check(atk.phase == AttackState.Phase.NONE, "attack ends after recovery")
	_check(atk.action_frame == 0, "action_frame resets at end")
	_check(atk.combo_index == 0, "combo resets at end")


func _test_attack_fatigue(tuning: CombatTuning) -> void:
	# T-027 law: fatigue buys time only in recovery. Startup, the active window and
	# the combo window keep their authored length, so a player who chains on beat is
	# never punished - the cost lands on the swing after the combo runs out.
	var s := tuning.light_startup_frames
	var a := tuning.light_active_frames
	var r := tuning.light_recovery_frames
	var w := tuning.combo_window_frames
	var atk := AttackState.new(s, a, r, w, tuning.light_combo_hits)
	atk.start(1, 0)
	var clean := _timeline(atk, s + a + r + 20)
	_check(clean["startup"] == s, "fatigue 0 keeps authored startup")
	_check(clean["active"] == a, "fatigue 0 keeps authored active window")
	_check(clean["recovery"] == r, "fatigue 0 keeps authored recovery")
	_check(clean["chained"] == mini(w, r), "fatigue 0 keeps the combo window")

	atk.start(1, 4)
	_check(atk.fatigue_frames == 4, "the swing records the fatigue it started with")
	var tired := _timeline(atk, s + a + r + 20)
	var expected_recovery := r + (0 if _negative else 4)
	_check(tired["startup"] == s, "fatigue never touches startup")
	_check(tired["active"] == a, "fatigue never touches the active window")
	_check(tired["recovery"] == expected_recovery, "fatigue extends recovery only")
	_check(tired["chained"] == mini(w, r), "the combo window stays the authored length while fatigued")


# Runs one swing to completion and counts how many physics frames each phase held.
func _timeline(atk: AttackState, limit: int) -> Dictionary:
	var counts := {"startup": 0, "active": 0, "recovery": 0, "chained": 0}
	for tick in limit:
		if atk.phase == AttackState.Phase.STARTUP:
			counts["startup"] += 1
		elif atk.phase == AttackState.Phase.ACTIVE:
			counts["active"] += 1
		elif atk.phase == AttackState.Phase.RECOVERY:
			counts["recovery"] += 1
			if atk.can_combo():
				counts["chained"] += 1
		atk.tick()
	return counts


func _test_combo_window() -> void:
	var atk := AttackState.new(4, 3, 12, 8, 3)
	atk.start(1)
	for i in range(7):
		atk.tick()
	_check(atk.phase == AttackState.Phase.RECOVERY, "recovery reached")
	_check(atk.recovery_frame() == 1, "recovery_frame starts at 1")
	_check(atk.can_combo(), "combo valid at window start")
	for i in range(7):
		atk.tick()
	_check(atk.recovery_frame() == 8, "recovery_frame at window end")
	_check(atk.can_combo(), "combo valid at window end")
	atk.tick()
	_check(atk.recovery_frame() == 9, "recovery_frame past window")
	_check(not atk.can_combo(), "combo expired past window")
	atk.start(3)
	for i in range(7):
		atk.tick()
	_check(atk.phase == AttackState.Phase.RECOVERY, "third hit reaches recovery")
	_check(not atk.can_combo(), "combo capped at max hits")
	atk.cancel()
	_check(atk.phase == AttackState.Phase.NONE and atk.combo_index == 0, "cancel resets combo")


func _test_input_buffer(tuning: CombatTuning) -> void:
	var window := tuning.input_buffer_frames
	var buf := InputBuffer.new(window)
	_check(not buf.is_valid(0), "empty buffer is invalid")
	buf.push(100)
	_check(buf.is_valid(100), "valid at capture frame")
	_check(buf.is_valid(100 + window), "valid at window end")
	_check(not buf.is_valid(100 + window + 1), "expired after window")
	_check(not buf.consume(100 + window + 1), "consume expired -> false")
	_check(not buf.has_pending(), "expired consume clears buffer")
	buf.push(200)
	_check(buf.consume(200 + window), "consume within window -> true")
	_check(not buf.consume(200 + window), "single consume per push")
	buf.push(300)
	buf.clear()
	_check(not buf.has_pending(), "clear drops pending input")


func _test_dodge() -> void:
	var dodge := DodgeState.new(22, 10)
	dodge.start()
	_check(dodge.frame == 1 and dodge.is_active(), "dodge starts at frame 1")
	_check(dodge.is_invulnerable(), "iframe at frame 1")
	for i in range(9):
		dodge.tick()
	_check(dodge.frame == 10, "at iframe end")
	_check(dodge.is_invulnerable(), "iframe at frame 10")
	dodge.tick()
	_check(dodge.frame == 11 and not dodge.is_invulnerable(), "vulnerable after iframe")
	while dodge.is_active():
		dodge.tick()
	_check(dodge.frame == 0, "dodge ends after total frames")


func _test_health() -> void:
	var health := Health.new(100)
	_check(health.apply_damage(10) == 10 and health.hp == 90, "damage applied")
	_check(health.apply_damage(1000) == 90 and health.hp == 0 and health.is_dead(), "overkill clamps to hp")
	_check(health.apply_damage(5) == 0, "no damage after death")
	health.reset()
	_check(health.hp == 100 and not health.is_dead(), "reset restores hp")


func _test_hitstop() -> void:
	var stop := HitstopController.new()
	stop.request(3)
	_check(stop.tick(), "hitstop frozen tick 1")
	stop.request(2)
	_check(stop.tick(), "overlap policy keeps max remaining")
	_check(stop.tick(), "hitstop frozen tick 3")
	_check(not stop.tick(), "hitstop released after 3 ticks")
	stop.request(1)
	stop.reset()
	_check(not stop.tick(), "reset clears hitstop")


func _test_hit_registry() -> void:
	var registry := HitRegistry.new()
	registry.enforce = not _negative
	var swings := 100
	var active_ticks := 3
	var applied := 0
	var target := Health.new(30)
	var hp_resets_ok := true
	for swing in range(swings):
		target.reset()
		for tick in range(active_ticks):
			if registry.try_register(swing + 1, 1):
				applied += 1
				target.apply_damage(10)
		if target.hp != 20:
			hp_resets_ok = false
	_check(registry.duplicate_applied == 0, "0 duplicate damage in 100 swings")
	_check(applied == swings, "exactly one damage per swing")
	_check(hp_resets_ok, "target HP reset between swings")
	_check(registry.blocked_repeats == swings * (active_ticks - 1), "repeat overlaps blocked")
	var multi := HitRegistry.new()
	_check(multi.try_register(7, 1), "first hit on target 1")
	_check(multi.try_register(7, 2), "first hit on target 2")
	_check(not multi.try_register(7, 1), "second hit on target 1 blocked")
	_check(multi.duplicate_applied == 0, "multi-target swing has no duplicate")


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("FAIL: ", label)
