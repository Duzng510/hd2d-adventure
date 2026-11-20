extends Node

## T-023 E1.2/E1.3/E1.4: every enemy role telegraphs for its full tuned window
## and lands exactly one hit per swing. Measured on a controlled stage: the wave
## loop is frozen, one role is spawned at a time, and the pinned player never
## fights back, so every counter delta belongs to the subject. 10 windows/role.
## Headless:
##   <GODOT> --headless --path . res://scenes/phase_c/run_t023_onehit.tscn --fixed-fps 60
## Negative (HitRegistry enforcement off) must exit 1 on E1.3 and E1.4:
##   ... --fixed-fps 60 -- negative

const WINDOWS_PER_ROLE := 10
const MAX_TICKS_PER_PHASE := 400
const PLAYER_ANCHOR := Vector3(0.0, 0.0, 4.5)
## Ranged only: a projectile needs ~50 ticks to cross the standoff, then a
## margin of idle ticks to prove no second hit follows the despawn.
const IMPACT_TICKS := 90
const POST_HIT_TICKS := 20
const ROLES := ["grunt", "swarm", "ranged", "boss"]
## Melee standoffs sit just inside attack_range; boss at 2.0 m keeps SMASH and
## LUNGE both in range so both telegraphs get sampled; ranged at 5.0 m is inside
## the 3.5-7.0 kite band and never has to move.
const STANDOFFS := {
	"grunt": 1.2,
	"swarm": 0.9,
	"ranged": 5.0,
	"boss": 2.0,
}

var _encounter: WaveEncounter
var _combat: PlayerCombat
var _player: PlayerController
var _director: CombatDirector
var _tuning: CombatTuning
var _negative := false
var _checks := 0
var _failures: Array[String] = []
var _blocked_total := 0
var _duplicates_total := 0


func _ready() -> void:
	_negative = OS.get_cmdline_user_args().has("negative")
	var arena := get_node("../GroveArena")
	_encounter = arena.get_node("WaveEncounter")
	_player = arena.get_node("Player")
	_combat = arena.get_node("Player/PlayerCombat")
	_director = arena.get_node("CombatDirector")
	_tuning = _encounter.tuning
	# Freeze only the wave-loop node: children spawned under it keep ticking.
	# The wave-1 enemies the arena already spawned must go, otherwise they
	# pollute every hit/damage delta this stage measures.
	_encounter.set_physics_process(false)
	_encounter.debug_clear_enemies()
	_player.global_position = PLAYER_ANCHOR
	_player.velocity = Vector3.ZERO
	_run()


func _run() -> void:
	for role in ROLES:
		# Drop the previous subject: a live enemy left at the anchor keeps
		# swinging, and its hits and hitstops would poison the next role's
		# counters and telegraph deltas.
		_encounter.debug_clear_enemies()
		await _ticks(2)
		var enemy := _encounter.debug_spawn(role, PLAYER_ANCHOR + Vector3(0.0, 0.0, -float(STANDOFFS[role])))
		if enemy == null:
			_check(false, "E1.3 %s spawned (role has no scene mapped)" % role)
			continue
		if _negative:
			enemy.debug_set_registry_enforce(false)
		await _measure_role(role, enemy)
	# E1.4: positive = the registry allowed no repeat yet really did block them.
	_check(_duplicates_total == 0, "E1.4 registry allowed no duplicate hit (duplicates=%d)" % _duplicates_total)
	_check(_blocked_total > 0, "E1.4 registry blocked repeats inside active windows (blocked=%d)" % _blocked_total)
	var ok := _failures.is_empty()
	print("windows=%d checks=%d failures=%d blocked=%d duplicates=%d" % [
		WINDOWS_PER_ROLE * ROLES.size(), _checks, _failures.size(), _blocked_total, _duplicates_total,
	])
	for failure in _failures:
		print("ASSERT FAIL: %s" % failure)
	print("PASS t023_onehit" if ok else "FAIL t023_onehit")
	get_tree().quit(0 if ok else 1)


func _measure_role(role: String, enemy: Grunt) -> void:
	for window in WINDOWS_PER_ROLE:
		# Re-pin the anchor every window: a boss LUNGE or a chase drift moves
		# the subject, and the standoff only holds while the player stays put.
		_player.global_position = PLAYER_ANCHOR
		_player.velocity = Vector3.ZERO
		if not await _observe_window(role, enemy, window):
			return


