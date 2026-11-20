class_name RewardKernel
extends RefCounted

## Pure Phase C reward flow: boss death opens the gate once, the shrine heals
## once per run, and a reset locks everything again. Time unit is irrelevant —
## every transition is driven by an event from the node.

enum State { LOCKED, GATE_OPEN, HEALED }

var state: State = State.LOCKED


func grant() -> bool:
	if state != State.LOCKED:
		return false
	state = State.GATE_OPEN
	return true


func gate_open() -> bool:
	return state != State.LOCKED


func try_heal(current_hp: int, max_hp: int) -> int:
	if state != State.GATE_OPEN:
		return 0
	var missing := max_hp - current_hp
	if missing <= 0:
		return 0
	state = State.HEALED
	return missing


func reset() -> void:
	state = State.LOCKED
