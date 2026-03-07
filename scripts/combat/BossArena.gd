# BossArena.gd
class_name BossArena
extends Node2D

# ─── NODE REFERENCES ──────────────────────────────────────
@onready var boss_hp_bar = $BossContainer/BossHealthBar
@onready var boss_name_label = $BossContainer/BossName
@onready var boss_sprite = $BossContainer/BossSprite        # AnimatedSprite2D    # AnimatedSprite2D
@onready var player_hp_bar = $PlayerContainer/PlayerHealthBar
@onready var player_name_label = $PlayerContainer/PlayerName
@onready var telegraph_label = $TelegraphBox/TelegraphLabel
@onready var combat_log = $CombatLog
@onready var attack_btn = $ActionMenu/AttackButton
@onready var heavy_attack_btn = $ActionMenu/HeavyAttackButton
@onready var defend_btn = $ActionMenu/DefendButton
@onready var item_btn = $ActionMenu/ItemButton
@onready var turn_manager = $TurnManager
@onready var hero_sprite2 = $PlayerContainer/HeroSprite2    # sword hero
@onready var sword_attack_btn = $ActionMenu/SwordAttackButton
@onready var sword_heavy_btn = $ActionMenu/SwordHeavyButton
var active_hero: AnimatedSprite2D

const RUN_SPEED: float = 900.0
const BOSS_NORMAL_ATTACK_ANIMATION: String = "attack"
const BOSS_HEAVY_ATTACK_ANIMATION: String = "heavyattack"

var _hero_start_position: Vector2
var _boss_start_position: Vector2
var _arena_base_position: Vector2
var _is_shaking: bool = false

# ─── READY ────────────────────────────────────────────────
func _ready():
	_connect_signals()
	_connect_buttons()
	_initialise_ui()
	_apply_ui_style()
	await get_tree().process_frame   # wait for layout
	active_hero = hero_sprite2
	hero_sprite2.visible = true
	attack_btn.visible = true
	heavy_attack_btn.visible = true
	sword_attack_btn.visible = true
	sword_heavy_btn.visible = true
	_hero_start_position = hero_sprite2.global_position
	_boss_start_position = boss_sprite.global_position
	_arena_base_position = global_position
	_start_idle_animations()

func _start_idle_animations():
	boss_sprite.play("idle")
	active_hero.play("idle")

func _connect_signals():
	turn_manager.hp_changed.connect(_on_hp_changed)
	turn_manager.boss_attack_started.connect(_on_boss_attack_started)
	turn_manager.combat_log_updated.connect(_on_log_updated)
	turn_manager.telegraph_updated.connect(_on_telegraph_updated)
	turn_manager.player_turn_started.connect(_on_player_turn_started)
	turn_manager.boss_turn_started.connect(_on_boss_turn_started)
	turn_manager.combat_ended.connect(_on_combat_ended)
	turn_manager.loadout_swapped.connect(_on_loadout_swapped)

func _connect_buttons():
	attack_btn.pressed.connect(_on_attack_pressed)
	heavy_attack_btn.pressed.connect(_on_heavy_attack_pressed)
	defend_btn.pressed.connect(_on_defend_pressed)
	item_btn.pressed.connect(_on_item_pressed)
	sword_attack_btn.pressed.connect(_on_sword_attack_pressed)
	sword_heavy_btn.pressed.connect(_on_sword_heavy_pressed)

func _initialise_ui():
	boss_name_label.text = "THE WARDEN"
	player_name_label.text = "PLAYER"
	boss_hp_bar.max_value = turn_manager.boss_max_hp
	boss_hp_bar.value = turn_manager.boss_hp
	player_hp_bar.max_value = turn_manager.player_max_hp
	player_hp_bar.value = turn_manager.player_hp
	telegraph_label.text = "..."
	combat_log.text = ""

# ─── SIGNAL HANDLERS ──────────────────────────────────────
var _boss_animating: bool = false

func _on_boss_attack_started():
	_boss_animating= true
	await play_boss_attack()       # ← await it
	_boss_animating= false

func _on_hp_changed(entity, new_hp):
	if entity == "boss":
		boss_hp_bar.value = new_hp
		await _screen_shake(18.0, 0.2)
		await hit_pause(0.07)
		await flash_sprite(boss_sprite)
		await play_boss_hurt()     # ← await it
	elif entity == "player":
		player_hp_bar.value = new_hp
		await _screen_shake(14.0, 0.18)
		await hit_pause(0.05)
		await flash_sprite(active_hero)
		await play_hero_hurt()     # ← await it

func _on_log_updated(message):
	combat_log.append_text("\n" + message)

func _on_telegraph_updated(move, description):
	telegraph_label.text = "NEXT: [%s] — %s" % [move, description]

func _on_player_turn_started():
	_set_buttons_active(true)
	_start_idle_animations()

func _on_boss_turn_started():
	_set_buttons_active(false)

