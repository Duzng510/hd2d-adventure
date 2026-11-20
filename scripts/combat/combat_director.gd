class_name CombatDirector
extends Node3D

## Central sim clock, hitstop ownership and combat log for the encounter.

@export var log_path: String = "user://combat_log.csv"

var sim_frame: int = 0
var frozen_tick: bool = false
var hitstop := HitstopController.new()
var log := CombatLog.new()


func _ready() -> void:
	process_priority = -20
	log.open(log_path)


func _physics_process(_delta: float) -> void:
	sim_frame += 1
	frozen_tick = hitstop.tick()


func request_hitstop(frames: int) -> void:
	hitstop.request(frames)


func log_event(entity: StringName, event_name: StringName, attack_id: int = 0, target_id: int = 0, value: int = 0) -> void:
	log.event(sim_frame, entity, event_name, attack_id, target_id, value)


func reset() -> void:
	hitstop.reset()
	frozen_tick = false
