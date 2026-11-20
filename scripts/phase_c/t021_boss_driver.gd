extends Node

## T-021 boss evidence: attack bands, telegraph lengths, one-shot phase flip,
## one hit per swing with matching damage. Headless:
##   <GODOT> --headless --path . res://scenes/phase_c/run_t021_boss.tscn --fixed-fps 60
## Negative (phase threshold 0 -> never flips) must exit 1 with an E3.2 assert:
##   ... --fixed-fps 60 -- negative

const BOSS_SCENE := preload("res://scenes/combat/boss.tscn")
const TUNING_PATH := "res://scripts/combat/combat_tuning.tres"
const TARGET_SWINGS := 10

var _arena: Node3D
var _director: CombatDirector
var _combat: PlayerCombat
var _player: PlayerController
var _boss: Boss
var _tuning: CombatTuning
var _negative := false
var _checks: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	_negative = OS.get_cmdline_user_args().has("negative")
	_arena = get_node("../GroveArena")
	_director = _arena.get_node("CombatDirector")
	_combat = _arena.get_node("Player/PlayerCombat")
	_player = _arena.get_node("Player")
	_arena.get_node("WaveEncounter").process_mode = Node.PROCESS_MODE_DISABLED
	_tuning = (load(TUNING_PATH) as CombatTuning).duplicate() as CombatTuning
	if _negative:
		_tuning.boss_phase_hp_percent = 0
	_spawn_boss()
	_run()


func _spawn_boss() -> void:
	_boss = BOSS_SCENE.instantiate() as Boss
	_boss.tuning = _tuning
	_boss.spawn_position = Vector3.ZERO
	_boss.position = Vector3.ZERO
	_boss.name = "T021Boss"
	_arena.add_child(_boss)


func _run() -> void:
	await _phase_smash()
	await _phase_lunge()
	var flipped: bool = await _phase_flip()
	if flipped:
		await _phase_swings()
	var ok := _failures.is_empty()
	print("checks=%d failures=%d" % [_checks, _failures.size()])
	for failure in _failures:
		print("ASSERT FAIL: %s" % failure)
	print("PASS t021_boss" if ok else "FAIL t021_boss")
	get_tree().quit(0 if ok else 1)


func _phase_smash() -> void:
	_reset_boss(Vector3.ZERO)
	_set_player(Vector3(0.0, 0.0, 1.5))
	var hits_before := _count(&"hit")
	var hp_before := _combat.hp()
	var kind := -1
	var telegraph_frame := -1
	var active_frame := -1
	var tick := 0
	while tick < 200 and active_frame < 0:
		await get_tree().physics_frame
		tick += 1
		if telegraph_frame < 0 and _boss.ai_state() == GruntAI.State.TELEGRAPH:
			telegraph_frame = _director.sim_frame
			kind = _boss.attack_kind()
		if telegraph_frame >= 0 and _boss.ai_state() == GruntAI.State.ACTIVE:
			active_frame = _director.sim_frame
	_check(kind == BossAI.Attack.SMASH, "E3.1 smash band picks SMASH (kind=%d)" % kind)
	var delta := active_frame - telegraph_frame
	_check(active_frame >= 0 and delta == _tuning.boss_smash_telegraph_frames, "E3.1 smash telegraph 30 before active (delta=%d)" % delta)
	_check(delta >= 18, "E3.3 smash telegraph >= 18 floor")
	await _wait_count(&"hit", hits_before + 1, 90)
	var hits := _count(&"hit") - hits_before
	_check(hits == 1, "E3.4 smash lands exactly one hit (hits=%d)" % hits)
	_check(hp_before - _combat.hp() == _tuning.boss_smash_damage, "E3 smash damage 20 (loss=%d)" % (hp_before - _combat.hp()))


func _phase_lunge() -> void:
	_reset_boss(Vector3(-6.0, 0.0, 1.0))
	_set_player(Vector3(-2.5, 0.0, 1.0))
	var hits_before := _count(&"hit")
	var hp_before := _combat.hp()
	var kind := -1
	var telegraph_frame := -1
	var active_frame := -1
	var tick := 0
	while tick < 200 and active_frame < 0:
		await get_tree().physics_frame
		tick += 1
		if telegraph_frame < 0 and _boss.ai_state() == GruntAI.State.TELEGRAPH:
			telegraph_frame = _director.sim_frame
			kind = _boss.attack_kind()
		if telegraph_frame >= 0 and _boss.ai_state() == GruntAI.State.ACTIVE:
			active_frame = _director.sim_frame
	_check(kind == BossAI.Attack.LUNGE, "E3.1 lunge band picks LUNGE (kind=%d)" % kind)
	var delta := active_frame - telegraph_frame
	_check(active_frame >= 0 and delta == _tuning.boss_lunge_telegraph_frames, "E3.1 lunge telegraph 24 before active (delta=%d)" % delta)
	_check(delta >= 18, "E3.3 lunge telegraph >= 18 floor")
	var dash_from := _boss.global_position
	await _wait_state(GruntAI.State.RECOVERY, 60)
	var travelled := dash_from.distance_to(_boss.global_position)
	_check(travelled >= 4.0, "E3.1 lunge dash travels its track (travelled=%.2f m)" % travelled)
	var hits := _count(&"hit") - hits_before
	_check(hits == 1, "E3.4 lunge lands exactly one hit (hits=%d)" % hits)
	_check(hp_before - _combat.hp() == _tuning.boss_lunge_damage, "E3 lunge damage 12 (loss=%d)" % (hp_before - _combat.hp()))