func _on_combat_ended(player_won):
	_set_buttons_active(false)
	if player_won:
		telegraph_label.text = "Victory. The Warden falls."
		combat_log.append_text("\n\n— YOUR RUN CONTINUES —")
	else:
		telegraph_label.text = "Your run ends here."
		combat_log.append_text("\n\n— THE SPIRE CLAIMS YOU —")

func _on_loadout_swapped(new_loadout):
	active_hero = hero_sprite2   # always hero_sprite2 now

	attack_btn.visible = true
	heavy_attack_btn.visible = true
	sword_attack_btn.visible = true
	sword_heavy_btn.visible = true

	_hero_start_position = active_hero.global_position
	active_hero.play("idle")

	combat_log.append_text(
		"\nEquipping: %s (DMG: %d)" % [
			new_loadout.weapon_name,
			new_loadout.weapon_damage
		])

# ─── BUTTON HANDLERS ──────────────────────────────────────

var _hero_animating: bool = false

func _on_attack_pressed():
	if _hero_animating:
		return
	_hero_animating= true
	_set_buttons_active(false)
	await play_hero_attack()
	_hero_animating= false                             # ← hero attacks
	turn_manager.player_act(TurnManager.PlayerAction.ATTACK)

	
func _on_heavy_attack_pressed():
	if _hero_animating:
		return
	_hero_animating= true
	_set_buttons_active(false) 
	await play_hero_heavy_attack()
	_hero_animating = false
	turn_manager.player_act(TurnManager.PlayerAction.HEAVY_ATTACK)
	
func _on_sword_attack_pressed():
	if _hero_animating:
		return
	_hero_animating = true
	_set_buttons_active(false)
	var anim = GameManager.active_loadout.get_attack_animation()
	await _execute_run_attack(active_hero, boss_sprite, _hero_start_position, anim)
	_hero_animating = false
	turn_manager.player_act(TurnManager.PlayerAction.SWORD_ATTACK)

func _on_sword_heavy_pressed():
	if _hero_animating:
		return
	_hero_animating = true
	_set_buttons_active(false)
	var anim = GameManager.active_loadout.get_heavy_animation()
	await _execute_run_attack(active_hero, boss_sprite, _hero_start_position, anim)
	_hero_animating = false
	turn_manager.player_act(TurnManager.PlayerAction.SWORD_HEAVY)

func _on_defend_pressed():
	turn_manager.player_act(TurnManager.PlayerAction.DEFEND)

func _on_item_pressed():
	turn_manager.player_act(TurnManager.PlayerAction.USE_ITEM)

# ─── HELPERS ──────────────────────────────────────────────
func _set_buttons_active(active):
	attack_btn.disabled = not active
	heavy_attack_btn.disabled = not active
	defend_btn.disabled = not active
	item_btn.disabled = not active
	sword_attack_btn.disabled = not active
	sword_heavy_btn.disabled = not active

func _apply_ui_style():
	boss_hp_bar.self_modulate = Color(1.0, 0.92, 0.92)
	player_hp_bar.self_modulate = Color(0.9, 1.0, 0.95)

	boss_hp_bar.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	player_hp_bar.add_theme_color_override("font_color", Color(0.92, 1.0, 0.95))

	boss_hp_bar.add_theme_stylebox_override("fill", _make_bar_style(Color(0.8, 0.18, 0.25), Color(0.5, 0.05, 0.12)))
	boss_hp_bar.add_theme_stylebox_override("background", _make_bar_style(Color(0.16, 0.05, 0.08), Color(0.3, 0.1, 0.15)))

	player_hp_bar.add_theme_stylebox_override("fill", _make_bar_style(Color(0.19, 0.75, 0.4), Color(0.05, 0.38, 0.2)))
	player_hp_bar.add_theme_stylebox_override("background", _make_bar_style(Color(0.04, 0.14, 0.09), Color(0.07, 0.2, 0.12)))

	_apply_button_style(attack_btn, Color(0.85, 0.22, 0.22), Color(1.0, 0.67, 0.2))
	_apply_button_style(heavy_attack_btn, Color(0.62, 0.18, 0.78), Color(0.32, 0.15, 0.7))
	_apply_button_style(defend_btn, Color(0.15, 0.47, 0.88), Color(0.09, 0.31, 0.67))
	_apply_button_style(item_btn, Color(0.94, 0.64, 0.16), Color(0.88, 0.42, 0.08))

