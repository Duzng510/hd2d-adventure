extends Node

## T-031 evidence: the display path is wired to the damage path, one shown number
## per logged damage line, with the pool and the toggle holding under a spam
## phase. This measures the plumbing, not balance (the staging teleports the
## player next to the target, same as the T-030 harness).
##
##   <GODOT> --headless --path . res://scenes/phase_c/run_t031_numbers.tscn --fixed-fps 60
##   ... -- negative : the hook is unwired, so T31.1 and T31.5 go red (exit 1)
##   ... -- spam     : 30 live chains forced at the view, ceiling + instances (exit 0)
##
## The -- negative fault is injected here at driver level, never as a flag inside
## PlayerCombat (T-030 precedent: DG3 negatives live in the driver).

const FOLLOW_OFFSET := 0.8
const STALK_TICKS := 600
const BATCH_SIZE := 8
const SPAM_TARGETS := 30
## The synthetic load starts after the toggle window closes, so T31.3 and T31.4
## cannot mask each other.
const SPAM_FROM := 330
const TARGET_LOG_HITS := 24
const TOGGLE_FROM := 200
const TOGGLE_TICKS := 60

var _arena: Node
var _encounter: WaveEncounter
var _combat: PlayerCombat
var _player: PlayerController
var _director: CombatDirector
var _numbers: DamageNumbers
var _negative := false
var _spam := false
var _damage_events := 0
var _damage_total := 0
var _shown_events := 0
var _shown_total := 0
var _amounts_ok := true
var _pending_amount := -1
var _ceiling_ok := true
var _stable_labels := true
var _label_ids: Array = []
var _window_damage := 0
var _window_shown := 0
## The spam load drives the view directly, so its shows must stay out of the
## shown-vs-damage accounting below (it has no damage line behind it).
var _synthetic := false
var _tick := 0
var _checks := 0
var _failures := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_negative = args.has("negative")
	_spam = args.has("spam")
	_arena = get_node("../GroveArena")
	_encounter = _arena.get_node("WaveEncounter") as WaveEncounter
	_combat = _arena.get_node("Player/PlayerCombat") as PlayerCombat
	_player = _arena.get_node("Player") as PlayerController
	_director = _arena.get_node("CombatDirector") as CombatDirector
	_numbers = _arena.get_node("DamageNumbers") as DamageNumbers
	if _negative:
		# Driver-level fault: unwire the layer the way a scene without the mount
		# would, instead of teaching PlayerCombat a test flag.
		_combat._numbers = null
	_encounter.set_physics_process(false)
	_combat.aim_override_enabled = true
	_director.event_logged.connect(_observe)
	_numbers.shown.connect(_on_shown)
	_label_ids = _numbers.label_instance_ids()
	_respawn_batch(SPAM_TARGETS if _spam else BATCH_SIZE)
	_run()


func _respawn_batch(count: int) -> void:
	_encounter.debug_clear_enemies()
	for i in count:
		_encounter.debug_spawn("grunt", Vector3(
			1.2 + float(i % 6) * 0.5, 0.0, float(i) / 6.0 * 0.8 - 0.4))


func _run() -> void:
	while _tick < STALK_TICKS:
		await get_tree().physics_frame
		_tick += 1
		if _encounter.alive_count() == 0:
			_respawn_batch(SPAM_TARGETS if _spam else BATCH_SIZE)
		_combat.health.hp = _combat.health.max_hp
		_attack_nearest()
		if _tick == TOGGLE_FROM:
			# The toggle has to shut the readout up while hits keep landing.
			_numbers.set_enabled(false)
		if _tick == TOGGLE_FROM + TOGGLE_TICKS:
			_numbers.set_enabled(true)
		if _spam and _tick > SPAM_FROM:
			_load_display_layer()
	print("damage_events=%d shown_events=%d damage_total=%d shown_total=%d window_damage=%d window_shown=%d ceiling_ok=%s stable_labels=%s labels=%d" % [
		_damage_events, _shown_events, _damage_total, _shown_total, _window_damage,
		_window_shown, str(_ceiling_ok), str(_stable_labels), _numbers.label_count()])
	_check(_damage_events >= TARGET_LOG_HITS,
		"T31.0 the harness really landed %d+ hits (got %d)" % [TARGET_LOG_HITS, _damage_events])
	_check(_shown_events == _damage_events,
		"T31.1 one shown number per logged damage line (shown %d, damage %d)"
		% [_shown_events, _damage_events])
	_check(_amounts_ok, "T31.2 every shown amount matches the damage value the log carries")
	_check(_ceiling_ok and _numbers.label_count() == DamageNumbersKernel.POOL_SIZE,
		"T31.3 the pool stays at %d slots and %d labels (labels %d)"
		% [DamageNumbersKernel.POOL_SIZE, DamageNumbersKernel.POOL_SIZE, _numbers.label_count()])
	_check(_window_damage > 0 and _window_shown == 0,
		"T31.4 the disabled window held %d real hits and showed %d numbers"
		% [_window_damage, _window_shown])
	_check(_shown_total == _damage_total,
		"T31.5 shown damage (%d) equals logged damage (%d)" % [_shown_total, _damage_total])
	_check(_stable_labels, "T31.6 the same %d label instances served every hit"
		% DamageNumbersKernel.POOL_SIZE)
	print("checks=%d failures=%d" % [_checks, _failures])
	print("%s t031_numbers: damage numbers track the damage path" % ("PASS" if _failures == 0 else "FAIL"))
	get_tree().quit(0 if _failures == 0 else 1)


func _attack_nearest() -> void:
	var target := _encounter.nearest_alive_position()
	_player.global_position = target + Vector3(FOLLOW_OFFSET, 0.0, 0.0)
	_player.velocity = Vector3.ZERO
	_combat.aim_override_point = target
	if _combat.attack_phase() == AttackState.Phase.NONE:
		_combat.debug_request_attack()


## Display-layer load, not a balance claim: 30 chains are opened faster than 24
## slots can hold, which is the only scene-level way to exercise eviction and
## prove no Label is ever allocated after _ready.
func _load_display_layer() -> void:
	_synthetic = true
	var enemies := _encounter.enemies()
	for i in enemies.size():
		if enemies[i].hp() > 0:
			_numbers.show_hit(enemies[i], 900 + i, 5)
	_synthetic = false
	if _numbers.active_count() > DamageNumbersKernel.POOL_SIZE:
		_ceiling_ok = false
	if _numbers.label_instance_ids() != _label_ids:
		_stable_labels = false


## The window starts on the tick set_enabled(false) is called and ends before the
## tick that re-enables it: SceneTree emits physics_frame before the nodes run
## _physics_process, so the driver's write and the combat read happen on one tick.
func _in_toggle_window() -> bool:
	return _tick >= TOGGLE_FROM and _tick < TOGGLE_FROM + TOGGLE_TICKS


func _observe(entity: StringName, event_name: StringName, _attack_id: int, _target_id: int, value: int) -> void:
	if entity != &"player" or event_name != &"damage":
		return
	if _in_toggle_window():
		_window_damage += 1
		return
	_damage_events += 1
	_damage_total += value
	_pending_amount = value


func _on_shown(_target_id: int, amount: int, _total: int) -> void:
	if _synthetic:
		return
	if _in_toggle_window():
		_window_shown += 1
		return
	_shown_events += 1
	_shown_total += amount
	if _pending_amount < 0 or amount != _pending_amount:
		_amounts_ok = false
	_pending_amount = -1


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if ok:
		print("CHECK PASS %s" % label)
		return
	_failures += 1
	print("CHECK FAIL %s" % label)
