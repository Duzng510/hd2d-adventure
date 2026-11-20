extends SceneTree

## BossAI: attack selection, phase switch, frame convention. Run:
##   <GODOT> --headless --path . -s res://tests/test_boss_ai.gd
## Negative (phase gate ignores HP) must exit 1 on the flip-count assert:
##   <GODOT> --headless --path . -s res://tests/test_boss_ai.gd -- negative

const TUNING_PATH := "res://scripts/combat/combat_tuning.tres"
const CLOSE := Vector3(1.5, 0.0, 0.0)
const MID := Vector3(3.5, 0.0, 0.0)
const BAND := Vector3(2.0, 0.0, 0.0)
const FAR := Vector3(8.0, 0.0, 0.0)

var _tuning: CombatTuning
var _checks: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	var negative := OS.get_cmdline_user_args().has("negative")
	_tuning = (load(TUNING_PATH) as CombatTuning).duplicate() as CombatTuning
	if _tuning == null:
		print("FAIL test_boss_ai: cannot load tuning")
		quit(1)
		return
	_test_smash()
	_test_lunge()
	_test_rotation()
	_test_phase_flip(negative)
	_test_no_candidate()
	_test_reset()
	print("checks=%d failures=%d" % [_checks, _failures.size()])
	for failure in _failures:
		print("FAIL: %s" % failure)
	var ok := _failures.is_empty()
	print("PASS test_boss_ai" if ok else "FAIL test_boss_ai")
	quit(0 if ok else 1)


func _new_ai() -> BossAI:
	return BossAI.new(_tuning.duplicate() as CombatTuning)


func _test_smash() -> void:
	var ai := _new_ai()
	var to_telegraph := _advance(ai, CLOSE, GruntAI.State.TELEGRAPH, 20)
	_check(ai.state == GruntAI.State.TELEGRAPH, "smash band reaches TELEGRAPH")
	_check(ai.attack == BossAI.Attack.SMASH, "first attack at 1.5 m is SMASH")
	_check(ai.alert_pending, "alert event on first detection")
	_check(ai.attack_dir.is_equal_approx(Vector3.RIGHT), "telegraph snapshots aim")
	var to_active := _advance(ai, CLOSE, GruntAI.State.ACTIVE, 60)
	_check(to_active == _tuning.boss_smash_telegraph_frames, "smash telegraph 30 before active")
	_check(to_active >= 18, "smash telegraph >= 18 floor")
	_check(ai.move_dir == Vector3.ZERO, "smash rooted in active")


func _test_lunge() -> void:
	var ai := _new_ai()
	_advance(ai, MID, GruntAI.State.TELEGRAPH, 20)
	_check(ai.attack == BossAI.Attack.LUNGE, "only lunge valid at 3.5 m")
	var to_active := _advance(ai, MID, GruntAI.State.ACTIVE, 60)
	_check(to_active == _tuning.boss_lunge_telegraph_frames, "lunge telegraph 24 before active")
	var to_recovery := _advance(ai, MID, GruntAI.State.RECOVERY, 30)
	_check(to_recovery == _tuning.boss_lunge_active_frames, "lunge active 8 frames")
	var dash := _new_ai()
	_advance(dash, MID, GruntAI.State.ACTIVE, 60)
	var snapshot := dash.attack_dir
	_check(dash.move_dir.is_equal_approx(snapshot), "lunge dashes along snapshot")
	dash.tick(Vector3(0.0, 0.0, 3.5), Vector3.ZERO)
	_check(dash.attack_dir.is_equal_approx(snapshot), "lunge direction locked in")


func _test_rotation() -> void:
	var ai := _new_ai()
	var phase1 := _collect_attacks(ai, CLOSE, 4, 900)
	_check(phase1.size() == 4, "four phase 1 attacks observed")
	if phase1.size() == 4:
		_check(phase1[0] == BossAI.Attack.SMASH, "rotation starts at SMASH")
		_check(phase1[1] == BossAI.Attack.LUNGE, "rotation alternates to LUNGE")
		_check(phase1[2] == BossAI.Attack.SMASH, "rotation cycles SMASH again")
		_check(not phase1.has(BossAI.Attack.SWEEP), "no SWEEP in phase 1")
	var ai2 := _new_ai()
	ai2.tick(BAND, Vector3.ZERO)
	ai2.report_damage(int(_tuning.boss_max_hp * 0.4), _tuning.boss_max_hp)
	var phase2 := _collect_attacks_with_flip(ai2, BAND, 4, 1500)
	_check(phase2.has(BossAI.Attack.SWEEP), "SWEEP available in phase 2")


