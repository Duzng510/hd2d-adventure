class_name EncounterManager
extends Node

## Single Grunt encounter: win/lose detection, auto-reset and manual R reset.

enum State { FIGHTING, WON, LOST }

@export var player_path: NodePath = NodePath("../Player")
@export var grunt_path: NodePath = NodePath("../Grunt")
@export var director_path: NodePath = NodePath("../CombatDirector")
@export var spawn_position := Vector3.ZERO
@export var reset_delay_frames: int = 120

var state: State = State.FIGHTING
var runs_completed: int = 0
var wins: int = 0
var losses: int = 0

var _player: PlayerController
var _combat: PlayerCombat
var _grunt: Grunt
var _director: CombatDirector
var _end_frame: int = -1


func _ready() -> void:
	process_priority = -5
	_player = get_node(player_path)
	_combat = _player.get_node("PlayerCombat")
	_grunt = get_node(grunt_path)
	_director = get_node(director_path)


func encounter_state() -> State:
	return state


func _physics_process(_delta: float) -> void:
	if _director.frozen_tick:
		return
	match state:
		State.FIGHTING:
			if _grunt.hp() <= 0:
				_end_run(State.WON)
			elif _combat.is_dead():
				_end_run(State.LOST)
		State.WON, State.LOST:
			if _end_frame >= 0 and _director.sim_frame - _end_frame >= reset_delay_frames:
				reset_encounter()


func reset_encounter() -> void:
	_player.global_position = spawn_position
	_player.velocity = Vector3.ZERO
	_player.facing = 1
	_combat.reset()
	_grunt.reset()
	_director.reset()
	state = State.FIGHTING
	_end_frame = -1
	runs_completed += 1
	_director.log_event(&"encounter", &"encounter_reset", 0, 0, runs_completed)


func _end_run(next_state: State) -> void:
	state = next_state
	_end_frame = _director.sim_frame
	if next_state == State.WON:
		wins += 1
		_director.log_event(&"encounter", &"encounter_win")
	else:
		losses += 1
		_director.log_event(&"encounter", &"encounter_lose")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"encounter_reset"):
		reset_encounter()
