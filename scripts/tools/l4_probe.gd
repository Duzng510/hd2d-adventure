class_name L4Probe
extends Node3D

## T-025 capture rig for the L4 session: a read-only observer that writes the
## context a playtest report would otherwise have to remember into
## `user://l4_probe.csv`, joined to `combat_log.csv` by `sim_frame`.
##
## It listens to CombatDirector.event_logged and samples the world; it never
## writes to gameplay state, so it cannot change feel. For every hit the player
## takes it records how many frames the telegraph really gave them, whether they
## moved after it, whether dodge was available and how close cover was, and it
## saves a PNG of the real frame on each death.
##
## Row kinds (unused columns are empty):
##   v  banner: note = schema and sampling rate
##   s  10 Hz sample: hp, x, z, nearobs, dodge, swing, boss_hp, boss_state,
##      near_role, near_dist
##   h  the player took damage: src, atk, dmg, dist, dreact, moved, nearobs, dodge
##   d  the player died: src, atk, dmg of the killing blow and the boss HP left
##   p  a screenshot was written: note = its path

const SCHEMA := 1
const SAMPLE_EVERY_TICKS := 6
const MOVED_THRESHOLD := 0.4
const PLAYER_TARGET_ID := 2
const OBSERVER_HEIGHT := 1.0
const NEAR_RADII := [0.75, 1.5]
const HISTORY_LIMIT := 900
const COLS := ["frame", "kind", "hp", "x", "z", "nearobs", "dodge", "swing",
	"boss_hp", "boss_state", "atk", "src", "dist", "dreact", "moved", "dmg",
	"near_role", "near_dist", "fps", "note"]

@export var player_path: NodePath = NodePath("../Player")
@export var director_path: NodePath = NodePath("../CombatDirector")
@export var encounter_path: NodePath = NodePath("../WaveEncounter")
@export var probe_path: String = "user://l4_probe.csv"
@export var shot_dir: String = "user://"
@export var capture_death_shots := true
## Off only for the negative control: the probe keeps sampling but stops
## observing hits, which must break the driver's hit-count cross-check.
@export var tap_events := true

var _file: FileAccess
var _player: PlayerController
var _combat: PlayerCombat
var _director: CombatDirector
var _encounter: WaveEncounter
var _history: Array = []
var _deaths := 0
var _hits := 0
var _last_src := ""
var _last_atk := 0
var _last_dmg := 0


func _ready() -> void:
	_player = get_node(player_path) as PlayerController
	_combat = _player.get_node("PlayerCombat") as PlayerCombat
	_director = get_node(director_path) as CombatDirector
	_encounter = get_node(encounter_path) as WaveEncounter
	_file = FileAccess.open(probe_path, FileAccess.WRITE)
	if _file == null:
		push_warning("L4Probe: cannot open %s" % probe_path)
		return
	_file.store_line(",".join(COLS))
	_write({"kind": "v", "note": "schema=%d;sample_every=%d" % [SCHEMA, SAMPLE_EVERY_TICKS]})
	if tap_events:
		_director.event_logged.connect(_on_event)


func _physics_process(_delta: float) -> void:
	if _file == null:
		return
	var frame := _director.sim_frame
	_history.append({"frame": frame, "pos": _player.global_position})
	if _history.size() > HISTORY_LIMIT:
		_history.pop_front()
	if frame % SAMPLE_EVERY_TICKS != 0:
		return
	var near := _nearest_enemy()
	var boss := _boss()
	var row := {
		"kind": "s", "hp": _combat.hp(), "x": _axis(_player.global_position.x),
		"z": _axis(_player.global_position.z), "nearobs": _nearobs(),
		"dodge": 1 if _combat.dodge_available() else 0,
		"swing": 1 if _combat.is_attacking() else 0,
		"boss_hp": -1 if boss == null else boss.hp(),
		"boss_state": -1 if boss == null else int(boss.ai_state()),
		"fps": 0 if _director.sim_frame < 60 else int(Engine.get_frames_per_second()),
	}
	if not near.is_empty():
		row["near_role"] = near["role"]
		row["near_dist"] = _axis(near["dist"])
	_write(row)


