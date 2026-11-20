extends SceneTree

## Swarm tuning envelope + grunt regression. Run:
##   <GODOT> --headless --path . -s res://tests/test_swarm_tuning.gd
## Negative (swarm telegraph below GDD floor) must exit 1:
##   <GODOT> --headless --path . -s res://tests/test_swarm_tuning.gd -- negative

const TUNING_PATH := "res://scripts/combat/combat_tuning.tres"

var _checks: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	var negative := OS.get_cmdline_user_args().has("negative")
	var tuning := load(TUNING_PATH) as CombatTuning
	if tuning == null:
		print("FAIL test_swarm_tuning: cannot load tuning")
		quit(1)
		return
	tuning = tuning.duplicate() as CombatTuning
	if negative:
		tuning.swarm_telegraph_frames = 10
	_check(tuning.swarm_max_hp == 20, "swarm hp 20")
	_check(tuning.swarm_telegraph_frames >= 18, "swarm telegraph >= 18 (GDD floor)")
	_check(tuning.swarm_active_frames == 4, "swarm active 4")
	_check(tuning.swarm_recovery_frames == 20, "swarm recovery 20")
	_check(tuning.swarm_damage == 5, "swarm damage 5")
	_check(absf(tuning.swarm_approach_speed - 3.125) < 0.0001, "swarm approach speed 3.125 (1.25x grunt)")
	_check(absf(tuning.swarm_attack_range - 1.0) < 0.0001, "swarm attack range 1.0")
	_check(absf(tuning.swarm_detect_range - 6.0) < 0.0001, "swarm detect range 6.0")
	_check(tuning.grunt_max_hp == 30 and tuning.grunt_damage == 15, "grunt regression hp/damage")
	_check(tuning.grunt_telegraph_frames == 20, "grunt regression telegraph")
	_check(absf(tuning.grunt_approach_speed - 2.5) < 0.0001, "grunt regression approach 2.5")
	var swarm_node := Swarm.new()
	swarm_node.tuning = tuning
	_check(swarm_node._max_hp() == 20, "swarm node reads swarm hp")
	_check(swarm_node._telegraph_frames() == tuning.swarm_telegraph_frames, "swarm node telegraph follows swarm tuning")
	_check(swarm_node._damage() == 5, "swarm node damage 5")
	_check(swarm_node._log_entity() == &"swarm", "swarm node logs entity swarm")
	swarm_node.free()
	var grunt_node := Grunt.new()
	grunt_node.tuning = tuning
	_check(grunt_node._max_hp() == 30 and grunt_node._log_entity() == &"grunt", "grunt node defaults unchanged")
	grunt_node.free()
	print("checks=%d failures=%d" % [_checks, _failures.size()])
	for failure in _failures:
		print("FAIL: %s" % failure)
	var ok := _failures.is_empty()
	print("PASS test_swarm_tuning" if ok else "FAIL test_swarm_tuning")
	quit(0 if ok else 1)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
