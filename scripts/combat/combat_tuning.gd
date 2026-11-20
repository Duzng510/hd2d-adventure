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

@export_group("Attack tempo (T-027, player only)")
@export var fatigue_free_swings: int = 3
@export var fatigue_step_frames: int = 4
@export var fatigue_max_frames: int = 12
@export var fatigue_decay_frames: int = 6

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

@export_group("Swarm")
@export var swarm_max_hp: int = 20
@export var swarm_detect_range: float = 6.0
@export var swarm_attack_range: float = 1.0
@export var swarm_approach_speed: float = 3.125
@export var swarm_telegraph_frames: int = 18
@export var swarm_active_frames: int = 4
@export var swarm_recovery_frames: int = 20
@export var swarm_damage: int = 5

@export_group("Ranged")
@export var ranged_max_hp: int = 30
@export var ranged_min_range: float = 3.5
@export var ranged_max_range: float = 7.0
@export var ranged_approach_speed: float = 2.0
@export var ranged_telegraph_frames: int = 24
@export var ranged_active_frames: int = 4
@export var ranged_recovery_frames: int = 30
@export var ranged_damage: int = 8
@export var ranged_projectile_speed: float = 6.0
@export var ranged_projectile_lifetime_frames: int = 120

@export_group("Boss")
@export var boss_max_hp: int = 300
@export var boss_detect_range: float = 12.0
@export var boss_chase_speed: float = 2.0
@export var boss_phase_hp_percent: int = 50
@export var boss_phase_switch_frames: int = 45
@export var boss_smash_telegraph_frames: int = 30
@export var boss_smash_active_frames: int = 6
@export var boss_smash_recovery_frames: int = 30
@export var boss_smash_phase2_recovery_frames: int = 20
@export var boss_smash_damage: int = 20
@export var boss_smash_radius: float = 2.2
@export var boss_lunge_telegraph_frames: int = 24
@export var boss_lunge_active_frames: int = 8
@export var boss_lunge_recovery_frames: int = 36
@export var boss_lunge_phase2_recovery_frames: int = 24
@export var boss_lunge_damage: int = 12
@export var boss_lunge_range: float = 5.0
@export var boss_sweep_telegraph_frames: int = 20
@export var boss_sweep_active_frames: int = 6
@export var boss_sweep_recovery_frames: int = 24
@export var boss_sweep_damage: int = 10
@export var boss_sweep_radius: float = 2.6
