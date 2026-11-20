class_name BossAI
extends GruntAI

## Grove Warden: three attacks picked by range band with a rotation cursor, plus a
## one-shot phase switch modelled as its own attack instance (SWITCH, no damage).
## Reuses GruntAI.State and the frame convention: frame 1 on entry, leave when frame > limit.

enum Attack { SMASH, LUNGE, SWEEP, SWITCH }

var tuning: CombatTuning
var attack: int = Attack.SMASH
var phase: int = 1
var phase_flip_pending: bool = false

var _cursor: int = 0
var _switch_requested: bool = false


func _init(p_tuning: CombatTuning) -> void:
	super(p_tuning.boss_detect_range, 0.0, 1, 1, 1)
	tuning = p_tuning


func tick(player_pos: Vector3, self_pos: Vector3) -> void:
	var to_player := player_pos - self_pos
	to_player.y = 0.0
	distance = to_player.length()
	var dir := to_player.normalized() if distance > 0.0001 else Vector3.ZERO
	match state:
		State.IDLE:
			move_dir = Vector3.ZERO
			if distance <= detect_range:
				alert_pending = true
				_enter(State.CHASE)
		State.CHASE:
			if _switch_requested:
				_start_attack(Attack.SWITCH, dir)
			else:
				var next := _pick_attack()
				if next >= 0:
					_start_attack(next, dir)
				else:
					move_dir = dir
					frame += 1
		State.TELEGRAPH:
			move_dir = Vector3.ZERO
			frame += 1
			if frame > _telegraph_limit():
				_enter(State.ACTIVE)
				if attack == Attack.LUNGE:
					move_dir = attack_dir
		State.ACTIVE:
			move_dir = attack_dir if attack == Attack.LUNGE else Vector3.ZERO
			frame += 1
			if frame > _active_limit():
				_enter(State.RECOVERY)
		State.RECOVERY:
			move_dir = Vector3.ZERO
			frame += 1
			if frame > _recovery_limit():
				if attack == Attack.SWITCH:
					phase = 2
					phase_flip_pending = true
				_enter(State.CHASE)


func report_damage(hp: int, max_hp: int) -> void:
	if not _switch_requested and _phase_switch_due(hp, max_hp):
		_switch_requested = true


func reset() -> void:
	super()
	attack = Attack.SMASH
	phase = 1
	phase_flip_pending = false
	_switch_requested = false
	_cursor = 0


## Overridable gate; the negative-control subclass ignores HP and phase.
func _phase_switch_due(hp: int, max_hp: int) -> bool:
	return phase == 1 and max_hp > 0 and hp * 100 <= tuning.boss_phase_hp_percent * max_hp


func _pick_attack() -> int:
	var options: Array[int] = []
	if distance <= tuning.boss_smash_radius:
		options.append(Attack.SMASH)
	if distance <= tuning.boss_lunge_range:
		options.append(Attack.LUNGE)
	if phase >= 2 and distance <= tuning.boss_sweep_radius:
		options.append(Attack.SWEEP)
	if options.is_empty():
		return -1
	var chosen: int = options[_cursor % options.size()]
	_cursor += 1
	return chosen


func _start_attack(kind: int, dir: Vector3) -> void:
	attack = kind
	attack_dir = dir
	move_dir = Vector3.ZERO
	if kind == Attack.SWITCH:
		_switch_requested = false
	_enter(State.TELEGRAPH)


func _telegraph_limit() -> int:
	match attack:
		Attack.SMASH:
			return tuning.boss_smash_telegraph_frames
		Attack.LUNGE:
			return tuning.boss_lunge_telegraph_frames
		Attack.SWEEP:
			return tuning.boss_sweep_telegraph_frames
		_:
			return tuning.boss_phase_switch_frames


func _active_limit() -> int:
	match attack:
		Attack.SMASH:
			return tuning.boss_smash_active_frames
		Attack.LUNGE:
			return tuning.boss_lunge_active_frames
		Attack.SWEEP:
			return tuning.boss_sweep_active_frames
		_:
			return 1


func _recovery_limit() -> int:
	match attack:
		Attack.SMASH:
			return tuning.boss_smash_phase2_recovery_frames if phase == 2 else tuning.boss_smash_recovery_frames
		Attack.LUNGE:
			return tuning.boss_lunge_phase2_recovery_frames if phase == 2 else tuning.boss_lunge_recovery_frames
		Attack.SWEEP:
			return tuning.boss_sweep_recovery_frames
		_:
			return 1
