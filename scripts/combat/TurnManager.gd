# TurnManager.gd
class_name TurnManager
extends Node

# ==============================
# SIGNALS (BossArena compatible)
# ==============================

signal hp_changed(entity: String, new_hp: int)
signal boss_attack_started()
signal combat_log_updated(message: String)
signal telegraph_updated(move: String, description: String)
signal player_turn_started()
signal boss_turn_started()
signal combat_ended(player_won: bool)
signal loadout_swapped(new_loadout)
signal charges_updated(attack_charges: int, attack_max_charges: int, heavy_charges: int, heavy_max_charges: int)
signal damage_taken(entity: String, amount: int, is_crit: bool)

# ==============================
# ENUMS
# ==============================

enum PlayerAction {
	ATTACK,
	HEAVY_ATTACK,
	SWORD_ATTACK,   # ← new
	SWORD_HEAVY,    # ← new
	DEFEND,
	USE_ITEM
}

enum TurnState {
	PLAYER_TURN,
	BOSS_TURN,
	ENDED
}

var turn_state: TurnState = TurnState.PLAYER_TURN

# ==============================
# PLAYER STATS (from loadout)
# ==============================

var player_max_hp: int = 100
var player_hp: int = 100
var default_player_damage: int = 0
var sword_player_damage: int = 0
var player_defense: int = 0
var player_is_defending: bool = false

const HERO_BASE_CRIT_CHANCE: float = 0.10
const HERO_BASE_CRIT_MULTIPLIER: float = 1.5
const SWORD_UNLOCK_THRESHOLD: int = 2
const MAX_COMBO_COUNT: int = 3
const COMBO_LEVEL3_CRIT_BOOST: float = 0.5

# ==============================
# BOSS STATS
# ==============================

var boss_max_hp: int = 1200
var boss_hp: int = 1200
var boss_damage: int = 18
var boss_defense: int = 5

var boss_next_move: String = ""
var last_boss_move: String = ""

const BOSS_CRIT_CHANCE: float = 0.20
const BOSS_STRIKE_CRIT_MULTIPLIER: float = 2.1
const BOSS_HEAVY_CRIT_MULTIPLIER: float = 2.2

# ==============================
# ECHO TRACKING (unchanged)
# ==============================

var threshold_damage_dealt: int = 0
var threshold_turns: int = 0
var threshold_required_damage: float = boss_hp*0.15
var threshold_turn_window: int = 6
var echo_threshold_met: bool = false

# ==============================
# READY
# ==============================

func _ready() -> void:
	_apply_loadout_stats()
	randomize()
	_roll_next_move()

	emit_signal("telegraph_updated", boss_next_move, _describe_move(boss_next_move))
	emit_signal("hp_changed", "player", player_hp)
	emit_signal("hp_changed", "boss", boss_hp)
	emit_signal("player_turn_started")

# ==============================
# LOADOUT APPLY
# ==============================

func _apply_loadout_stats() -> void:
	default_player_damage = GameManager.default_weapon_damage
	sword_player_damage = GameManager.active_loadout.weapon_damage
	player_defense = GameManager.active_loadout.armor_defense
	player_hp = GameManager.active_loadout.current_hp
	player_max_hp = GameManager.active_loadout.max_hp
	GameManager.player_hp = player_hp
# ==============================
# PLAYER ACTION ENTRY
# ==============================

func player_act(action: PlayerAction) -> void:
	if turn_state != TurnState.PLAYER_TURN:
		return

	player_is_defending = false

	match action:
		PlayerAction.ATTACK:
			_player_attack()
		PlayerAction.HEAVY_ATTACK:
			_player_heavy_attack()
		PlayerAction.SWORD_ATTACK:
			_player_sword_attack()
		PlayerAction.SWORD_HEAVY:
			_player_sword_heavy_attack()
		PlayerAction.DEFEND:
			_player_defend()
		PlayerAction.USE_ITEM:
			_player_use_item()

	_check_end()
	if turn_state == TurnState.ENDED:
		return

	turn_state = TurnState.BOSS_TURN
	emit_signal("boss_turn_started")
	await get_tree().create_timer(0.35).timeout
	emit_signal("boss_attack_started")
	await get_tree().create_timer(0.85).timeout
	_boss_act()

# ==============================
# PLAYER ACTIONS
# ==============================

