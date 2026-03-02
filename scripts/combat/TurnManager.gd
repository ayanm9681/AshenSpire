# TurnManager.gd
extends Node

# ─── SIGNALS ──────────────────────────────────────────────
signal player_turn_started
signal boss_turn_started
signal combat_log_updated(message)
signal hp_changed(entity, new_hp)
signal combat_ended(player_won)
signal telegraph_updated(boss_move, description)
signal loadout_swapped(new_loadout)

# ─── ENUMS ────────────────────────────────────────────────
enum TurnState { PLAYER_TURN, BOSS_TURN, RESOLVING, ENDED }
enum PlayerAction { ATTACK, DEFEND, USE_ITEM }

# ─── COMBAT STATE ─────────────────────────────────────────
var turn_state = TurnState.PLAYER_TURN
var player_is_defending = false

# ─── PLAYER STATS ─────────────────────────────────────────
var player_hp = 100
var player_max_hp = 100
var player_damage = 22
var player_defense = 8

# ─── BOSS STATS ───────────────────────────────────────────
var boss_hp = 300
var boss_max_hp = 300
var boss_damage = 30
var boss_defense = 5
var boss_name = "The Warden"

# ─── TELEGRAPH ────────────────────────────────────────────
var boss_next_move = ""
var boss_next_description = ""

# ─── ECHO THRESHOLD TRACKING ──────────────────────────────
var threshold_damage_dealt = 0
var threshold_turns = 0
var threshold_required_damage = 180
var threshold_turn_window = 6
var echo_threshold_met = false

# ─── READY ────────────────────────────────────────────────
func _ready():
	_sync_from_game_manager()
	_boss_choose_next_move()
	emit_signal("player_turn_started")

func _sync_from_game_manager():
	player_hp = GameManager.player_hp
	player_max_hp = GameManager.player_max_hp
	player_damage = GameManager.active_loadout.weapon_damage
	player_defense = GameManager.active_loadout.armor_defense

# ─── PLAYER ACTIONS ───────────────────────────────────────
func player_act(action):
	if turn_state != TurnState.PLAYER_TURN:
		return

	turn_state = TurnState.RESOLVING
	player_is_defending = false

	match action:
		PlayerAction.ATTACK:
			_player_attack()
		PlayerAction.DEFEND:
			_player_defend()
		PlayerAction.USE_ITEM:
			_player_use_item()

func _player_attack():
	var damage = max(1, player_damage - boss_defense)
	boss_hp -= damage
	boss_hp = max(0, boss_hp)

	# Echo threshold tracking
	threshold_turns += 1
	if threshold_turns <= threshold_turn_window:
		threshold_damage_dealt += damage
		_check_echo_threshold()

	emit_signal("hp_changed", "boss", boss_hp)
	emit_signal("combat_log_updated",
		"You strike for %d damage." % damage)

	if boss_hp <= 0:
		_end_combat(true)
		return

	_start_boss_turn()

func _player_defend():
	player_is_defending = true
	emit_signal("combat_log_updated", "You brace for impact.")
	_start_boss_turn()

func _player_use_item():
	emit_signal("combat_log_updated",
		"You reach for your pack... nothing yet.")
	_start_boss_turn()

# ─── BOSS ACTIONS ─────────────────────────────────────────
func _start_boss_turn():
	turn_state = TurnState.BOSS_TURN
	emit_signal("boss_turn_started")
	await get_tree().create_timer(0.8).timeout
	_boss_act()

func _boss_act():
	match boss_next_move:
		"STRIKE":
			_boss_strike()
		"HEAVY":
			_boss_heavy()
		"ENDURE":
			_boss_endure()

	if player_hp <= 0:
		_handle_player_death()
		return

	_boss_choose_next_move()
	turn_state = TurnState.PLAYER_TURN
	emit_signal("player_turn_started")

func _boss_strike():
	var mitigated = player_defense * 2 if player_is_defending else player_defense
	var damage = max(1, boss_damage - mitigated)
	player_hp -= damage
	player_hp = max(0, player_hp)
	GameManager.player_hp = player_hp
	emit_signal("hp_changed", "player", player_hp)
	emit_signal("combat_log_updated",
		"%s strikes for %d damage." % [boss_name, damage])

func _boss_heavy():
	var mitigated = int(player_defense * 1.2) if player_is_defending else 0
	var damage = max(1, int(boss_damage * 1.8) - mitigated)
	player_hp -= damage
	player_hp = max(0, player_hp)
	GameManager.player_hp = player_hp
	emit_signal("hp_changed", "player", player_hp)
	emit_signal("combat_log_updated",
		"%s lands a crushing blow for %d damage!" % [boss_name, damage])

func _boss_endure():
	var heal = 15
	boss_hp = min(boss_max_hp, boss_hp + heal)
	emit_signal("hp_changed", "boss", boss_hp)
	emit_signal("combat_log_updated",
		"%s endures. Recovers %d HP." % [boss_name, heal])

# ─── TELEGRAPH ────────────────────────────────────────────
func _boss_choose_next_move():
	var roll = randi() % 100

	if roll < 55:
		boss_next_move = "STRIKE"
		boss_next_description = "A measured strike. Blockable."
	elif roll < 80:
		boss_next_move = "HEAVY"
		boss_next_description = "A slow, devastating blow. Block helps less."
	else:
		boss_next_move = "ENDURE"
		boss_next_description = "It steadies itself. Preparing."

	emit_signal("telegraph_updated", boss_next_move, boss_next_description)

# ─── ECHO THRESHOLD ───────────────────────────────────────
func _check_echo_threshold():
	if echo_threshold_met:
		return
	if threshold_damage_dealt >= threshold_required_damage:
		echo_threshold_met = true
		GameManager.echo_threshold_met = true
		GameManager.echo_snapshot = {
			"weapon": GameManager.active_loadout.weapon_name,
			"damage": player_damage,
			"hp_at_threshold": player_hp
		}
		# Silent — environment layer will react later
		emit_signal("combat_log_updated", "...")

# ─── DEATH ────────────────────────────────────────────────
func _handle_player_death():
	turn_state = TurnState.ENDED
	var run_continues = GameManager.on_player_death()

	if run_continues:
		emit_signal("loadout_swapped", GameManager.active_loadout)
		emit_signal("combat_log_updated",
			"You fall. The Spire is not done with you.")
		_reset_for_retry()
	else:
		emit_signal("combat_log_updated",
			"You have nothing left. The Spire consumes you.")
		emit_signal("combat_ended", false)

func _reset_for_retry():
	boss_hp = boss_max_hp
	player_hp = GameManager.player_hp
	player_damage = GameManager.active_loadout.weapon_damage
	player_defense = GameManager.active_loadout.armor_defense
	player_is_defending = false
	threshold_damage_dealt = 0
	threshold_turns = 0
	echo_threshold_met = false

	emit_signal("hp_changed", "boss", boss_hp)
	emit_signal("hp_changed", "player", player_hp)
	_boss_choose_next_move()
	turn_state = TurnState.PLAYER_TURN
	emit_signal("player_turn_started")

func _end_combat(player_won):
	turn_state = TurnState.ENDED
	if player_won:
		emit_signal("combat_log_updated",
			"The %s falls. Silence." % boss_name)
	emit_signal("combat_ended", player_won)
