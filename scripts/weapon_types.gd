# weapon_types.gd
extends Node

# Dictionary of weapon types with their properties
var types = {
	"sword": {
		"name": "Sword",
		"base_damage": 12,
		"attack_speed": 1.2,
		"knockback_force": 600,
		"script_path": "res://scripts/sword.gd",
		"primary_stat": "strength"
	},
	"staff": {
		"name": "Magic Staff",
		"base_damage": 8,
		"attack_speed": 0.8,
		"knockback_force": 400,
		"script_path": "res://scripts/magic_staff.gd",
		"primary_stat": "intelligence"
	}
	# Add more weapons as needed
}

func get_weapon(weapon_id: String):
	if types.has(weapon_id):
		var weapon_info = types[weapon_id]
		var weapon = load(weapon_info.script_path).new()
		
		# Initialize with base properties if the weapon script supports it
		if weapon.has_method("set_properties"):
			weapon.set_properties(weapon_info)
			
		return weapon
	
	# Return default if weapon not found
	return load("res://scripts/sword.gd").new()
