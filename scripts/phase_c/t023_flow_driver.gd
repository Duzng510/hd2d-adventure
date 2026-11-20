extends Node

## T-023 E5.1/E5.2 on the real arena: the next wave only spawns once the
## previous one is wiped (wave_start order + no survivors), and WON is only
## reachable with the boss dead. 3 full runs. Fault injection (`-- negative`)
## lies to the kernel about alive_count to prove both asserts bite.
## Headless:
##   <GODOT> --headless --path . res://scenes/phase_c/run_t023_flow.tscn --fixed-fps 60
## Negative must exit 1 on E5.1 and E5.2:
##   ... --fixed-fps 60 -- negative

const TARGET_RUNS := 3
const MAX_TICKS := 20000
## Same staging trick as t018/t019: chase the nearest enemy so a kiting ranged
## still gets hit; 0.8 m keeps the target inside light_reach (1.4).
const FOLLOW_OFFSET := 0.8

var _encounter: WaveEncounter
var _combat: PlayerCombat
var _player: PlayerController
var _director: CombatDirector
var _negative := false
var _checks := 0
var _failures: Array[String] = []
var _wave_order: Array[int] = []
var _wave_starts_seen := 0
var _last_runs := 0
var _last_state := WaveKernel.State.INACTIVE
var _spawn_early_injected := false
var _win_early_injected := false


func _ready() -> void:
	_negative = OS.get_cmdline_user_args().has("negative")
	var arena := get_node("../GroveArena")
	_encounter = arena.get_node("WaveEncounter")
	_combat = arena.get_node("Player/PlayerCombat")
	_player = arena.get_node("Player")
	_director = arena.get_node("CombatDirector")
	_combat.aim_override_enabled = true
	_run()


func _run() -> void:
	var ticks := 0
	while _encounter.runs_completed < TARGET_RUNS and ticks < MAX_TICKS:
		await get_tree().physics_frame
		ticks += 1
		var kernel := _encounter.kernel
		var state := kernel.state
		if _encounter.runs_completed != _last_runs:
			_last_runs = _encounter.runs_completed
			_wave_order.clear()
		if state != _last_state:
			if state == WaveKernel.State.WON:
				_check_won(kernel)
			elif state == WaveKernel.State.PAUSED and kernel.wave_index < kernel.wave_count() - 1:
				_check(_encounter.alive_count() == 0, "E5.2 wave %d cleared to PAUSED, not WON (alive=%d)" % [
					kernel.wave_index + 1, _encounter.alive_count(),
				])
			_last_state = state
		_observe_wave_start(kernel)
		if _negative:
			_inject_fault(kernel, state)
		if state == WaveKernel.State.WON:
			# T-022 keeps control on a win, so the harness resets for the next run.
			_encounter.reset_run()
			continue
		if state == WaveKernel.State.FIGHTING or state == WaveKernel.State.PAUSED:
			_combat.health.hp = _combat.health.max_hp
			if _encounter.alive_count() > 0:
				var target := _encounter.nearest_alive_position()
				var staging := target + Vector3(FOLLOW_OFFSET if target.x < 0.0 else -FOLLOW_OFFSET, 0.0, 0.0)
				if _player.global_position.distance_to(staging) > 0.4:
					_player.global_position = staging
					_player.velocity = Vector3.ZERO
				_combat.aim_override_point = target
				if _combat.attack_phase() == AttackState.Phase.NONE:
					_combat.debug_request_attack()
	var completed := _encounter.runs_completed >= TARGET_RUNS
	_check(completed, "E5.1 %d runs played inside tick budget (runs=%d ticks=%d)" % [
		TARGET_RUNS, _encounter.runs_completed, ticks,
	])
	var ok := _failures.is_empty()
	print("runs=%d checks=%d failures=%d ticks=%d" % [_encounter.runs_completed, _checks, _failures.size(), ticks])
	for failure in _failures:
		print("ASSERT FAIL: %s" % failure)
	print("PASS t023_flow" if ok else "FAIL t023_flow")
	get_tree().quit(0 if ok else 1)


## E5.1: each wave_start must carry the next index in order, and at that moment
## the arena may only contain the new wave — a survivor pushes alive_count above
## the wave size, which is exactly the early-spawn bug this evidence refuses.
func _observe_wave_start(kernel: WaveKernel) -> void:
	var starts := int(_director.event_counts.get("wave_start", 0))
	if starts == _wave_starts_seen:
		return
	_wave_starts_seen = starts
	_wave_order.append(kernel.wave_index + 1)
	_check(_wave_order.back() == _wave_order.size(), "E5.1 wave_start order %s" % str(_wave_order))
	_check(_encounter.alive_count() == _encounter.wave_size(kernel.wave_index), "E5.1 wave %d spawned after full wipe (alive=%d size=%d)" % [
		kernel.wave_index + 1, _encounter.alive_count(), _encounter.wave_size(kernel.wave_index),
	])


## E5.2: a win is the boss's death, not "the last wave timer ran out".
func _check_won(kernel: WaveKernel) -> void:
	var boss_seen := false
	var boss_alive := false
	for enemy in _encounter.enemies():
		if enemy is Boss:
			boss_seen = true
			if enemy.hp() > 0:
				boss_alive = true
	_check(kernel.wave_index == kernel.wave_count() - 1, "E5.2 WON only on last wave (wave=%d)" % (kernel.wave_index + 1))
	_check(boss_seen and not boss_alive, "E5.2 WON only with boss dead (boss_seen=%s boss_alive=%s)" % [
		str(boss_seen), str(boss_alive),
	])
	_check(_encounter.alive_count() == 0, "E5.2 WON with empty arena (alive=%d)" % _encounter.alive_count())


## Producer-side fault injection: WaveKernel.tick(alive_count) is the very call
## the encounter makes each tick, only here it lies. No production backdoor.
func _inject_fault(kernel: WaveKernel, state: WaveKernel.State) -> void:
	if state != WaveKernel.State.FIGHTING or kernel.wave_start_pending:
		return
	if _encounter.alive_count() == 0:
		return
	if not _spawn_early_injected and kernel.wave_index == 0:
		_spawn_early_injected = true
		kernel.tick(0)
	elif not _win_early_injected and kernel.wave_index == kernel.wave_count() - 1:
		_win_early_injected = true
		kernel.tick(0)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	print("CHECK %s %s" % ["PASS" if condition else "FAIL", label])
	if not condition:
		_failures.append(label)
