# GameManager.gd
# Global singleton — survives all scene changes
# Access from anywhere: GameManager.player_hp etc.
extends Node

# ─── PLAYER STATE ─────────────────────────────────────────
var player_hp: int = 100
var player_max_hp: int = 100
var current_floor: int = 1

# ─── ACTIVE LOADOUT ───────────────────────────────────────
var active_loadout: LoadoutData = null

# ─── BACKUP VAULT ─────────────────────────────────────────
var backup_loadouts: Array = []

# ─── ECHO SYSTEM ──────────────────────────────────────────
var echo_threshold_met: bool = false
var echo_snapshot: Dictionary = {}

# ─── READY ────────────────────────────────────────────────
func _ready():
	_initialise_loadouts()

func _initialise_loadouts():
	# Active loadout — Excalibur
	active_loadout = LoadoutData.new()
	active_loadout.weapon_name = "EXCALIBUR"
	active_loadout.weapon_damage = 22
	active_loadout.armor_name = "Leather Plate"
	active_loadout.armor_defense = 8
	active_loadout.consumables = ["Ember Flask", "Whetstone"]
	active_loadout.weapon_type = LoadoutData.WeaponType.EXCALIBUR  # ← add this

	# Backup slot 1 — Durandal
	var backup1 = LoadoutData.new()
	backup1.weapon_name = "DURANDAL"
	backup1.weapon_damage = 16
	backup1.armor_name = "Worn Padding"
	backup1.armor_defense = 5
	backup1.consumables = ["Ember Flask"]
	backup1.weapon_type = LoadoutData.WeaponType.DURANDAL           # ← add this
	backup_loadouts.append(backup1)

	# Backup slot 2 — Sunsword
	var backup2 = LoadoutData.new()
	backup2.weapon_name = "SUNSWORD"
	backup2.weapon_damage = 12
	backup2.armor_name = "Torn Cloth"
	backup2.armor_defense = 3
	backup2.consumables = []
	backup2.weapon_type = LoadoutData.WeaponType.SUNSWORD           # ← add this
	backup_loadouts.append(backup2)

# ─── DEATH HANDLER ────────────────────────────────────────
# Returns true if run continues, false if run is over
func on_player_death() -> bool:
	if backup_loadouts.is_empty():
		return false

	# Swap to next backup
	active_loadout = backup_loadouts.pop_front()
	player_hp = player_max_hp
	echo_threshold_met = false
	echo_snapshot = {}
	return true

# ─── HELPERS ──────────────────────────────────────────────
func has_backups() -> bool:
	return not backup_loadouts.is_empty()

func backup_count() -> int:
	return backup_loadouts.size()

func reset_run():
	player_hp = player_max_hp
	current_floor = 1
	echo_threshold_met = false
	echo_snapshot = {}
	_initialise_loadouts()