func _observe_window(role: String, enemy: Grunt, window: int) -> bool:
	if not await _wait_for_state(enemy, GruntAI.State.TELEGRAPH):
		_check(false, "E1.2 %s window %d reached TELEGRAPH (%s)" % [role, window, _stall_reason(enemy)])
		return false
	var attack_id := enemy.current_attack_id()
	var entity := enemy.log_entity()
	# A projectile writes its own hit/damage rows, not the shooter's.
	var hit_entity := &"projectile" if role == "ranged" else entity
	var kind := (enemy as Boss).attack_kind() if enemy is Boss else -1
	_combat.health.hp = _combat.health.max_hp
	var blocked_before := enemy.blocked_repeat_count()
	var duplicates_before := enemy.duplicate_hit_count()
	if not await _wait_for_state(enemy, GruntAI.State.ACTIVE):
		_check(false, "E1.2 %s attack %d reached ACTIVE (%s)" % [role, attack_id, _stall_reason(enemy)])
		return false
	# The window is read from the frames the log itself carries, exactly how E1.2
	# defines it, so noticing a transition a tick late cannot bias the number.
	# Hitstop ticks are subtracted: a frozen tick advances the clock but lets no
	# fighter process, and the GDD counts a wind-up in processed frames. A ranged
	# shot from the previous window lands inside this one's telegraph, so the raw
	# gap alone would over-report the wind-up.
	var telegraph := _director.attack_event_frame(entity, attack_id, &"telegraph_start")
	var active := _director.attack_event_frame(entity, attack_id, &"active_start")
	var frozen := _director.attack_event_frozen(entity, attack_id, &"active_start") \
		- _director.attack_event_frozen(entity, attack_id, &"telegraph_start")
	var delta := (active - telegraph) - frozen
	var expected := _telegraph_frames(role, kind)
	_check(delta == expected, "E1.2 %s attack %d telegraph %d == tuned %d (raw=%d hitstop=%d)" % [
		role, attack_id, delta, expected, active - telegraph, frozen,
	])
	_check(delta >= 18, "E1.2 %s attack %d telegraph %d >= 18 floor" % [role, attack_id, delta])
	if role == "ranged":
		var tick := 0
		while _director.attack_event_count(hit_entity, attack_id, &"projectile_hit") == 0 and tick < IMPACT_TICKS:
			await get_tree().physics_frame
			tick += 1
	else:
		if not await _wait_for_state(enemy, GruntAI.State.RECOVERY):
			_check(false, "E1.3 %s attack %d reached RECOVERY (%s)" % [role, attack_id, _stall_reason(enemy)])
			return false
	# Idle margin: a second hit from the same swing would land here.
	for _i in POST_HIT_TICKS:
		await get_tree().physics_frame
	var hits := _director.attack_event_count(hit_entity, attack_id, &"hit") \
		+ _director.attack_event_count(hit_entity, attack_id, &"projectile_hit")
	var expected_damage := _damage_for(role, kind)
	var damage := _director.attack_event_value(hit_entity, attack_id, &"damage")
	_check(hits == 1, "E1.3 %s attack %d logged exactly 1 hit (hits=%d)" % [role, attack_id, hits])
	_check(damage == expected_damage, "E1.3 %s attack %d logged damage %d == tuned %d" % [
		role, attack_id, damage, expected_damage,
	])
	_blocked_total += enemy.blocked_repeat_count() - blocked_before
	_duplicates_total += enemy.duplicate_hit_count() - duplicates_before
	return true


func _wait_for_state(enemy: Grunt, wanted: GruntAI.State) -> bool:
	for _tick in MAX_TICKS_PER_PHASE:
		if enemy.ai_state() == wanted:
			return true
		if enemy.hp() <= 0:
			return false
		await get_tree().physics_frame
	return enemy.ai_state() == wanted


func _stall_reason(enemy: Grunt) -> String:
	return "subject dead" if enemy.hp() <= 0 else "timeout %d ticks" % MAX_TICKS_PER_PHASE


func _telegraph_frames(role: String, kind: int) -> int:
	match role:
		"grunt":
			return _tuning.grunt_telegraph_frames
		"swarm":
			return _tuning.swarm_telegraph_frames
		"ranged":
			return _tuning.ranged_telegraph_frames
		_:
			match kind:
				BossAI.Attack.LUNGE:
					return _tuning.boss_lunge_telegraph_frames
				BossAI.Attack.SWEEP:
					return _tuning.boss_sweep_telegraph_frames
				_:
					return _tuning.boss_smash_telegraph_frames


func _damage_for(role: String, kind: int) -> int:
	match role:
		"grunt":
			return _tuning.grunt_damage
		"swarm":
			return _tuning.swarm_damage
		"ranged":
			return _tuning.ranged_damage
		_:
			match kind:
				BossAI.Attack.LUNGE:
					return _tuning.boss_lunge_damage
				BossAI.Attack.SWEEP:
					return _tuning.boss_sweep_damage
				_:
					return _tuning.boss_smash_damage


func _ticks(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame


func _count(event_name: StringName) -> int:
	return int(_director.event_counts.get(String(event_name), 0))


func _check(condition: bool, label: String) -> void:
	_checks += 1
	print("CHECK %s %s" % ["PASS" if condition else "FAIL", label])
	if not condition:
		_failures.append(label)
