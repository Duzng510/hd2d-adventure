extends Node

## T-030 buff evidence: ten full 3-wave runs with the chooser in auto-pick.
## Every run must park twice in BUFF_PENDING, resolve both picks through the
## encounter, and leave exactly two modifiers on PlayerStats before the reset.
## Damage/hits come from the director event tap, so dmg_per_s is comparable with
## the Phase C baseline (4.8) printed next to it.
##
##   <GODOT> --headless --path . res://scenes/phase_c/run_t030_buffs.tscn --fixed-fps 60
##   ... -- negative      : T30.3 expects zero picks, so the run goes red (exit 1)
##   ... -- stall         : park the flow with no resolve_pick -> T30.5 red (exit 1)
##   ... -- dirty-reset   : leave a modifier across a reset -> T30.6 red (exit 1)
##
## T30.5/T30.6 are behavioural negatives: the -- stall / -- dirty-reset faults are
## injected here at driver level, never as flags inside production classes.

const TARGET_RUNS := 10
const MAX_TICKS := 40000
const PICKS_PER_RUN := 2
const SEED_BASE := 4242
## A lost resolve parks the flow in BUFF_PENDING forever; 600 idle ticks (10 s)
## is far past any legitimate pause (60 tick wave pause + a pick), so it proves
## the flow is stuck instead of slow.
const STALL_TICKS := 600
## Wave 2 kites, so the harness follows the nearest alive enemy instead of
## pinning one point; the 0.8 m offset keeps the target inside light_reach (1.4).
const FOLLOW_OFFSET := 0.8

var _encounter: WaveEncounter
var _combat: PlayerCombat
var _player: PlayerController
var _director: CombatDirector
var _negative := false
var _stall_mode := false
var _dirty_mode := false
var _runs_ok := true
var _mods_ok := true
var _stalled := false
var _reset_clean := true
var _stall_injected := false
var _dirty_injected := false
var _pending_ticks := 0
var _picks_total := 0
var _damage := 0
var _hits := 0
var _checks := 0
var _failures := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_negative = args.has("negative")
	_stall_mode = args.has("stall")
	_dirty_mode = args.has("dirty-reset")
	var arena := get_node("../GroveArena")
	_encounter = arena.get_node("WaveEncounter") as WaveEncounter
	_combat = arena.get_node("Player/PlayerCombat") as PlayerCombat
	_player = arena.get_node("Player") as PlayerController
	_director = arena.get_node("CombatDirector") as CombatDirector
	_combat.aim_override_enabled = true
	# Fixed seed base: run N offers from seed 4242 + N, so the 20 picks are
	# reproducible from the combat log's buff_seed rows.
	_encounter.buff_seed_base = SEED_BASE
	_director.event_logged.connect(_observe)
	_run()


