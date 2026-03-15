extends TurnManager

func _ready() -> void:
	boss_max_hp = 3200
	boss_hp = 3200
	boss_damage = 26
	boss_defense = 12
	super._ready()
