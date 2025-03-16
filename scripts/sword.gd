extends Weapon

func _ready():
	super._ready()
	weapon_name = "Basic Sword"
	damage = 15
	knockback_force = 600.0
	attack_speed = 1.2
	attack_range = Vector2(60, 40)

func attack_effects():
	# Play sword swing animation/sound
	print("Sword swing!")
	
	# You could add particles or animation here
	
func on_hit_effects(target):
	# Sword-specific hit effects
	print("Sword hit effect!")
