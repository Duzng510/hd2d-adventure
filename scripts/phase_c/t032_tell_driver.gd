extends Node

## T-032 tell evidence: the ring must show the tier the mechanic actually charges.
## Three bots swing at three cadences and the driver samples the kernel and the
## view on every physics tick, so a display that lags, leads, or never moves is
## caught here rather than in a screenshot.
##
##   <GODOT> --headless --path . res://scenes/phase_c/run_t032_tell.tscn --fixed-fps 60
##   ... -- tell-off     export off: no consumer, ring art never changes      -> exit 0
##   ... -- broken-wire  arena consumer disconnected: the ring freezes green  -> exit 1
##   ... -- negative     fatigue neutered: no tier is ever paid               -> exit 1

const TICKS_PER_RUN := 300
const BOSS_OFFSET := Vector3(0.0, 0.0, -1.0)
const POLICIES := ["mash", "paced", "loose"]

var _arena: Node3D
var _player: PlayerController
var _combat: PlayerCombat
var _encounter: WaveEncounter
var _marker_material: StandardMaterial3D
var _mode := "live"
var _checks := 0
var _failures := 0
var _emits := 0
var _last_emit := -1
var _double_emits := 0
var _transitions := 0
var _bad_math := 0
var _prev_tier := 0
var _tick := 0
var _trace := false
var _results: Array = []


func _enter_tree() -> void:
	# Before the arena subtree is ready, so the export and the tuning are settled
	# by the time _add_self_marker() decides what art to build and connect.
	var args := OS.get_cmdline_user_args()
	_trace = args.has("trace")
	if args.has("tell-off"):
		_mode = "tell-off"
		(get_node("GroveArena") as Node).set("show_tempo_tell", false)
	elif args.has("broken-wire"):
		_mode = "broken-wire"
	elif args.has("negative"):
		_mode = "negative"
		var combat := get_node("GroveArena/Player/PlayerCombat") as PlayerCombat
		var fresh := CombatTuning.new()
		fresh.fatigue_free_swings = 100000
		combat.tuning = fresh


func _ready() -> void:
	_arena = get_node("GroveArena")
	_player = _arena.get_node("Player") as PlayerController
	_combat = _arena.get_node("Player/PlayerCombat") as PlayerCombat
	_encounter = _arena.get_node("WaveEncounter") as WaveEncounter
	_marker_material = (_arena.get_node("Player/SelfMarker") as MeshInstance3D).mesh.material
	if _mode == "broken-wire":
		for conn in _combat.fatigue_level_changed.get_connections():
			_combat.fatigue_level_changed.disconnect(conn["callable"])
	_combat.fatigue_level_changed.connect(_on_level)
	# Sampled on the tree's own frame signal, not inside the run loops: a tier
	# change on the reset tick between two runs must still be seen exactly once,
	# or the emit/transition comparison measures the harness instead of the tell.
	get_tree().physics_frame.connect(_sample)
	if _mode == "tell-off":
		await _verify_off()
		return
	_run.call_deferred()


func _on_level(level: int) -> void:
	_emits += 1
	if level == _last_emit:
		_double_emits += 1
	if _trace:
		print("EMIT  tick=%d level=%d" % [_tick, level])
	_last_emit = level


## One tick of the display law, sampled on every physics frame: the tier is the
## charged cost floored to whole steps, and every change of it is a transition
## the consumer must have been told about exactly once.
func _sample() -> void:
	_tick += 1
	var level := _combat.fatigue_level()
	if level != _combat.fatigue_frames() / _combat.stats.fatigue_step_frames():
		_bad_math += 1
	if level != _prev_tier:
		_transitions += 1
		if _trace:
			print("TRACE tick=%d %d->%d" % [_tick, _prev_tier, level])
		_prev_tier = level


func _run() -> void:
	for policy in POLICIES:
		_results.append(await _one_run(policy))
	var wipe: Dictionary = await _dodge_wipes_tier()
	# The emit for a tier change can land on the frame after the sample that saw
	# it (the driver reads on the tree signal, PlayerCombat publishes in its own
	# _physics_process). Let the queue settle or T32.3 would grade the harness.
	await get_tree().physics_frame
	await get_tree().physics_frame
	_verify(wipe)


func _one_run(policy: String) -> Dictionary:
	_encounter.reset_run()
	_encounter.debug_clear_enemies()
	var boss := _encounter.debug_spawn("boss", _player.global_position + BOSS_OFFSET)
	if boss == null:
		return {}
	var swings := 0
	var ticks := 0
	var max_tier := 0
	var max_swing_tier := 0
	var texture_start: Texture2D = _marker_material.albedo_texture
	while ticks < TICKS_PER_RUN and boss.hp() > 0 and not _combat.is_dead():
		await get_tree().physics_frame
		ticks += 1
		_combat.aim_override_enabled = true
		_combat.aim_override_point = boss.global_position
		var tier := _combat.fatigue_level()
		max_tier = maxi(max_tier, tier)
		if _combat.attack_phase() == AttackState.Phase.NONE:
			var wants := policy == "mash" or (policy == "paced" and tier == 0) or (policy == "loose" and tier <= 1)
			if wants:
				swings += 1
				max_swing_tier = maxi(max_swing_tier, tier)
				_combat.debug_request_attack()
	var texture_end: Texture2D = _marker_material.albedo_texture
	return {
		"policy": policy,
		"ticks": ticks,
		"swings": swings,
		"damage": _boss_damage(boss),
		"max_tier": max_tier,
		"max_swing_tier": max_swing_tier,
		"texture_moved": texture_start != texture_end,
		"level_max": _combat.fatigue_level_max(),
	}


