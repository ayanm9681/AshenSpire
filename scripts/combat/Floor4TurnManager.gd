extends TurnManager

func _ready() -> void:
	boss_max_hp = 4500
	boss_hp = 4500
	boss_damage = 32
	boss_defense = 15
	super._ready()
