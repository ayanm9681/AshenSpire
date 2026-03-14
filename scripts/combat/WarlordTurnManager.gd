# WarlordTurnManager.gd
extends TurnManager

func _ready() -> void:
	boss_max_hp = 2000
	boss_hp = 2000
	boss_damage = 18
	boss_defense = 8
	super._ready()
