extends SceneTree

## Ranged tuning envelope. Run:
##   <GODOT> --headless --path . -s res://tests/test_ranged_tuning.gd
## Negative (ranged telegraph below GDD floor) must exit 1:
##   <GODOT> --headless --path . -s res://tests/test_ranged_tuning.gd -- negative

const TUNING_PATH := "res://scripts/combat/combat_tuning.tres"

var _checks: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	var negative := OS.get_cmdline_user_args().has("negative")
	var loaded := load(TUNING_PATH) as CombatTuning
	if loaded == null:
		print("FAIL test_ranged_tuning: cannot load tuning")
		quit(1)
		return
	var tuning := loaded.duplicate() as CombatTuning
	if negative:
		tuning.ranged_telegraph_frames = 10
	_check(tuning.ranged_max_hp == 30, "ranged hp 30")
	_check(tuning.ranged_telegraph_frames == 24, "ranged telegraph 24")
	_check(tuning.ranged_telegraph_frames >= 18, "ranged telegraph >= 18 (GDD floor)")
	_check(tuning.ranged_active_frames == 4, "ranged active 4 (hypothesis)")
	_check(tuning.ranged_recovery_frames == 30, "ranged recovery 30 (hypothesis)")
	_check(tuning.ranged_damage == 8, "ranged damage 8")
	_check(absf(tuning.ranged_min_range - 3.5) < 0.0001, "ranged min range 3.5")
	_check(absf(tuning.ranged_max_range - 7.0) < 0.0001, "ranged max range 7.0")
	_check(absf(tuning.ranged_approach_speed - 2.0) < 0.0001, "ranged approach speed 2.0 (hypothesis)")
	_check(absf(tuning.ranged_projectile_speed - 6.0) < 0.0001, "projectile speed 6.0")
	_check(tuning.ranged_projectile_lifetime_frames > 0 and tuning.ranged_projectile_lifetime_frames <= 120, "projectile lifetime <= 2 s")
	_check(tuning.grunt_max_hp == 30 and tuning.grunt_damage == 15, "grunt regression hp/damage")
	_check(tuning.grunt_telegraph_frames == 20, "grunt regression telegraph")
	_check(tuning.swarm_max_hp == 20 and tuning.swarm_damage == 5, "swarm regression hp/damage")
	_check(tuning.swarm_telegraph_frames == 18, "swarm regression telegraph")
	var ranged_node := Ranged.new()
	ranged_node.tuning = tuning
	_check(ranged_node._max_hp() == 30, "ranged node reads ranged hp")
	_check(absf(ranged_node._detect_range() - 7.0) < 0.0001, "ranged node detect range = max range")
	_check(absf(ranged_node._attack_range() - 3.5) < 0.0001, "ranged node attack range = min range")
	_check(ranged_node._log_entity() == &"ranged", "ranged node logs entity ranged")
	_check(ranged_node._create_ai() is RangedAI, "ranged node builds RangedAI")
	ranged_node.free()
	var grunt_node := Grunt.new()
	grunt_node.tuning = tuning
	_check(grunt_node._max_hp() == 30 and grunt_node._log_entity() == &"grunt", "grunt node defaults unchanged")
	grunt_node.free()
	var encounter := WaveEncounter.new()
	var wave1: Array = encounter.wave_roles[0]
	var wave2: Array = encounter.wave_roles[1]
	_check(wave1.count("grunt") == 2 and wave1.count("swarm") == 3, "wave 1 composition 2 grunt + 3 swarm")
	_check(wave2.count("swarm") == 2 and wave2.count("ranged") == 2, "wave 2 composition 2 swarm + 2 ranged")
	encounter.free()
	print("checks=%d failures=%d" % [_checks, _failures.size()])
	for failure in _failures:
		print("FAIL: %s" % failure)
	var ok := _failures.is_empty()
	print("PASS test_ranged_tuning" if ok else "FAIL test_ranged_tuning")
	quit(0 if ok else 1)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