func _run() -> void:
	var ticks := 0
	var fight_ticks := 0
	while _encounter.runs_completed < TARGET_RUNS and ticks < MAX_TICKS:
		await get_tree().physics_frame
		ticks += 1
		var state := _encounter.kernel.state
		if _stall_mode and not _stall_injected and _encounter.buff != null:
			# DG3 fixture "missing resolve_pick": the flow parks in BUFF_PENDING
			# with the offer already marked emitted, so auto-pick never fires and
			# nothing can leave the state. Driver-level simulation only.
			_stall_injected = true
			_encounter._offer_emitted = true
			_encounter.kernel.state = WaveKernel.State.BUFF_PENDING
			state = _encounter.kernel.state
		if state == WaveKernel.State.BUFF_PENDING:
			_pending_ticks += 1
			if _pending_ticks > STALL_TICKS:
				_stalled = true
				print("STALL run=%d pending_ticks=%d" % [_encounter.runs_completed, _pending_ticks])
				break
		else:
			_pending_ticks = 0
		if state == WaveKernel.State.FIGHTING or state == WaveKernel.State.PAUSED \
				or state == WaveKernel.State.BUFF_PENDING:
			fight_ticks += 1
			# Top the HP every fighting tick: this harness verifies buff flow, not
			# balance, so a death would hide whether the picks landed.
			_combat.health.hp = _combat.health.max_hp
			if _encounter.alive_count() > 0:
				var target := _encounter.nearest_alive_position()
				var staging := target + Vector3(FOLLOW_OFFSET if target.x < 0.0 else -FOLLOW_OFFSET, 0.0, 0.0)
				if _player.global_position.distance_to(staging) > 0.4:
					_player.global_position = staging
					_player.velocity = Vector3.ZERO
			_combat.aim_override_point = _encounter.nearest_alive_position()
			if _combat.attack_phase() == AttackState.Phase.NONE:
				_combat.debug_request_attack()
		if state == WaveKernel.State.WON:
			# Before the reset rebuilds the kernel and clears the modifiers: the
			# two picks of this run must still be visible.
			var picked := _encounter.buff.picked_ids().size()
			var mods := _combat.stats.active_modifiers().size()
			if picked != PICKS_PER_RUN or mods != PICKS_PER_RUN:
				_runs_ok = false
				print("RUN MISMATCH run=%d picks=%d mods=%d" % [_encounter.runs_completed, picked, mods])
			else:
				_picks_total += PICKS_PER_RUN
			if mods != PICKS_PER_RUN:
				_mods_ok = false
			_encounter.reset_run()
			# Run boundary (runs_completed just changed, the new run is in wave 1
			# and cannot pick yet): every modifier of the old run must be gone.
			if _dirty_mode and not _dirty_injected:
				# DG3 fixture "buffs-not-reset-on-r": a stray modifier survives the
				# reset; the detector below must catch it before any new pick.
				_dirty_injected = true
				_combat.stats.add_modifier(&"dirty_fixture", {&"light_damage_add": 1.0})
			if not _combat.stats.active_modifiers().is_empty():
				_reset_clean = false
			if _dirty_mode and _dirty_injected:
				# The fixture is a one-shot fault: remove it after the detector read
				# it so T30.6 is the only red line and the remaining runs stay green.
				_combat.stats.remove_modifier(&"dirty_fixture")
	var runs := _encounter.runs_completed
	var wins := _encounter.wins
	var dmg_per_s := float(_damage) / maxf(float(fight_ticks) / 60.0, 1.0)
	print("runs=%d wins=%d picks=%d mods_ok=%s dmg=%d hits=%d fight_ticks=%d dmg_per_s=%.1f" % [
		runs, wins, _picks_total, str(_mods_ok and _runs_ok), _damage, _hits, fight_ticks, dmg_per_s])
	print("phase_c_baseline=4.8")
	_check(runs == TARGET_RUNS and wins == TARGET_RUNS and _runs_ok,
		"T30.0 runs==10 wins==10 (%d/%d) and every run banked both picks (runs_ok=%s)"
		% [runs, wins, str(_runs_ok)])
	_check(_picks_total == TARGET_RUNS * PICKS_PER_RUN,
		"T30.1 picks==20 (picks=%d)" % _picks_total)
	_check(_mods_ok and _runs_ok,
		"T30.2 mods_ok: exactly 2 active modifiers before each reset (mods_ok=%s runs_ok=%s)"
		% [str(_mods_ok), str(_runs_ok)])
	var expected := 0 if _negative else 20
	_check(_picks_total == expected,
		"T30.3 picks_total == %d%s (got %d)" % [expected, " on -- negative" if _negative else "", _picks_total])
	_check(not _stalled,
		"T30.5 buff flow never stalls in BUFF_PENDING (stalled=%s pending_ticks=%d)"
		% [str(_stalled), _pending_ticks])
	_check(_reset_clean,
		"T30.6 modifiers cleared after reset (reset_clean=%s)" % str(_reset_clean))
	print("checks=%d failures=%d" % [_checks, _failures])
	print("%s t030_buffs: buff picks in the wave flow" % ("PASS" if _failures == 0 else "FAIL"))
	get_tree().quit(0 if _failures == 0 else 1)


## Director tap: the player's damage events are the authoritative numbers, so the
## summary does not re-derive damage from enemy HP.
func _observe(entity: StringName, event_name: StringName, _attack_id: int, _target_id: int, value: int) -> void:
	if entity != &"player":
		return
	if event_name == &"damage":
		_damage += value
	elif event_name == &"hit":
		_hits += 1


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if ok:
		print("CHECK PASS %s" % label)
		return
	_failures += 1
	print("CHECK FAIL %s" % label)
