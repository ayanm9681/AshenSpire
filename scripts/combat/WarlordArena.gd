# WarlordArena.gd
extends BossArena

func _initialise_ui():
	boss_name_label.text = "THE WARLORD"
	player_name_label.text = "PLAYER"
	boss_hp_bar.max_value = turn_manager.boss_max_hp
	boss_hp_bar.value = turn_manager.boss_hp
	player_hp_bar.max_value = turn_manager.player_max_hp
	player_hp_bar.value = turn_manager.player_hp
	telegraph_label.text = "..."
	combat_log.text = ""
