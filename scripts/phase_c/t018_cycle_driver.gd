extends Node

## T-018 structural replay: attack-spam with aim override clears all 3 waves.
## HP is topped up each tick because this harness verifies wave flow, not
## balance. Headless:
##   <GODOT> --headless --path . res://scenes/phase_c/run_t018_cycles.tscn --fixed-fps 60
## Negative control (corrupted reset state) must exit 1:
##   ... --fixed-fps 60 -- negative

const TARGET_RUNS := 10
const MAX_TICKS := 30000
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
	_run()


func _run() -> void:
	var ticks := 0
	var last_runs := 0
	var reset_checks_ok := true
	var max_wave_seen := 0
	while _encounter.runs_completed < TARGET_RUNS and ticks < MAX_TICKS:
		await get_tree().physics_frame
		ticks += 1
		var state := _encounter.kernel.state
		# Runs before the staging teleport below: this coroutine resumes on
		# physics_frame, i.e. before node _physics_process, so on the tick after
		# a reset the player is still at player_spawn here. Checking after the
		# teleport would always see the staging point instead.
		if _encounter.runs_completed != last_runs:
			last_runs = _encounter.runs_completed
			if _negative and last_runs == 1:
				_combat.health.hp = 0
			var hp_ok := _combat.hp() == _combat.health.max_hp and not _combat.is_dead()
			var pos_ok := _player.global_position.distance_to(_encounter.player_spawn) < 0.1
			var wave_ok := _encounter.kernel.wave_index == 0
			var enemies_ok := _encounter.alive_count() == _encounter.wave_size(0)
			if not (hp_ok and pos_ok and wave_ok and enemies_ok):
				reset_checks_ok = false
		if state == WaveKernel.State.FIGHTING or state == WaveKernel.State.PAUSED:
			_combat.health.hp = _combat.health.max_hp
			if _encounter.alive_count() > 0:
				var target := _encounter.nearest_alive_position()
				var staging := target + Vector3(FOLLOW_OFFSET if target.x < 0.0 else -FOLLOW_OFFSET, 0.0, 0.0)
				if _player.global_position.distance_to(staging) > 0.4:
					_player.global_position = staging
					_player.velocity = Vector3.ZERO
			_combat.aim_override_point = _encounter.nearest_alive_position()
			if _combat.attack_phase() == AttackState.Phase.NONE:
				_combat.debug_request_attack()
			max_wave_seen = maxi(max_wave_seen, _encounter.kernel.wave_index + 1)
	var completed := _encounter.runs_completed >= TARGET_RUNS
	print("runs=%d wins=%d losses=%d max_wave=%d reset_checks=%s ticks=%d" % [
		_encounter.runs_completed, _encounter.wins, _encounter.losses,
		max_wave_seen, str(reset_checks_ok), ticks,
	])
	var ok := (
		completed
		and _encounter.wins == TARGET_RUNS
		and max_wave_seen == _encounter.kernel.wave_count()
		and reset_checks_ok
		and ticks < MAX_TICKS
	)
	print("PASS t018_cycles: %d runs, full wave flow" % TARGET_RUNS if ok else "FAIL t018_cycles")
	get_tree().quit(0 if ok else 1)
