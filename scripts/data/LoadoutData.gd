# LoadoutData.gd
# Represents one complete loadout slot in the Vault
# Used by GameManager for active loadout and all backups
class_name LoadoutData
extends Resource

# ─── WEAPON ───────────────────────────────────────────────
var weapon_name: String = ""
var weapon_damage: int = 0
var weapon_durability: int = 100
var weapon_max_durability: int = 100

# ─── ARMOR ────────────────────────────────────────────────
var armor_name: String = ""
var armor_defense: int = 0
var armor_durability: int = 100

# ─── CONSUMABLES ──────────────────────────────────────────
var consumables: Array = []

# ─── HELPERS ──────────────────────────────────────────────

# Is this slot empty — nothing equipped
func is_empty() -> bool:
	return weapon_name == "" and armor_name == ""

# Is weapon broken
func weapon_broken() -> bool:
	return weapon_durability <= 0

# Degrade weapon on use
func degrade_weapon(amount: int = 2):
	weapon_durability -= amount
	weapon_durability = max(0, weapon_durability)

# Get weapon condition as text
func weapon_condition() -> String:
	var pct = float(weapon_durability) / float(weapon_max_durability)
	if pct > 0.6:
		return "Good"
	elif pct > 0.3:
		return "Worn"
	elif pct > 0.1:
		return "Degraded"
	elif pct > 0.0:
		return "Critical"
	else:
		return "Broken"

# Effective damage — reduced by condition
func effective_damage() -> int:
	var pct = float(weapon_durability) / float(weapon_max_durability)
	if pct > 0.6:
		return weapon_damage
	elif pct > 0.3:
		return int(weapon_damage * 0.85)
	elif pct > 0.1:
		return int(weapon_damage * 0.65)
	elif pct > 0.0:
		return int(weapon_damage * 0.40)
	else:
		return max(1, int(weapon_damage * 0.15)) # Broken — barely usable

# One line summary for UI display
func get_summary() -> String:
	if is_empty():
		return "Empty"
	return "%s / %s [%s]" % [weapon_name, armor_name, weapon_condition()]
