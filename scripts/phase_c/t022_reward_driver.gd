extends Node

## T-022 reward evidence: the gate blocks before the win, opens after it, the
## shrine heals once, and R re-locks everything. Headless:
##   <GODOT> --headless --path . res://scenes/phase_c/run_t022_reward.tscn --fixed-fps 60
## Negative (reward hook disconnected) must exit 1 with an E4.2 assert:
##   ... --fixed-fps 60 -- negative

const GATE_BLOCK_Z := -5.6
const PAST_GATE_Z := -6.2
const WIN_TICKS := 1200

var _arena: Node3D
var _encounter: WaveEncounter
var _reward: Reward
var _director: CombatDirector
var _combat: PlayerCombat
var _player: PlayerController
var _negative := false
var _checks: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	_negative = OS.get_cmdline_user_args().has("negative")
	_arena = get_node("../GroveArena")
	_encounter = _arena.get_node("WaveEncounter")
	_reward = _arena.get_node("Reward")
	_director = _arena.get_node("CombatDirector")
	_combat = _arena.get_node("Player/PlayerCombat")
	_player = _arena.get_node("Player")
	if _negative:
		for connection in _encounter.run_ended.get_connections():
			_encounter.run_ended.disconnect(connection.callable)
	_run()


func _run() -> void:
	await _phase_blocks_before_win()
	var won := await _phase_win_and_reward()
	if won:
		await _phase_shrine_heal()
	await _phase_reset_relocks()
	var ok := _failures.is_empty()
	print("checks=%d failures=%d" % [_checks, _failures.size()])
	for failure in _failures:
		print("ASSERT FAIL: %s" % failure)
	print("PASS t022_reward" if ok else "FAIL t022_reward")
	get_tree().quit(0 if ok else 1)


func _phase_blocks_before_win() -> void:
	_encounter.reset_run()
	_combat.health.hp = _combat.health.max_hp
	_set_player(Vector3(0.0, 0.0, -4.5))
	var granted := _count(&"reward_granted")
	Input.action_press(&"move_up")
	var blocked := true
	for i in 120:
		await get_tree().physics_frame
		_combat.health.hp = _combat.health.max_hp
		if _player.global_position.z < GATE_BLOCK_Z:
			blocked = false
	Input.action_release(&"move_up")
	_check(blocked, "E4.1 closed gate blocks movement (z=%.2f)" % _player.global_position.z)
	_check(_count(&"reward_granted") == granted, "E4.1 no reward before win")


func _phase_win_and_reward() -> bool:
	var granted_before := _count(&"reward_granted")
	var runs_before := _encounter.runs_completed
	_kill_wave()
	var ticks := 0
	while ticks < WIN_TICKS and _encounter.kernel.state != WaveKernel.State.WON:
		await get_tree().physics_frame
		ticks += 1
		_combat.health.hp = _combat.health.max_hp
		if _encounter.kernel.state == WaveKernel.State.FIGHTING:
			_kill_wave()
	_check(_encounter.kernel.state == WaveKernel.State.WON, "E4.2 encounter reaches WON (ticks=%d)" % ticks)
	var granted := _count(&"reward_granted") - granted_before
	_check(granted == 1, "E4.2 reward_granted logged once (granted=%d)" % granted)
	if granted != 1:
		return false
	for i in 200:
		await get_tree().physics_frame
	_check(_encounter.runs_completed == runs_before, "E4.2 win keeps control, no auto-reset")
	return true


func _phase_shrine_heal() -> void:
	_set_player(Vector3(0.0, 0.0, -4.5))
	Input.action_press(&"move_up")
	var passed := false
	for i in 150:
		await get_tree().physics_frame
		if _player.global_position.z < PAST_GATE_Z:
			passed = true
			break
	Input.action_release(&"move_up")
	_check(passed, "E4.2 gate opens after reward (z=%.2f)" % _player.global_position.z)
	_combat.health.apply_damage(60)
	_set_player(_reward.shrine_position)
	var heals := _count(&"heal")
	var healed := false
	for i in 60:
		await get_tree().physics_frame
		if _combat.hp() == _combat.health.max_hp:
			healed = true
			break
	_check(healed, "E4.2 shrine heals to full (hp=%d)" % _combat.hp())
	_check(_count(&"heal") == heals + 1, "E4.2 heal logged once (delta=%d)" % (_count(&"heal") - heals))
	_combat.health.apply_damage(30)
	for i in 60:
		await get_tree().physics_frame
	_check(_combat.hp() == _combat.health.max_hp - 30, "E4.2 shrine heals only once per run (hp=%d)" % _combat.hp())


func _phase_reset_relocks() -> void:
	var granted_before := _count(&"reward_granted")
	_encounter.reset_run()
	_check(not _reward.kernel.gate_open(), "E4.3 gate locked after reset")
	_check(_combat.hp() == _combat.health.max_hp, "E4.3 HP full after reset")
	_check(_count(&"reward_granted") == granted_before, "E4.3 reset grants no new reward")
	_set_player(Vector3(0.0, 0.0, -4.5))
	Input.action_press(&"move_up")
	var blocked := true
	for i in 90:
		await get_tree().physics_frame
		_combat.health.hp = _combat.health.max_hp
		if _player.global_position.z < GATE_BLOCK_Z:
			blocked = false
	Input.action_release(&"move_up")
	_check(blocked, "E4.3 reset gate blocks again (z=%.2f)" % _player.global_position.z)
	_combat.health.apply_damage(50)
	_set_player(_reward.shrine_position)
	for i in 60:
		await get_tree().physics_frame
	_check(_combat.hp() == _combat.health.max_hp - 50, "E4.3 locked shrine does not heal (hp=%d)" % _combat.hp())


func _kill_wave() -> void:
	for enemy in _encounter.enemies():
		if enemy.hp() > 0:
			enemy.apply_hit(9999)


func _set_player(at: Vector3) -> void:
	_player.global_position = at
	_player.velocity = Vector3.ZERO


func _count(event_name: StringName) -> int:
	return int(_director.event_counts.get(String(event_name), 0))


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
