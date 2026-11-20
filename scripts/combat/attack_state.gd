class_name AttackState
extends RefCounted

## Frame convention: startup = action_frame 1..S, active = S+1..S+A, recovery = S+A+1..S+A+R.

enum Phase { NONE, STARTUP, ACTIVE, RECOVERY }

var startup_frames: int
var active_frames: int
var recovery_frames: int
var combo_window_frames: int
var max_combo_hits: int

var phase: Phase = Phase.NONE
var action_frame: int = 0
var combo_index: int = 0
var fatigue_frames: int = 0


func _init(p_startup: int, p_active: int, p_recovery: int, p_combo_window: int, p_max_combo: int) -> void:
	startup_frames = maxi(p_startup, 1)
	active_frames = maxi(p_active, 1)
	recovery_frames = maxi(p_recovery, 1)
	combo_window_frames = maxi(p_combo_window, 0)
	max_combo_hits = maxi(p_max_combo, 1)


func start(p_combo_index: int, p_fatigue_frames: int = 0) -> void:
	combo_index = p_combo_index
	fatigue_frames = maxi(p_fatigue_frames, 0)
	action_frame = 1
	_refresh_phase()


func tick() -> void:
	if phase == Phase.NONE:
		return
	action_frame += 1
	_refresh_phase()


func cancel() -> void:
	phase = Phase.NONE
	action_frame = 0
	combo_index = 0
	fatigue_frames = 0


func is_attacking() -> bool:
	return phase != Phase.NONE


func is_active() -> bool:
	return phase == Phase.ACTIVE


func recovery_frame() -> int:
	return action_frame - startup_frames - active_frames


func can_combo() -> bool:
	return (
		phase == Phase.RECOVERY
		and combo_index < max_combo_hits
		and recovery_frame() >= 1
		and recovery_frame() <= combo_window_frames
	)


func _refresh_phase() -> void:
	if action_frame <= startup_frames:
		phase = Phase.STARTUP
	elif action_frame <= startup_frames + active_frames:
		phase = Phase.ACTIVE
	elif action_frame <= startup_frames + active_frames + recovery_frames + fatigue_frames:
		phase = Phase.RECOVERY
	else:
		phase = Phase.NONE
		action_frame = 0
		combo_index = 0
		fatigue_frames = 0