func _test_phase_flip(negative: bool) -> void:
	var tuning := _tuning.duplicate() as CombatTuning
	var ai: BossAI
	if negative:
		ai = OscillatingBossAI.new(tuning)
	else:
		ai = BossAI.new(tuning)
	ai.tick(BAND, Vector3.ZERO)
	ai.report_damage(150, 300)
	_advance(ai, BAND, GruntAI.State.TELEGRAPH, 60)
	_check(ai.attack == BossAI.Attack.SWITCH, "phase switch attack queued at 50 percent HP")
	var to_active := _advance(ai, BAND, GruntAI.State.ACTIVE, 80)
	_check(to_active == _tuning.boss_phase_switch_frames, "switch telegraph 45 frames")
	_check(ai.phase == 1, "phase stays 1 during switch")
	var flips := _drain_flips(ai, BAND, 200)
	_check(flips == 1, "boss_phase flips once")
	_check(ai.phase == 2, "phase 2 after switch")
	ai.report_damage(60, 300)
	var extra := _drain_flips(ai, BAND, 400)
	_check(extra + flips == 1, "phase flip fires exactly once")


func _test_no_candidate() -> void:
	var ai := _new_ai()
	ai.tick(FAR, Vector3.ZERO)
	_check(ai.state == GruntAI.State.CHASE, "alert within detect range at 8 m")
	for i in 120:
		ai.tick(FAR, Vector3.ZERO)
	_check(ai.state == GruntAI.State.CHASE, "no attack out of every band at 8 m")
	_check(ai.move_dir.is_equal_approx(Vector3.RIGHT), "advances toward player")


func _test_reset() -> void:
	var ai := _new_ai()
	_collect_attacks(ai, CLOSE, 2, 600)
	ai.reset()
	_check(ai.state == GruntAI.State.IDLE, "reset -> IDLE")
	_check(ai.phase == 1, "reset -> phase 1")
	var kinds := _collect_attacks(ai, CLOSE, 1, 300)
	_check(kinds.size() == 1 and kinds[0] == BossAI.Attack.SMASH, "reset rewinds rotation")


func _advance(ai: BossAI, player: Vector3, want: GruntAI.State, budget: int) -> int:
	var ticks := 0
	while ticks < budget and ai.state != want:
		ai.tick(player, Vector3.ZERO)
		ticks += 1
	return ticks


func _collect_attacks(ai: BossAI, player: Vector3, count: int, budget: int) -> Array[int]:
	var kinds: Array[int] = []
	var previous := ai.state
	var ticks := 0
	while kinds.size() < count and ticks < budget:
		ai.tick(player, Vector3.ZERO)
		ticks += 1
		if ai.state != previous:
			if ai.state == GruntAI.State.TELEGRAPH:
				kinds.append(ai.attack)
			previous = ai.state
	return kinds


func _collect_attacks_with_flip(ai: BossAI, player: Vector3, count: int, budget: int) -> Array[int]:
	var kinds := _drain_attacks(ai, player, 1, budget)
	ai.report_damage(int(_tuning.boss_max_hp * 0.4), _tuning.boss_max_hp)
	kinds.append_array(_drain_attacks(ai, player, count, budget))
	return kinds


func _drain_attacks(ai: BossAI, player: Vector3, count: int, budget: int) -> Array[int]:
	var kinds: Array[int] = []
	var previous := ai.state
	var ticks := 0
	while kinds.size() < count and ticks < budget:
		ai.tick(player, Vector3.ZERO)
		ticks += 1
		if ai.phase_flip_pending:
			ai.phase_flip_pending = false
		if ai.state != previous:
			if ai.state == GruntAI.State.TELEGRAPH and ai.attack != BossAI.Attack.SWITCH:
				kinds.append(ai.attack)
			previous = ai.state
	return kinds


func _drain_flips(ai: BossAI, player: Vector3, budget: int) -> int:
	var flips := 0
	for i in budget:
		ai.tick(player, Vector3.ZERO)
		if ai.phase_flip_pending:
			ai.phase_flip_pending = false
			flips += 1
	return flips


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


class OscillatingBossAI extends BossAI:
	func _phase_switch_due(_hp: int, _max_hp: int) -> bool:
		return true
