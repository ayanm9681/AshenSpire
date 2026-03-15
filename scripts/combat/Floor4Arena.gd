extends BossArena

func _initialise_ui():
	boss_name_label.text = "THE FALLEN HERO"
	player_name_label.text = "PLAYER"
	boss_hp_bar.max_value = turn_manager.boss_max_hp
	boss_hp_bar.value = turn_manager.boss_hp
	player_hp_bar.max_value = turn_manager.player_max_hp
	player_hp_bar.value = turn_manager.player_hp
	telegraph_label.text = "..."
	combat_log.text = ""

func _on_combat_ended(player_won):
	_set_buttons_active(false)
	if player_won:
		telegraph_label.text = "The Fallen Hero is at rest."
		combat_log.append_text("\n\n— THE SPIRE IS CONQUERED —")
		await _play_death_animation(boss_sprite, true)
		await get_tree().create_timer(2.0).timeout
		# Final floor — go to credits or main menu
		# get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	else:
		telegraph_label.text = "Your run ends here."
		combat_log.append_text("\n\n— THE SPIRE CLAIMS YOU —")
		await _play_hero_final_death()