func _phase_flip() -> bool:
	_reset_boss(Vector3.ZERO)
	_set_player(Vector3(0.0, 0.0, 1.5))
	var flips_before := _count(&"boss_phase")
	await _wait_state(GruntAI.State.TELEGRAPH, 60)
	var kind_before_damage := _boss.attack_kind()
	_boss.apply_hit(150)
	_check(_boss.attack_kind() == kind_before_damage, "E3.2 switch does not cancel the live telegraph")
	var switch_frame := -1
	var switch_active_frame := -1
	var tick := 0
	while tick < 400 and _count(&"boss_phase") == flips_before:
		await get_tree().physics_frame
		tick += 1
		if _boss.ai_state() == GruntAI.State.TELEGRAPH and _boss.attack_kind() == BossAI.Attack.SWITCH:
			if switch_frame < 0:
				switch_frame = _director.sim_frame
		if switch_frame >= 0 and _boss.ai_state() == GruntAI.State.ACTIVE:
			switch_active_frame = _director.sim_frame
			_combat.health.hp = _combat.health.max_hp
			break
	if switch_frame < 0:
		_check(false, "E3.2 SWITCH telegraph observed (threshold=%d percent)" % _tuning.boss_phase_hp_percent)
		return false
	var delta := switch_active_frame - switch_frame
	_check(delta == _tuning.boss_phase_switch_frames, "E3.2 switch telegraph 45 before active (delta=%d)" % delta)
	_check(delta >= 18, "E3.3 switch telegraph >= 18 floor")
	var hp_at_switch := _combat.hp()
	await _wait_count(&"boss_phase", flips_before + 1, 200)
	var flips := _count(&"boss_phase") - flips_before
	_check(flips == 1, "E3.2 boss_phase logged exactly once (flips=%d)" % flips)
	_check(_combat.hp() == hp_at_switch, "E3.2 switch deals no damage")
	_check(_boss.phase_number() == 2, "E3.2 phase 2 after switch")
	_boss.apply_hit(40)
	await _ticks(300)
	_check(_count(&"boss_phase") == flips_before + 1, "E3.2 phase flip never repeats")
	return true


func _phase_swings() -> void:
	_boss.health.hp = _boss.health.max_hp
	_boss.global_position = Vector3.ZERO
	_set_player(Vector3(0.0, 0.0, 2.0))
	var window_id := -1
	var window_kind := -1
	var window_hits := 0
	var window_hp := 0
	var pinned := false
	var kinds: Array[int] = []
	var swings := 0
	var tick := 0
	while swings < TARGET_SWINGS and tick < 4000:
		await get_tree().physics_frame
		tick += 1
		var state := _boss.ai_state()
		# Re-pin during recovery so the next attack is selected from a fixed 2 m
		# distance; pinning later would lock the dash at the drifted position.
		if state == GruntAI.State.RECOVERY and not pinned:
			_boss.global_position = Vector3.ZERO
			pinned = true
		var id := _boss.current_attack_id()
		if id != window_id and state == GruntAI.State.TELEGRAPH:
			pinned = false
			if window_id >= 0:
				var hits := _count(&"hit") - window_hits
				var loss := window_hp - _combat.hp()
				var expected := _expected_damage(window_kind)
				_check(hits == 1, "E3.4 one hit per swing (attack %d kind %d hits %d)" % [window_id, window_kind, hits])
				_check(loss == expected, "E3 swing damage matches attack (kind=%d loss=%d expected=%d)" % [window_kind, loss, expected])
				swings += 1
			window_id = id
			window_kind = _boss.attack_kind()
			kinds.append(window_kind)
			window_hits = _count(&"hit")
			_combat.health.hp = _combat.health.max_hp
			window_hp = _combat.hp()
	_check(swings == TARGET_SWINGS, "E3.4 ten boss swings observed (swings=%d ticks=%d)" % [swings, tick])
	_check(kinds.has(BossAI.Attack.SWEEP), "E3.1 sweep used in phase 2")
	_check(not kinds.has(BossAI.Attack.SWITCH), "E3.2 no further switch in phase 2")


func _expected_damage(kind: int) -> int:
	match kind:
		BossAI.Attack.LUNGE:
			return _tuning.boss_lunge_damage
		BossAI.Attack.SWEEP:
			return _tuning.boss_sweep_damage
		BossAI.Attack.SMASH:
			return _tuning.boss_smash_damage
		_:
			return 0


func _reset_boss(at: Vector3) -> void:
	_boss.set_physics_process(true)
	_boss.reset()
	_boss.global_position = at
	_combat.health.reset()


func _set_player(at: Vector3) -> void:
	_player.global_position = at
	_player.velocity = Vector3.ZERO


func _wait_state(want: GruntAI.State, budget: int) -> int:
	var ticks := 0
	while ticks < budget and _boss.ai_state() != want:
		await get_tree().physics_frame
		ticks += 1
	return ticks


func _wait_count(event_name: StringName, target: int, budget: int) -> int:
	var ticks := 0
	while ticks < budget and _count(event_name) < target:
		await get_tree().physics_frame
		ticks += 1
	return ticks


func _ticks(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _count(event_name: StringName) -> int:
	return int(_director.event_counts.get(String(event_name), 0))


func _check(condition: bool, label: String) -> void:
	_checks += 1
	print("CHECK %s %s" % ["PASS" if condition else "FAIL", label])
	if not condition:
		_failures.append(label)