func _boss_damage(boss: Node) -> int:
	return _combat.tuning.boss_max_hp - boss.hp()


## The other half of the readout: paying the cost back has to be visible too,
## or the ring only ever tells the player bad news one tick late.
func _dodge_wipes_tier() -> Dictionary:
	_encounter.reset_run()
	_encounter.debug_clear_enemies()
	var boss := _encounter.debug_spawn("boss", _player.global_position + BOSS_OFFSET)
	if boss == null:
		return {}
	var ticks := 0
	while ticks < 200 and _combat.fatigue_level() < _combat.fatigue_level_max():
		await get_tree().physics_frame
		ticks += 1
		_combat.aim_override_enabled = true
		_combat.aim_override_point = boss.global_position
		if _combat.attack_phase() == AttackState.Phase.NONE:
			_combat.debug_request_attack()
	var before := _combat.fatigue_level()
	while ticks < 260 and _combat.attack_phase() != AttackState.Phase.NONE:
		await get_tree().physics_frame
		ticks += 1
	Input.action_press(&"dodge")
	await get_tree().physics_frame
	Input.action_release(&"dodge")
	await get_tree().physics_frame
	return {"before": before, "after": _combat.fatigue_level(), "dodged": _combat.is_invulnerable()}


func _verify(wipe: Dictionary) -> void:
	for result in _results:
		print("RESULT %s" % [result.get("policy", "?")])
	var mash: Dictionary = _results[0]
	var paced: Dictionary = _results[1]
	var loose: Dictionary = _results[2]
	_check(mash["damage"] > 0 and paced["damage"] > 0 and loose["damage"] > 0,
		"T32.0 the tell is not a nerf: all three cadences still deal damage (%d/%d/%d)"
			% [mash["damage"], paced["damage"], loose["damage"]])
	# What the mechanic promises is about the swing decision, not about every tick:
	# a paced player is legitimately tired during the recovery of the swing they
	# already committed, and hands the tier back before choosing the next one.
	_check(
		mash["max_swing_tier"] == mash["level_max"]
			and paced["max_swing_tier"] == 0
			and loose["max_swing_tier"] == 1,
		"T32.1 tier charged at the swing decision: mash pays the ceiling (%d), paced pays none (%d), loose pays one (%d)"
			% [mash["max_swing_tier"], paced["max_swing_tier"], loose["max_swing_tier"]]
	)
	_check(
		paced["max_tier"] > 0 and loose["max_tier"] < loose["level_max"],
		"T32.1b paced still reads tired mid-recovery (%d), and the middle bot never sits on the ceiling (%d)"
			% [paced["max_tier"], loose["max_tier"]]
	)
	_check(_bad_math == 0, "T32.2 every sampled tick reads level == frames/step (offences=%d)" % _bad_math)
	_check(
		_emits > 0 and _emits == _transitions and _double_emits == 0,
		"T32.3 emits=%d == transitions=%d, no repeated level (%d)" % [_emits, _transitions, _double_emits]
	)
	_check(mash["texture_moved"], "T32.3b the ring material really changed texture under the ceiling tier")
	_check(wipe.get("dodged", false) and wipe.get("before", 0) > 0 and wipe.get("after", 99) == 0,
		"T32.5 a dodge drops the tier to 0 within a tick (%d -> %d)" % [wipe.get("before", -1), wipe.get("after", -1)])
	print("checks=%d failures=%d mode=%s" % [_checks, _failures, _mode])
	print("%s t032_tell: kernel, signal and ring agree" % ("PASS" if _failures == 0 else "FAIL"))
	get_tree().quit(0 if _failures == 0 else 1)


func _verify_off() -> void:
	# The export must hide the drawing without touching the mechanic: the cost is
	# still charged, the ring art is still the one T-026 measured.
	var texture_before: Texture2D = _marker_material.albedo_texture
	var connected := _combat.fatigue_level_changed.get_connections().size()
	_check(connected == 1, "T32.4 tell-off: the arena connects no consumer (connections=%d)" % connected)
	for tick in 120:
		await get_tree().physics_frame
		_combat.debug_request_attack()
	_check(_combat.fatigue_level() > 0, "T32.4 tell-off: the cost is still charged (%d)" % _combat.fatigue_level())
	_check(_marker_material.albedo_texture == texture_before, "T32.4 tell-off: mashing never swaps the ring art")
	print("checks=%d failures=%d mode=%s" % [_checks, _failures, _mode])
	print("%s t032_tell: tell-off path" % ("PASS" if _failures == 0 else "FAIL"))
	get_tree().quit(0 if _failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("CHECK PASS %s" % label)
		return
	_failures += 1
	print("CHECK FAIL %s" % label)
