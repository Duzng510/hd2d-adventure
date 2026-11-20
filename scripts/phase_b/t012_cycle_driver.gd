extends Node

## T-012 automated replay: the player stands still, the Grunt kills it, the
## manager auto-resets, repeated 10 times. Headless run:
## <GODOT> --headless --path . res://scenes/phase_b/run_t012_cycles.tscn --fixed-fps 60

const TARGET_RUNS := 10
const MAX_TICKS := 12000

var _manager: EncounterManager
var _combat: PlayerCombat
var _grunt: Grunt
var _player: PlayerController
var _negative: bool = false


func _ready() -> void:
	_negative = OS.get_cmdline_user_args().has("negative")
	var playground := get_node("../PhaseAPlayground")
	_manager = playground.get_node("EncounterManager")
	_combat = playground.get_node("Player/PlayerCombat")
	_grunt = playground.get_node("Grunt")
	_player = playground.get_node("Player")
	_run()


func _run() -> void:
	var ticks := 0
	var last_runs := 0
	var reset_checks_ok := true
	while _manager.runs_completed < TARGET_RUNS and ticks < MAX_TICKS:
		await get_tree().physics_frame
		ticks += 1
		if _manager.runs_completed != last_runs:
			last_runs = _manager.runs_completed
			if _negative and last_runs == 1:
				_combat.health.hp = 0
			var hp_ok := _combat.hp() == _combat.health.max_hp and not _combat.is_dead()
			var pos_ok := _player.global_position.distance_to(Vector3.ZERO) < 0.1
			var grunt_ok := _grunt.hp() == _grunt.health.max_hp
			if not (hp_ok and pos_ok and grunt_ok):
				reset_checks_ok = false
	var completed := _manager.runs_completed >= TARGET_RUNS
	var losses_ok := _manager.losses >= TARGET_RUNS
	print("runs=%d wins=%d losses=%d reset_checks=%s ticks=%d" % [
		_manager.runs_completed, _manager.wins, _manager.losses,
		str(reset_checks_ok), ticks,
	])
	if completed and losses_ok and reset_checks_ok and ticks < MAX_TICKS:
		print("PASS t012_cycles: %d runs" % TARGET_RUNS)
		get_tree().quit(0)
	else:
		print("FAIL t012_cycles")
		get_tree().quit(1)
