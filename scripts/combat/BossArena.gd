# BossArena.gd
extends Node2D

# ─── NODE REFERENCES ──────────────────────────────────────
@onready var boss_hp_bar = $BossContainer/BossHealthBar
@onready var boss_name_label = $BossContainer/BossName
@onready var boss_sprite = $BossContainer/BossSprite        # AnimatedSprite2D
@onready var hero_sprite = $PlayerContainer/HeroSprite      # AnimatedSprite2D
@onready var player_hp_bar = $PlayerContainer/PlayerHealthBar
@onready var player_name_label = $PlayerContainer/PlayerName
@onready var telegraph_label = $TelegraphBox/TelegraphLabel
@onready var combat_log = $CombatLog
@onready var attack_btn = $ActionMenu/AttackButton
@onready var defend_btn = $ActionMenu/DefendButton
@onready var item_btn = $ActionMenu/ItemButton
@onready var turn_manager = $TurnManager

# ─── READY ────────────────────────────────────────────────
func _ready():
	_connect_signals()
	_connect_buttons()
	_initialise_ui()
	_start_idle_animations()

func _start_idle_animations():
	boss_sprite.play("idle")
	hero_sprite.play("idle")

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
	defend_btn.pressed.connect(_on_defend_pressed)
	item_btn.pressed.connect(_on_item_pressed)

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
func _on_boss_attack_started():
	play_boss_attack()
	
func _on_hp_changed(entity, new_hp):
	if entity == "boss":
		boss_hp_bar.value = new_hp
		hit_pause(0.07)
		flash_sprite(boss_sprite)
		play_boss_hurt()
	elif entity == "player":
		player_hp_bar.value = new_hp
		hit_pause(0.05)
		flash_sprite(hero_sprite)
		play_hero_hurt()

func _on_log_updated(message):
	combat_log.append_text("\n" + message)

func _on_telegraph_updated(move, description):
	telegraph_label.text = "NEXT: [%s] — %s" % [move, description]

func _on_player_turn_started():
	_set_buttons_active(true)

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
	combat_log.append_text(
		"\nEquipping: %s (DMG: %d)" % [
			new_loadout.weapon_name,
			new_loadout.weapon_damage
		])

# ─── BUTTON HANDLERS ──────────────────────────────────────
func _on_attack_pressed():
	play_hero_attack()                              # ← hero attacks
	turn_manager.player_act(TurnManager.PlayerAction.ATTACK)

func _on_defend_pressed():
	turn_manager.player_act(TurnManager.PlayerAction.DEFEND)

func _on_item_pressed():
	turn_manager.player_act(TurnManager.PlayerAction.USE_ITEM)

# ─── HELPERS ──────────────────────────────────────────────
func _set_buttons_active(active):
	attack_btn.disabled = not active
	defend_btn.disabled = not active
	item_btn.disabled = not active

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
	await get_tree().create_timer(duration * 0.05).timeout
	Engine.time_scale = 1.0

func flash_sprite(sprite: AnimatedSprite2D):
	sprite.modulate = Color.WHITE
	await get_tree().create_timer(0.05).timeout
	sprite.modulate = Color(1, 0.3, 0.3)
	await get_tree().create_timer(0.08).timeout
	sprite.modulate = Color.WHITE
	
# ─── ANIMATION SYSTEM ─────────────────────────────────────
func play_hero_attack():
	hero_sprite.play("attack")
	# Return to idle when attack animation finishes
	await hero_sprite.animation_finished
	hero_sprite.play("idle")

func play_boss_attack():
	boss_sprite.play("attack")
	await boss_sprite.animation_finished
	boss_sprite.play("idle")

func play_boss_hurt():
	boss_sprite.play("hurt")
	await boss_sprite.animation_finished
	boss_sprite.play("idle")

func play_hero_hurt():
	hero_sprite.play("hurt")
	await hero_sprite.animation_finished
	hero_sprite.play("idle")
	

	
