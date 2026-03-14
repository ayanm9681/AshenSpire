# BossEffects.gd
class_name BossEffects
extends Node2D

@onready var lightning = $LightningEffect
@onready var green_slash = $GreenSlashEffect
@onready var sunburst = $SunburstEffect
@onready var impact = $ImpactBurst
@onready var impactdown = $ImpactBurstDown
@onready var crit_burst = $CritBurst

func _ready():
	for child in get_children():
		child.visible = false
	
func play_effect(effect_name: String) -> void:
	var effect: AnimatedSprite2D
	match effect_name:
		"lightning": effect = lightning
		"green_slash": effect = green_slash
		"sunburst": effect = sunburst
		"impact": effect = impact
		"impactdown": effect = impactdown
		"crit_burst": effect = crit_burst
		_: return
	effect.visible = true
	effect.play("default")
	await effect.animation_finished
	effect.visible = false
