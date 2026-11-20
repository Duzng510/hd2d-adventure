class_name GruntAI
extends RefCounted

## Pure Grunt state machine; the node supplies positions and reads move/attack intent.
## Alert is reported as a one-shot event (alert_pending), not a persistent state.

enum State { IDLE, CHASE, TELEGRAPH, ACTIVE, RECOVERY }

var detect_range: float
var attack_range: float
var telegraph_frames: int
var active_frames: int
var recovery_frames: int

var state: State = State.IDLE
var frame: int = 0
var distance: float = INF
var move_dir := Vector3.ZERO
var attack_dir := Vector3.RIGHT
var alert_pending: bool = false


func _init(p_detect: float, p_attack: float, p_telegraph: int, p_active: int, p_recovery: int) -> void:
	detect_range = maxf(p_detect, 0.0)
	attack_range = maxf(p_attack, 0.0)
	telegraph_frames = maxi(p_telegraph, 1)
	active_frames = maxi(p_active, 1)
	recovery_frames = maxi(p_recovery, 1)


func tick(player_pos: Vector3, self_pos: Vector3) -> void:
	var to_player := player_pos - self_pos
	to_player.y = 0.0
	distance = to_player.length()
	move_dir = to_player.normalized() if distance > 0.0001 else Vector3.ZERO
	match state:
		State.IDLE:
			if distance <= detect_range:
				alert_pending = true
				_enter(State.CHASE)
		State.CHASE:
			if distance > detect_range:
				_enter(State.IDLE)
			elif distance <= attack_range:
				attack_dir = move_dir
				_enter(State.TELEGRAPH)
			else:
				frame += 1
		State.TELEGRAPH:
			frame += 1
			if frame > telegraph_frames:
				_enter(State.ACTIVE)
		State.ACTIVE:
			frame += 1
			if frame > active_frames:
				_enter(State.RECOVERY)
		State.RECOVERY:
			frame += 1
			if frame > recovery_frames:
				_enter(State.CHASE)


func reset() -> void:
	state = State.IDLE
	frame = 0
	distance = INF
	alert_pending = false
	move_dir = Vector3.ZERO
	attack_dir = Vector3.RIGHT


func _enter(next_state: State) -> void:
	state = next_state
	frame = 1
