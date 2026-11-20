extends Node

## T-019 swarm composition evidence: wave 1 must spawn 2 Grunt + 3 Swarm
## simultaneously and the encounter must still clear. 3 runs.
## Headless:
##   <GODOT> --headless --path . res://scenes/phase_c/run_t019_swarm.tscn --fixed-fps 60
## Negative (swarm scene mapping erased) must exit 1:
##   ... --fixed-fps 60 -- negative

const TARGET_RUNS := 3
const MAX_TICKS := 15000
## Wave 2 kites, so the harness follows the nearest alive enemy instead of
## pinning one point; the 0.8 m offset keeps the target inside light_reach (1.4).
const FOLLOW_OFFSET := 0.8

var _encounter: WaveEncounter
var _combat: PlayerCombat
var _player: PlayerController
var _negative := false


func _ready() -> void:
	_negative = OS.get_cmdline_user_args().has("negative")
	var arena := get_node("../GroveArena")
	_encounter = arena.get_node("WaveEncounter")
	_combat = arena.get_node("Player/PlayerCombat")
	_player = arena.get_node("Player")
	_combat.aim_override_enabled = true
	if _negative:
		_encounter.enemy_scenes.erase("swarm")
		# Arena _ready already spawned wave 1 before this driver ran; reset so the
		# first sampled run spawns without the swarm mapping.
		_encounter.reset_run()
	_run()


func _run() -> void:
	var ticks := 0
	var last_runs := 0
	var reset_checks_ok := true
	var swarms_seen := 0
	var grunts_seen := 0
	while _encounter.runs_completed < TARGET_RUNS and ticks < MAX_TICKS:
		await get_tree().physics_frame
		ticks += 1
		# Runs before the staging teleport below: this coroutine resumes on
		# physics_frame, i.e. before node _physics_process, so on the tick after
		# a reset the player is still at player_spawn here. Checking after the
		# teleport would always see the staging point instead.
		if _encounter.runs_completed != last_runs:
			last_runs = _encounter.runs_completed
			var hp_ok := _combat.hp() == _combat.health.max_hp and not _combat.is_dead()
			var pos_ok := _player.global_position.distance_to(_encounter.player_spawn) < 0.1
			var wave_ok := _encounter.kernel.wave_index == 0
			var enemies_ok := _encounter.alive_count() == _encounter.wave_size(0)
			if not (hp_ok and pos_ok and wave_ok and enemies_ok):
				reset_checks_ok = false
		var state := _encounter.kernel.state
		if state == WaveKernel.State.FIGHTING or state == WaveKernel.State.PAUSED:
			if _encounter.kernel.wave_index == 0 and _encounter.alive_count() > 0:
				var swarms := 0
				var grunts := 0
				for enemy in _encounter.enemies():
					if enemy is Swarm:
						swarms += 1
					else:
						grunts += 1
				swarms_seen = maxi(swarms_seen, swarms)
				grunts_seen = maxi(grunts_seen, grunts)
			if _encounter.alive_count() > 0:
				var target := _encounter.nearest_alive_position()
				var staging := target + Vector3(FOLLOW_OFFSET if target.x < 0.0 else -FOLLOW_OFFSET, 0.0, 0.0)
				if _player.global_position.distance_to(staging) > 0.4:
					_player.global_position = staging
					_player.velocity = Vector3.ZERO
			_combat.health.hp = _combat.health.max_hp
			_combat.aim_override_point = _encounter.nearest_alive_position()
			if _combat.attack_phase() == AttackState.Phase.NONE:
				_combat.debug_request_attack()
		if state == WaveKernel.State.WON:
			# T-022: a win hands control back to the player, so the harness resets.
			_encounter.reset_run()
	var completed := _encounter.runs_completed >= TARGET_RUNS
	print("runs=%d wins=%d swarms=%d grunts=%d reset_checks=%s ticks=%d" % [
		_encounter.runs_completed, _encounter.wins, swarms_seen, grunts_seen,
		str(reset_checks_ok), ticks,
	])
	var ok := (
		completed
		and _encounter.wins == TARGET_RUNS
		and swarms_seen == 3
		and grunts_seen == 2
		and reset_checks_ok
		and ticks < MAX_TICKS
	)
	# Evidence ids consumed by tools/run_evidence.mjs.
	print("CHECK %s E1.1 wave 1 spawn %d Swarm + %d Grunt dong thoi (can 3+2)" % [
		"PASS" if swarms_seen == 3 and grunts_seen == 2 else "FAIL", swarms_seen, grunts_seen,
	])
	print("CHECK %s flow.reset_state hp/spawn/wave/enemies chuan sau moi reset" % [
		"PASS" if reset_checks_ok else "FAIL",
	])
	print("PASS t019_swarm" if ok else "FAIL t019_swarm")
	get_tree().quit(0 if ok else 1)