func _on_event(entity: StringName, event_name: StringName, attack_id: int, target_id: int, value: int) -> void:
	if _file == null:
		return
	if event_name == &"damage" and target_id == PLAYER_TARGET_ID:
		_hits += 1
		_last_src = str(entity)
		_last_atk = attack_id
		_last_dmg = value
		var row := {
			"kind": "h", "src": _last_src, "atk": attack_id, "dmg": value,
			"hp": _combat.hp(), "nearobs": _nearobs(),
			"dodge": 1 if _combat.dodge_available() else 0,
			"x": _axis(_player.global_position.x), "z": _axis(_player.global_position.z),
		}
		var source := _source_position(entity, attack_id)
		if source == Vector3.INF:
			row["dist"] = -1
		else:
			row["dist"] = _axis(_player.global_position.distance_to(source))
		var lead := _react_frames(entity, attack_id)
		row["dreact"] = lead["frames"]
		if lead.has("note"):
			row["note"] = lead["note"]
		var moved := _moved_since(lead["frames_at"] as int)
		if moved >= 0:
			row["moved"] = moved
		_write(row)
	elif event_name == &"death" and entity == &"player":
		_deaths += 1
		var boss := _boss()
		_write({
			"kind": "d", "src": _last_src, "atk": _last_atk, "dmg": _last_dmg, "hp": 0,
			"boss_hp": -1 if boss == null else boss.hp(),
			"note": "hits=%d" % _hits,
		})
		if capture_death_shots:
			_shot.call_deferred()


## Frames of telegraph the player actually had: hitstop freezes the clock for
## both fighters, so those ticks come out of the raw gap - the number left is
## what a human could have reacted to.
func _react_frames(entity: StringName, attack_id: int) -> Dictionary:
	var record := &"ranged" if entity == &"projectile" else entity
	var start := _director.attack_event_frame(record, attack_id, &"telegraph_start")
	if start < 0:
		return {"frames": -1, "frames_at": -1, "note": "no-telegraph"}
	var frozen := int(_director.attack_event_frozen(record, attack_id, &"telegraph_start"))
	var raw := _director.sim_frame - start
	var usable := (_director.sim_frame - _director.frozen_ticks) - (start - frozen)
	return {"frames": usable, "frames_at": start, "note": "raw=%d;frozen=%d" % [raw, _director.frozen_ticks - frozen]}


func _moved_since(frame: int) -> int:
	if frame < 0:
		return -1
	for entry in _history:
		if int(entry["frame"]) >= frame:
			var was := entry["pos"] as Vector3
			return 1 if _player.global_position.distance_to(was) > MOVED_THRESHOLD else 0
	return -1


func _source_position(entity: StringName, attack_id: int) -> Vector3:
	if entity == &"projectile":
		for node in get_tree().get_nodes_in_group(&"enemy_projectile"):
			var projectile := node as Projectile
			if projectile != null and projectile.attack_id == attack_id:
				return projectile.global_position
		return Vector3.INF
	var best := Vector3.INF
	var best_d := INF
	for enemy in _encounter.enemies():
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.log_entity() != entity or enemy.current_attack_id() != attack_id:
			continue
		var candidate_d := enemy.global_position.distance_squared_to(_player.global_position)
		if candidate_d < best_d:
			best_d = candidate_d
			best = enemy.global_position
	return best


func _nearest_enemy() -> Dictionary:
	var best_d := INF
	var role := ""
	for enemy in _encounter.enemies():
		if enemy == null or not is_instance_valid(enemy) or enemy.hp() <= 0:
			continue
		var distance := enemy.global_position.distance_to(_player.global_position)
		if distance < best_d:
			best_d = distance
			role = str(enemy.log_entity())
	if role == "":
		return {}
	return {"role": role, "dist": best_d}


func _boss() -> Boss:
	for enemy in _encounter.enemies():
		if enemy is Boss and is_instance_valid(enemy):
			return enemy as Boss
	return null


## 1 = touching cover or a wall, 2 = within 1.5 m, 3 = open ground. Queried at
## chest height so the arena floor never counts as cover.
func _nearobs() -> int:
	for level in NEAR_RADII.size():
		var shape := SphereShape3D.new()
		shape.radius = float(NEAR_RADII[level])
		var params := PhysicsShapeQueryParameters3D.new()
		params.shape = shape
		params.transform = Transform3D(Basis.IDENTITY, _player.global_position + Vector3(0.0, OBSERVER_HEIGHT, 0.0))
		params.collision_mask = 1
		params.collide_with_bodies = true
		params.collide_with_areas = false
		if get_world_3d().direct_space_state.intersect_shape(params, 4).is_empty():
			return level + 1
	return 0


func _shot() -> void:
	var image := get_viewport().get_texture().get_image()
	if image == null:
		return
	var path := "%sl4_death_%d.png" % [shot_dir, _deaths]
	if image.save_png(path) != OK:
		return
	_write({"kind": "p", "note": path})


func _axis(value: float) -> float:
	return snappedf(value, 0.01)


func _write(fields: Dictionary) -> void:
	if not fields.has("frame"):
		fields["frame"] = 0 if _director == null else _director.sim_frame
	var cells: Array[String] = []
	for column in COLS:
		cells.append(_text(fields.get(column, "")))
	_file.store_line(",".join(cells))
	_file.flush()


func _text(value) -> String:
	return value if value is String else str(value)
