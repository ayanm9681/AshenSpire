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

# ==============================
# BOSS STATS
# ==============================

var boss_max_hp: int = 1200
var boss_hp: int = 1200
var boss_damage: int = 18
var boss_defense: int = 5

var boss_next_move: String = ""
var last_boss_move: String = ""

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
	player_hp = player_max_hp
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

func _player_attack() -> void:
	var base: int = default_player_damage - boss_defense
	var damage: int = base if base > 0 else 1

	damage += 2  # small balance adjustment

	boss_hp -= damage
	boss_hp = max(0, boss_hp)
	threshold_damage_dealt += damage
	threshold_turns += 1

	emit_signal("combat_log_updated", "You dealt %d damage." % damage)
	emit_signal("hp_changed", "boss", boss_hp)

	_check_echo_threshold()

func _player_heavy_attack() -> void:
	var base: int = default_player_damage - boss_defense
	var damage: int = int(max(base, 1) * GameManager.default_heavy_multiplier)

	boss_hp -= damage
	boss_hp = max(0, boss_hp)
	threshold_damage_dealt += damage
	threshold_turns += 1

	emit_signal("combat_log_updated", "You unleash a HEAVY strike for %d damage." % damage)
	emit_signal("hp_changed", "boss", boss_hp)

	_check_echo_threshold()

func _player_sword_attack() -> void:
	var base: int = sword_player_damage - boss_defense
	var damage: int = base if base > 0 else 1

	damage += 2

	boss_hp -= damage
	boss_hp = max(0, boss_hp)
	threshold_damage_dealt += damage
	threshold_turns += 1

	emit_signal("combat_log_updated", "Sword attack dealt %d damage." % damage)
	emit_signal("hp_changed", "boss", boss_hp)

	_check_echo_threshold()

func _player_sword_heavy_attack() -> void:
	GameManager.active_loadout.degrade_weapon(5)
	sword_player_damage = GameManager.active_loadout.effective_damage()
	var base: int = sword_player_damage - boss_defense
	var damage: int = int(max(base, 1) * 1.8)

	boss_hp -= damage
	boss_hp = max(0, boss_hp)
	threshold_damage_dealt += damage
	threshold_turns += 1

	emit_signal("combat_log_updated", "You unleash a SWORD HEAVY strike for %d damage." % damage)
	emit_signal("hp_changed", "boss", boss_hp)

	_check_echo_threshold()

func _player_defend() -> void:
	player_is_defending = true
	threshold_turns += 1
	emit_signal("combat_log_updated", "You brace for impact.")

func _player_use_item() -> void:
	var heal: int = 25
	player_hp = min(player_max_hp, player_hp + heal)
	threshold_turns += 1

	emit_signal("combat_log_updated", "You healed %d HP." % heal)
	emit_signal("hp_changed", "player", player_hp)

# ==============================
# BOSS TURN
# ==============================

func _boss_act() -> void:
	var raw_damage: int = boss_damage

	match boss_next_move:
		"STRIKE":
			raw_damage = boss_damage
			emit_signal("combat_log_updated", "Warden uses STRIKE!")

		"HEAVY":
			raw_damage = int(boss_damage * 1.8)
			emit_signal("combat_log_updated", "Warden unleashes HEAVY attack!")

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
	emit_signal("combat_log_updated", "You took %d damage." % final_damage)
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
