# SlashEffect.gd
# A slash that travels from origin to target then disappears
extends Node2D

@onready var slash_sprite = $SlashSprite

# How fast it travels in pixels per second
var travel_speed: float = 1200.0
var target_position: Vector2 = Vector2.ZERO
var is_travelling: bool = true

# Called by BossArena when spawning
func setup(from: Vector2, to: Vector2, direction: String = "right"):
	global_position = from
	target_position = to
	
	## Rotate to face target
	#var angle = from.angle_to_point(to)
	#rotation = angle
	
	# Flip sprite based on travel direction
	if direction == "left":
		slash_sprite.flip_h = false
	else:
		slash_sprite.flip_h = false
	
	slash_sprite.play("slash")
	
	# Connect animation finish — clean up if arrives early
	slash_sprite.animation_finished.connect(_on_animation_finished)

func _process(delta):
	if not is_travelling:
		return
	
	# Move toward target
	var direction = (target_position - global_position)
	var distance = direction.length()
	
	# Close enough — arrived at target
	if distance < 20.0:
		is_travelling = false
		emit_signal("arrived")
		queue_free()
		return
	
	# Move this frame
	global_position += direction.normalized() * travel_speed * delta

func _on_animation_finished():
	if not is_travelling:
		queue_free()  # Delete itself when animation ends

# Signal — BossArena listens for this to trigger hit effects
signal arrived
