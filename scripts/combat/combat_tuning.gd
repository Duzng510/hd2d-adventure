class_name CombatTuning
extends Resource

## Authoritative combat tuning at 60 tick/s; GDD 6.4 values are hypotheses.

@export_group("Light attack")
@export var light_startup_frames: int = 4
@export var light_active_frames: int = 3
@export var light_recovery_frames: int = 10
@export var combo_window_frames: int = 10
@export var light_combo_hits: int = 3
@export var light_damage: int = 10
@export var light_reach: float = 1.4

@export_group("Dodge")
@export var dodge_iframe_frames: int = 10
@export var dodge_total_frames: int = 22
@export var dodge_speed: float = 7.0

@export_group("Input")
@export var input_buffer_frames: int = 6

@export_group("Hitstop")
@export var hitstop_frames: int = 3

@export_group("Health")
@export var player_max_hp: int = 100
@export var grunt_max_hp: int = 30

@export_group("Grunt")
@export var grunt_detect_range: float = 6.0
@export var grunt_approach_speed: float = 2.5
@export var grunt_attack_range: float = 1.3
@export var grunt_telegraph_frames: int = 20
@export var grunt_active_frames: int = 3
@export var grunt_recovery_frames: int = 18
@export var grunt_damage: int = 15