func player_swap_loadout(loadout_index: int) -> void:
	if turn_state != TurnState.PLAYER_TURN:
		return
	# Save current HP to active loadout before swapping
	GameManager.active_loadout.current_hp = player_hp
	var success = GameManager.swap_to_loadout(loadout_index)
	if success:
		_apply_loadout_stats()
		emit_signal("loadout_swapped", GameManager.active_loadout)
		emit_signal("hp_changed", "player", player_hp)
		emit_signal("charges_updated", GameManager.active_loadout.sword_attack_charges, GameManager.active_loadout.sword_attack_max_charges, GameManager.active_loadout.sword_heavy_charges, GameManager.active_loadout.sword_heavy_max_charges)
		emit_signal("combat_log_updated", "Switched to %s!" % GameManager.active_loadout.weapon_name)
		## Counts as your turn
		#turn_state = TurnState.BOSS_TURN
		#emit_signal("boss_turn_started")
		#await get_tree().create_timer(0.35).timeout
		#emit_signal("boss_attack_started")
		#await get_tree().create_timer(0.85).timeout
		#_boss_act()

func _player_attack() -> void:
	var base: int = default_player_damage - boss_defense
	var damage: int = base if base > 0 else 1

	damage += 2  # small balance adjustment
	var crit_roll := _roll_critical(HERO_BASE_CRIT_CHANCE, HERO_BASE_CRIT_MULTIPLIER)
	if crit_roll["is_crit"]:
		damage = int(round(float(damage) * crit_roll["multiplier"]))

	boss_hp -= damage
	boss_hp = max(0, boss_hp)
	threshold_damage_dealt += damage
	threshold_turns += 1

	if crit_roll["is_crit"]:
		emit_signal("combat_log_updated", "CRIT! You dealt %d damage." % damage)
	else:
		emit_signal("combat_log_updated", "You dealt %d damage." % damage)
	emit_signal("damage_taken", "boss", damage, crit_roll["is_crit"])
	emit_signal("hp_changed", "boss", boss_hp)

	_check_echo_threshold()
	GameManager.active_loadout.default_combo_count = min(MAX_COMBO_COUNT, GameManager.active_loadout.default_combo_count + 1)

func _player_heavy_attack() -> void:
	var base: int = default_player_damage - boss_defense
	var damage: int = int(max(base, 1) * GameManager.default_heavy_multiplier)
	var crit_roll := _roll_critical(HERO_BASE_CRIT_CHANCE, HERO_BASE_CRIT_MULTIPLIER)
	if crit_roll["is_crit"]:
		damage = int(round(float(damage) * crit_roll["multiplier"]))

	boss_hp -= damage
	boss_hp = max(0, boss_hp)
	threshold_damage_dealt += damage
	threshold_turns += 1

	if crit_roll["is_crit"]:
		emit_signal("combat_log_updated", "CRIT! HEAVY strike for %d damage." % damage)
	else:
		emit_signal("combat_log_updated", "You unleash a HEAVY strike for %d damage." % damage)
	emit_signal("damage_taken", "boss", damage, crit_roll["is_crit"])
	emit_signal("hp_changed", "boss", boss_hp)

	_check_echo_threshold()
	GameManager.active_loadout.default_heavy_combo_count = min(MAX_COMBO_COUNT, GameManager.active_loadout.default_heavy_combo_count + 1)

func _player_sword_attack() -> void:
	if not can_use_sword_attack_action():
		emit_signal("combat_log_updated", "Sword attack locked. Build %d default attacks first." % SWORD_UNLOCK_THRESHOLD)
		threshold_turns += 1
		return
	if not GameManager.active_loadout.use_sword_attack_charge():
		emit_signal("combat_log_updated", "No sword charges remaining!")
		# Still costs a turn but does no damage
		threshold_turns += 1
		return
	var combo_before_attack: int = GameManager.active_loadout.default_combo_count
	var base: int = sword_player_damage - boss_defense
	var damage: int = base if base > 0 else 1
	damage += 2
	var sword_crit := _hero_sword_crit_values()
	if combo_before_attack >= MAX_COMBO_COUNT:
		sword_crit["chance"] *= (1.0 + COMBO_LEVEL3_CRIT_BOOST)
		sword_crit["multiplier"] *= (1.0 + COMBO_LEVEL3_CRIT_BOOST)
	var crit_roll := _roll_critical(sword_crit["chance"], sword_crit["multiplier"])
	if crit_roll["is_crit"]:
		damage = int(round(float(damage) * crit_roll["multiplier"]))
	boss_hp -= damage
	boss_hp = max(0, boss_hp)
	threshold_damage_dealt += damage
	threshold_turns += 1
	if combo_before_attack >= MAX_COMBO_COUNT:
		GameManager.active_loadout.refund_sword_attack_charge(1)
	if crit_roll["is_crit"]:
		emit_signal("combat_log_updated", "CRIT! Sword attack dealt %d damage. [%d charges left]" % [damage, GameManager.active_loadout.sword_attack_charges])
	else:
		emit_signal("combat_log_updated", "Sword attack dealt %d damage. [%d charges left]" % [damage, GameManager.active_loadout.sword_attack_charges])
	emit_signal("damage_taken", "boss", damage, crit_roll["is_crit"])
	emit_signal("hp_changed", "boss", boss_hp)
	GameManager.active_loadout.default_combo_count = 0
	emit_signal("charges_updated", GameManager.active_loadout.sword_attack_charges, GameManager.active_loadout.sword_attack_max_charges, GameManager.active_loadout.sword_heavy_charges, GameManager.active_loadout.sword_heavy_max_charges)
	_check_echo_threshold()

