extends Node

## T-027 tempo evidence. Two bots fight the same solo boss under the same
## authored cadence; the only difference is whether they stop swinging to stay
## at full speed. If the mechanic is real, mashing must pay fatigue, swing less
## often per tick and eat more enemy damage per unit of damage dealt.
##
##   <GODOT> --headless --path . res://scenes/phase_c/run_t027_tempo.tscn --fixed-fps 60
##   ... -- negative  (free allowance made huge: mash and paced become the same
##        player, so the tempo checks must go red)                       -> exit 1

const RUNS := 3
const MAX_TICKS := 3600
const BOSS_OFFSET := Vector3(0.0, 0.0, -1.0)
const POLICIES := ["mash", "paced"]
const TUNING_PATH := "res://scripts/combat/combat_tuning.tres"

var _arena: Node3D
var _player: PlayerController
var _combat: PlayerCombat
var _encounter: WaveEncounter
var _director: CombatDirector
var _negative := false
var _results: Array = []
var _checks := 0
var _failures := 0
var _swings := 0
var _hits_taken := 0
var _fatigue_total := 0
var _fatigue_max := 0


func _enter_tree() -> void:
	# Runs before the arena subtree is ready, so the shared tuning resource can
	# still be edited before PlayerCombat builds its TempoFatigue from it.
	_negative = OS.get_cmdline_user_args().has("negative")
	if _negative:
		var tuning: CombatTuning = load(TUNING_PATH)
		tuning.fatigue_free_swings = 100000


func _ready() -> void:
	_arena = get_node("GroveArena")
	_player = _arena.get_node("Player") as PlayerController
	_combat = _arena.get_node("Player/PlayerCombat") as PlayerCombat
	_encounter = _arena.get_node("WaveEncounter") as WaveEncounter
	_director = _arena.get_node("CombatDirector") as CombatDirector
	_director.event_logged.connect(_observe)
	_run.call_deferred()


func _run() -> void:
	for policy in POLICIES:
		for run in RUNS:
			_results.append(await _one_run(policy))
	_verify()


func _one_run(policy: String) -> Dictionary:
	_encounter.reset_run()
	_encounter.debug_clear_enemies()
	var boss := _encounter.debug_spawn("boss", _player.global_position + BOSS_OFFSET)
	if boss == null:
		return {}
	_swings = 0
	_hits_taken = 0
	_fatigue_total = 0
	_fatigue_max = 0
	var ticks := 0
	while ticks < MAX_TICKS and boss.hp() > 0 and not _combat.is_dead():
		await get_tree().physics_frame
		ticks += 1
		_combat.aim_override_enabled = true
		_combat.aim_override_point = boss.global_position
		if _combat.attack_phase() == AttackState.Phase.NONE:
			if policy == "mash" or _combat.fatigue_frames() == 0:
				_combat.debug_request_attack()
	var damage := _combat.tuning.boss_max_hp - boss.hp()
	return {
		"policy": policy, "ticks": ticks, "swings": _swings, "damage": damage,
		"hits_taken": _hits_taken, "fatigue_total": _fatigue_total,
		"fatigue_max": _fatigue_max, "outcome": "kill" if boss.hp() <= 0 else "survived",
	}


func _observe(entity: StringName, event_name: StringName, _attack_id: int, _target_id: int, value: int) -> void:
	if event_name == &"action_start" and entity == &"player":
		_swings += 1
		_fatigue_total += value
		_fatigue_max = maxi(_fatigue_max, value)
	elif event_name == &"damage" and entity != &"player":
		_hits_taken += 1


func _verify() -> void:
	var mash := _summary("mash")
	var paced := _summary("paced")
	print("RESULT mash   %s" % [mash])
	print("RESULT paced  %s" % [paced])
	# Exposure is printed, not asserted: the boss attacks on its own clock, so both
	# policies eat the same damage in the same time. The mechanic's price is tempo,
	# and tempo only bites if it buys more damage before the player dies.
	_check(mash["runs"] == RUNS and paced["runs"] == RUNS and mash["damage"] > 0 and paced["damage"] > 0,
		"P27.1 both policies engaged and dealt damage (%d vs %d)" % [mash["damage"], paced["damage"]])
	_check(mash["fatigue_max"] > 0 and paced["fatigue_max"] == 0,
		"P27.2 mash pays fatigue (%d frames), paced pays none" % mash["fatigue_max"])
	# A margin, not a strict inequality: without one the check passes on a 1-tick
	# accounting difference between the two runs.
	_check(paced["swings_per_100t"] > mash["swings_per_100t"] * 1.05,
		"P27.3 paced swings at least 5%% more often (%.2f/100t vs %.2f/100t)" % [paced["swings_per_100t"], mash["swings_per_100t"]])
	_check(paced["damage"] > mash["damage"],
		"P27.4 paced deals more damage before dying (%d vs %d)" % [paced["damage"], mash["damage"]])
	_check(mash["hits_taken"] == paced["hits_taken"],
		"P27.5 exposure is time-driven, not tempo-driven (both ate %d hits)" % mash["hits_taken"])
	print("checks=%d failures=%d" % [_checks, _failures])
	print("%s t027_tempo: mash vs paced" % ("PASS" if _failures == 0 else "FAIL"))
	get_tree().quit(0 if _failures == 0 else 1)


func _summary(policy: String) -> Dictionary:
	var runs := _results.filter(func(run): return run.get("policy", "") == policy)
	var ticks := 0
	var swings := 0
	var damage := 0
	var hits := 0
	var fatigue_max := 0
	var kills := 0
	for run in runs:
		ticks += run["ticks"]
		swings += run["swings"]
		damage += run["damage"]
		hits += run["hits_taken"]
		fatigue_max = maxi(fatigue_max, run["fatigue_max"])
		kills += 1 if run["outcome"] == "kill" else 0
	return {
		"runs": runs.size(), "kills": kills, "ticks": ticks, "swings": swings,
		"damage": damage, "hits_taken": hits, "fatigue_max": fatigue_max,
		"ticks_per_hit": float(ticks) / maxf(float(swings), 1.0),
		"swings_per_100t": 100.0 * float(swings) / maxf(float(ticks), 1.0),
	}


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("CHECK PASS %s" % label)
		return
	_failures += 1
	print("CHECK FAIL %s" % label)
