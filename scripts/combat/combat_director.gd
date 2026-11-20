class_name CombatDirector
extends Node3D

## Central sim clock, hitstop ownership and combat log for the encounter.

@export var log_path: String = "user://combat_log.csv"

## Emitted for every logged combat event. Read-only tap for the L4 probe
## (T-025); nothing in gameplay listens to it, so it cannot change behaviour.
signal event_logged(entity: StringName, event_name: StringName, attack_id: int, target_id: int, value: int)

var sim_frame: int = 0
var frozen_tick: bool = false
## Hitstop ticks seen so far: a frozen tick advances the clock but no fighter
## processes, so evidence harnesses subtract it from a raw frame gap.
var frozen_ticks: int = 0
var hitstop := HitstopController.new()
var log := CombatLog.new()
var event_counts: Dictionary = {}
## "entity:attack_id" -> event name -> {count, value, frame}. Evidence harnesses
## read a swing's windows and hits from the log itself, so their polling order
## cannot distort the measurement. Entity is part of the key because every enemy
## numbers its own swings from one.
var attack_records: Dictionary = {}


func _ready() -> void:
	process_priority = -20
	log.open(log_path)


func _physics_process(_delta: float) -> void:
	sim_frame += 1
	frozen_tick = hitstop.tick()
	if frozen_tick:
		frozen_ticks += 1


func request_hitstop(frames: int) -> void:
	hitstop.request(frames)


func log_event(entity: StringName, event_name: StringName, attack_id: int = 0, target_id: int = 0, value: int = 0) -> void:
	var key := String(event_name)
	event_counts[key] = int(event_counts.get(key, 0)) + 1
	var record: Dictionary = attack_records.get("%s:%d" % [entity, attack_id], {})
	var entry: Dictionary = record.get(key, {"count": 0, "value": 0, "frame": -1, "frozen": 0})
	entry["count"] = int(entry["count"]) + 1
	entry["value"] = int(entry["value"]) + value
	entry["frame"] = sim_frame
	entry["frozen"] = frozen_ticks
	record[key] = entry
	attack_records["%s:%d" % [entity, attack_id]] = record
	log.event(sim_frame, entity, event_name, attack_id, target_id, value)
	event_logged.emit(entity, event_name, attack_id, target_id, value)


func attack_event_count(entity: StringName, attack_id: int, event_name: StringName) -> int:
	return int(_attack_entry(entity, attack_id, event_name).get("count", 0))


func attack_event_value(entity: StringName, attack_id: int, event_name: StringName) -> int:
	return int(_attack_entry(entity, attack_id, event_name).get("value", 0))


func attack_event_frame(entity: StringName, attack_id: int, event_name: StringName) -> int:
	return int(_attack_entry(entity, attack_id, event_name).get("frame", -1))


func attack_event_frozen(entity: StringName, attack_id: int, event_name: StringName) -> int:
	return int(_attack_entry(entity, attack_id, event_name).get("frozen", 0))


func _attack_entry(entity: StringName, attack_id: int, event_name: StringName) -> Dictionary:
	var record: Dictionary = attack_records.get("%s:%d" % [entity, attack_id], {})
	return record.get(String(event_name), {})


func reset() -> void:
	hitstop.reset()
	frozen_tick = false