func _player_sword_heavy_attack() -> void:
	if not can_use_sword_heavy_action():
		emit_signal("combat_log_updated", "Sword heavy locked. Build %d default heavy attacks first." % SWORD_UNLOCK_THRESHOLD)
		threshold_turns += 1
		return
	if not GameManager.active_loadout.use_sword_heavy_charge():
		emit_signal("combat_log_updated", "No sword charges remaining!")
		threshold_turns += 1
		return
	var combo_before_heavy: int = GameManager.active_loadout.default_heavy_combo_count
	GameManager.active_loadout.degrade_weapon(5)
	sword_player_damage = GameManager.active_loadout.effective_damage()
	var base: int = sword_player_damage - boss_defense
	var damage: int = int(max(base, 1) * 1.8)
	var sword_crit := _hero_sword_crit_values()
	if combo_before_heavy >= MAX_COMBO_COUNT:
		sword_crit["chance"] *= (1.0 + COMBO_LEVEL3_CRIT_BOOST)
		sword_crit["multiplier"] *= (1.0 + COMBO_LEVEL3_CRIT_BOOST)
	var crit_roll := _roll_critical(sword_crit["chance"], sword_crit["multiplier"])
	if crit_roll["is_crit"]:
		damage = int(round(float(damage) * crit_roll["multiplier"]))
	boss_hp -= damage
	boss_hp = max(0, boss_hp)
	threshold_damage_dealt += damage
	threshold_turns += 1
	if combo_before_heavy >= MAX_COMBO_COUNT:
		GameManager.active_loadout.refund_sword_heavy_charge(1)
	if crit_roll["is_crit"]:
		emit_signal("combat_log_updated", "CRIT! SWORD HEAVY for %d damage. [%d charges left]" % [damage, GameManager.active_loadout.sword_heavy_charges])
	else:
		emit_signal("combat_log_updated", "SWORD HEAVY for %d damage. [%d charges left]" % [damage, GameManager.active_loadout.sword_heavy_charges])
	emit_signal("damage_taken", "boss", damage, crit_roll["is_crit"])
	emit_signal("hp_changed", "boss", boss_hp)
	GameManager.active_loadout.default_heavy_combo_count = 0
	emit_signal("charges_updated", GameManager.active_loadout.sword_attack_charges, GameManager.active_loadout.sword_attack_max_charges, GameManager.active_loadout.sword_heavy_charges, GameManager.active_loadout.sword_heavy_max_charges)
	_check_echo_threshold()

func can_use_sword_attack_action() -> bool:
	return GameManager.active_loadout.default_combo_count >= SWORD_UNLOCK_THRESHOLD and GameManager.active_loadout.has_sword_attack_charges()

func can_use_sword_heavy_action() -> bool:
	return GameManager.active_loadout.default_heavy_combo_count >= SWORD_UNLOCK_THRESHOLD and GameManager.active_loadout.has_sword_heavy_charges()

func _player_defend() -> void:
	player_is_defending = true
	threshold_turns += 1
	emit_signal("combat_log_updated", "You brace for impact.")

func _player_use_item() -> void:
	var heal: int = 25
	player_hp = min(player_max_hp, player_hp + heal)
	threshold_turns += 1
	GameManager.player_hp = player_hp
	GameManager.active_loadout.current_hp = player_hp

	emit_signal("combat_log_updated", "You healed %d HP." % heal)
	emit_signal("hp_changed", "player", player_hp)

# ==============================
# BOSS TURN
# ==============================