func _make_bar_style(fill_color: Color, border_color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	return style

func _apply_button_style(button: Button, primary: Color, accent: Color):
	button.add_theme_color_override("font_color", Color(0.98, 0.98, 0.98))
	button.add_theme_color_override("font_focus_color", Color(1.0, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.7, 0.7, 0.7, 0.8))

	button.add_theme_stylebox_override("normal", _make_button_style(primary, accent, 10, 2))
	button.add_theme_stylebox_override("hover", _make_button_style(primary.lightened(0.2), accent.lightened(0.15), 10, 2))
	button.add_theme_stylebox_override("pressed", _make_button_style(primary.darkened(0.18), accent.darkened(0.2), 10, 2))
	button.add_theme_stylebox_override("disabled", _make_button_style(Color(0.25, 0.25, 0.25, 0.65), Color(0.12, 0.12, 0.12, 0.8), 10, 1))

func _make_button_style(fill_color: Color, border_color: Color, corner_radius: int, border_size: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	style.border_width_left = border_size
	style.border_width_top = border_size
	style.border_width_right = border_size
	style.border_width_bottom = border_size
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 3
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style

func _screen_shake(strength: float, duration: float):
	if _is_shaking:
		return

	_is_shaking = true
	var elapsed := 0.0
	while elapsed < duration:
		var damper := 1.0 - (elapsed / duration)
		global_position = _arena_base_position + Vector2(
			randf_range(-strength, strength) * damper,
			randf_range(-strength * 0.5, strength * 0.5) * damper
		)
		await get_tree().process_frame
		elapsed += get_process_delta_time()

	global_position = _arena_base_position
	_is_shaking = false

# ─── VISUAL EFFECTS ───────────────────────────────────────
func flash_boss_hit():
	hit_pause(0.07)                             # ← freeze first
	boss_sprite.modulate = Color.WHITE
	await get_tree().create_timer(0.05).timeout
	boss_sprite.modulate = Color(1, 0.3, 0.3)
	await get_tree().create_timer(0.08).timeout
	boss_sprite.modulate = Color.WHITE        # Back to normal

func flash_player_hit():
	await get_tree().create_timer(0.05).timeout
	# We'll add player sprite here later
	pass
	
# ─── HIT EFFECTS ──────────────────────────────────────────
func hit_pause(duration: float = 0.07):
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0

func flash_sprite(sprite: AnimatedSprite2D):
	sprite.modulate = Color.WHITE
	await get_tree().create_timer(0.05).timeout
	sprite.modulate = Color(1, 0.3, 0.3)
	await get_tree().create_timer(0.08).timeout
	sprite.modulate = Color.WHITE
	
# ─── ANIMATION SYSTEM ─────────────────────────────────────
func play_hero_attack():
	await _execute_run_attack(active_hero, boss_sprite, _hero_start_position, "attack")
	
func play_hero_heavy_attack():
	await _execute_run_attack(active_hero, boss_sprite, _hero_start_position, "heavyattack")

func play_boss_attack():
	if turn_manager.boss_next_move == "ENDURE":
		# Just play the animation in place, no running
		boss_sprite.play("idle")  # or a dedicated "endure" animation if you have one
		await get_tree().create_timer(0.6).timeout
		boss_sprite.play("idle")
		return

	var boss_attack_animation := _get_boss_attack_animation(turn_manager.boss_next_move)
	await _execute_run_attack(boss_sprite, active_hero, _boss_start_position, boss_attack_animation)

func _get_boss_attack_animation(next_move: String) -> String:
	var normalized_move := next_move.strip_edges().to_upper()
	if normalized_move in ["HEAVY", "MASSIVE OVERHEAD SLASH", "MASSIVE OVERHEAD STRIKE"]:
		return BOSS_HEAVY_ATTACK_ANIMATION
	if normalized_move in ["STRIKE", "QUICKSLASH", "QUICK SLASH"]:
		return BOSS_NORMAL_ATTACK_ANIMATION
	return BOSS_NORMAL_ATTACK_ANIMATION

func play_boss_hurt():
	boss_sprite.play("hurt")
	await get_tree().create_timer(0.3).timeout
	boss_sprite.play("idle")

func play_hero_hurt():
	active_hero.play("hurt")
	await get_tree().create_timer(0.3).timeout
	active_hero.play("idle")

func _execute_run_attack(attacker: AnimatedSprite2D, target: AnimatedSprite2D, start_position: Vector2, attack_animation: String):
	var target_position = _combat_target_position(attacker, target)
	await _run_to_position(attacker, target_position)
	attacker.play(attack_animation)
	await attacker.animation_finished
	await _run_to_position(attacker, start_position)
	attacker.play("idle")

func _combat_target_position(attacker: AnimatedSprite2D, target: AnimatedSprite2D) -> Vector2:
	var direction = sign(target.global_position.x - attacker.global_position.x)
	if direction == 0:
		direction = 1
	return Vector2(target.global_position.x - direction * 110.0, attacker.global_position.y)

func _run_to_position(sprite: AnimatedSprite2D, destination: Vector2):
	var distance = sprite.global_position.distance_to(destination)
	if distance <= 1.0:
		return

	sprite.play("run")
	var duration = distance / RUN_SPEED
	var tween = create_tween()
	tween.tween_property(sprite, "global_position", destination, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
