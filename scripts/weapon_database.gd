# weapon_database.gd - Add this as an autoload/singleton
extends Node

# Dictionary of all weapons
var weapons = {
	"sword": {
		"name": "Sword",
		"weapon_type": "sword",
		"damage": 12,
		"knockback_force": 600.0,
		"attack_speed": 1.2,
		"attack_range": Vector2(50, 30),
		"description": "Standard sword with good damage and speed",
		"effects": [],
		"tier": 0  # 0=common, 1=uncommon, 2=rare, 3=epic, 4=legendary
	},
	"staff": {
		"name": "Magic Staff",
		"weapon_type": "staff",
		"damage": 8,
		"knockback_force": 400.0,
		"attack_speed": 0.8,
		"attack_range": Vector2(60, 30),
		"description": "Magical staff with medium range",
		"effects": [],
		"tier": 0
	},
	"great_sword": {
		"name": "Great Sword",
		"weapon_type": "sword",
		"damage": 18,
		"knockback_force": 700.0,
		"attack_speed": 0.8,
		"attack_range": Vector2(60, 40),
		"description": "Heavy sword with high damage but slow speed",
		"effects": [],
		"tier": 1
	},
	"fire_staff": {
		"name": "Fire Staff",
		"weapon_type": "staff",
		"damage": 10,
		"knockback_force": 450.0,
		"attack_speed": 0.9,
		"attack_range": Vector2(70, 35),
		"description": "Staff imbued with fire magic",
		"effects": ["fire"],
		"tier": 1
	}
	# Add more weapons as needed
}

# Tier multipliers for damage
var tier_multipliers = [1.0, 1.3, 1.7, 2.2, 3.0]

# Get weapon data by ID
func get_weapon(weapon_id: String) -> Dictionary:
	if weapons.has(weapon_id):
		var data = weapons[weapon_id].duplicate(true)  # Deep copy
		
		# Apply tier multiplier to damage
		if data.has("tier") and data.has("damage"):
			var tier = data.tier
			if tier >= 0 and tier < tier_multipliers.size():
				data.base_damage = data.damage  # Store original damage
				data.damage = round(data.damage * tier_multipliers[tier])
		
		return data
	else:
		# Return default data if weapon not found
		return {
			"name": "Basic Weapon",
			"weapon_type": "sword",
			"damage": 10,
			"knockback_force": 500.0,
			"attack_speed": 1.0,
			"attack_range": Vector2(50, 30),
			"description": "A simple weapon",
			"effects": [],
			"tier": 0
		}

# Get all weapons of a specific type
func get_weapons_by_type(weapon_type: String) -> Array:
	var result = []
	for id in weapons.keys():
		if weapons[id].weapon_type == weapon_type:
			result.append(id)
	return result

# Get all weapons at or below a specific tier
func get_weapons_by_tier(max_tier: int) -> Array:
	var result = []
	for id in weapons.keys():
		if weapons[id].tier <= max_tier:
			result.append(id)
	return result
