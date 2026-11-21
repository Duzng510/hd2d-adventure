class_name WaveKernel
extends RefCounted

## Pure Phase C wave flow: wave advance only when all enemies are dead,
## pause between waves, WON only when the final wave (boss) is cleared.
## Time unit = physics frame @ 60 tick/s.

enum State { INACTIVE, FIGHTING, PAUSED, BUFF_PENDING, WON, LOST }

var wave_sizes: Array[int] = []
var pause_frames: int = 0
var state: State = State.INACTIVE
var wave_index: int = 0
var pause_remaining: int = 0
var wave_start_pending: bool = false
## Scene-level opt-in (T-030): when true, clearing a non-final wave parks the
## flow in BUFF_PENDING until resolve_pick() instead of auto-advancing. Kept
## out of reset() so the opt-in survives a run reset.
var buff_pick_enabled: bool = false


func _init(p_wave_sizes: Array[int], p_pause_frames: int) -> void:
	wave_sizes = p_wave_sizes.duplicate()
	pause_frames = maxi(p_pause_frames, 0)


func start() -> void:
	state = State.FIGHTING
	wave_index = 0
	pause_remaining = 0
	wave_start_pending = true


func tick(alive_count: int) -> void:
	match state:
		State.FIGHTING:
			if alive_count <= 0:
				if wave_index >= wave_sizes.size() - 1:
					state = State.WON
				elif buff_pick_enabled:
					state = State.BUFF_PENDING
				else:
					state = State.PAUSED
					pause_remaining = pause_frames
		State.PAUSED:
			pause_remaining -= 1
			if pause_remaining <= 0:
				wave_index += 1
				state = State.FIGHTING
				wave_start_pending = true
		State.BUFF_PENDING:
			# The flow stands still until the pick resolves (T-030).
			pass


## Called once the buff pick is taken: hand the cleared wave back to the normal
## between-wave pause so the next wave starts through the existing path.
func resolve_pick() -> void:
	if state != State.BUFF_PENDING:
		return
	state = State.PAUSED
	pause_remaining = pause_frames


func player_died() -> void:
	if state == State.FIGHTING or state == State.PAUSED:
		state = State.LOST


func reset() -> void:
	state = State.INACTIVE
	wave_index = 0
	pause_remaining = 0
	wave_start_pending = false


func wave_count() -> int:
	return wave_sizes.size()