func _boss_act() -> void:
	var raw_damage: int = boss_damage
	var was_critical := false

	match boss_next_move:
		"STRIKE":
			raw_damage = boss_damage
			var strike_crit := _roll_critical(BOSS_CRIT_CHANCE, BOSS_STRIKE_CRIT_MULTIPLIER)
			if strike_crit["is_crit"]:
				raw_damage = int(round(float(raw_damage) * strike_crit["multiplier"]))
				was_critical = true
			emit_signal("combat_log_updated", "Warden uses STRIKE%s" % (" — CRIT!" if was_critical else "!"))

		"HEAVY":
			raw_damage = int(boss_damage * 1.8)
			var heavy_crit := _roll_critical(BOSS_CRIT_CHANCE, BOSS_HEAVY_CRIT_MULTIPLIER)
			if heavy_crit["is_crit"]:
				raw_damage = int(round(float(raw_damage) * heavy_crit["multiplier"]))
				was_critical = true
			emit_signal("combat_log_updated", "Warden unleashes HEAVY attack%s" % (" — CRIT!" if was_critical else "!"))

		"ENDURE":
			var heal: int = 20
			boss_hp = min(boss_max_hp, boss_hp + heal)
			emit_signal("combat_log_updated", "Warden ENDURES and heals %d HP!" % heal)
			emit_signal("hp_changed", "boss", boss_hp)

			_end_boss_turn()
			return

	var final_damage: int = raw_damage

	if player_is_defending:
		if boss_next_move == "HEAVY":
			final_damage = int(raw_damage * 0.35)  # 65% reduction
		else:
			final_damage = int(raw_damage * 0.5)   # 50% reduction

	player_hp -= final_damage
	player_hp = max(0, player_hp)
	GameManager.player_hp = player_hp
	GameManager.active_loadout.current_hp = player_hp
	emit_signal("combat_log_updated", "You took %d damage." % final_damage)
	emit_signal("damage_taken", "player", final_damage, was_critical)
	emit_signal("hp_changed", "player", player_hp)
	
	if player_hp <= 0:
		_handle_player_death()
		return 
	_end_boss_turn()

# ==============================
# END BOSS TURN
# ==============================

func _end_boss_turn() -> void:
	_check_end()
	if turn_state == TurnState.ENDED:
		return

	_roll_next_move()
	emit_signal("telegraph_updated", boss_next_move, _describe_move(boss_next_move))

	await get_tree().create_timer(1.0).timeout  # small recovery delay
	turn_state = TurnState.PLAYER_TURN
	emit_signal("player_turn_started")

# ==============================
# BOSS AI (no heavy spam)
# ==============================

func _roll_next_move() -> void:
	var roll: int = randi() % 100

	if last_boss_move == "HEAVY":
		boss_next_move = "STRIKE" if roll < 70 else "ENDURE"
	else:
		if roll < 50:
			boss_next_move = "STRIKE"
		elif roll < 80:
			boss_next_move = "HEAVY"
		else:
			boss_next_move = "ENDURE"

	last_boss_move = boss_next_move

# ==============================
# TELEGRAPH DESCRIPTION
# ==============================

func _describe_move(move: String) -> String:
	match move:
		"STRIKE":
			return "Quick slash"
		"HEAVY":
			return "Massive overhead strike.Defend!!"
		"ENDURE":
			return "Recovering vitality."
	return ""

# ==============================
# ECHO CHECK (unchanged logic)
# ==============================

func _check_echo_threshold() -> void:
	if threshold_turns > threshold_turn_window:
		threshold_damage_dealt = 0
		threshold_turns = 0

	if threshold_damage_dealt >= threshold_required_damage:
		echo_threshold_met = true

# ==============================
# END CHECK
# ==============================

func _check_end() -> void:
	if player_hp <= 0:
		_handle_player_death()

	elif boss_hp <= 0:
		turn_state = TurnState.ENDED
		emit_signal("combat_log_updated", "The Warden falls.")
		emit_signal("combat_ended", true)

# ==============================
# LOADOUT CONTINUE SYSTEM
# ==============================

func _handle_player_death() -> void:
	turn_state = TurnState.ENDED 
	var run_continues: bool = GameManager.on_player_death()

	if run_continues:
		_apply_loadout_stats()
		emit_signal("loadout_swapped", GameManager.active_loadout)
		emit_signal("hp_changed", "player", player_hp)
		emit_signal("combat_log_updated", "You rise again with a new loadout!")
		await get_tree().create_timer(1.0).timeout
		turn_state = TurnState.PLAYER_TURN
		emit_signal("player_turn_started")
	else:
		turn_state = TurnState.ENDED
		emit_signal("combat_log_updated", "You were defeated.")
		emit_signal("combat_ended", false)

func _hero_sword_crit_values() -> Dictionary:
	var crit_chance := HERO_BASE_CRIT_CHANCE
	var crit_multiplier := HERO_BASE_CRIT_MULTIPLIER
	match GameManager.active_loadout.weapon_type:
		LoadoutData.WeaponType.EXCALIBUR:
			crit_chance += 0.15
			crit_multiplier += 0.75
		LoadoutData.WeaponType.DURANDAL:
			crit_chance += 0.12
			crit_multiplier += 0.75
		LoadoutData.WeaponType.SUNSWORD:
			crit_chance += 0.10
			crit_multiplier += 0.85
	return {
		"chance": crit_chance,
		"multiplier": crit_multiplier
	}

func _roll_critical(chance: float, multiplier: float) -> Dictionary:
	return {
		"is_crit": randf() <= chance,
		"multiplier": multiplier
	}
