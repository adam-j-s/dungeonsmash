# Weapon_database - JSON version
extends Node

# Dictionary of all weapons
var weapons = {}

# Tier multipliers for damage
var tier_multipliers = [1.0, 1.3, 1.7, 2.2, 3.0]

func _ready():
	# Load hardcoded weapons first as fallback
	initialize_default_weapons()
	
	# Try to load from JSON
	var success = load_weapons_from_json("res://data/weapons.json")
	if success:
		print("Successfully loaded weapons from JSON. Total weapons: " + str(weapons.size()))
	else:
		print("Failed to load weapons from JSON, using default weapons")

# Default weapon initialization (keep your current weapons as fallback)
func initialize_default_weapons():
	weapons = {
		"sword": {
			"name": "Sword",
			"weapon_type": "sword",
			"weapon_style": "melee",
			"stats": {
				"damage": 12,
				"knockback_force": 600.0,
				"attack_speed": 1.2,
				"cooldown": 0.833
			},
			"range": {
				"x": 50,
				"y": 30
			},
			"description": "Standard sword with good damage and speed",
			"effects": [],
			"tier": 0,  # 0=common, 1=uncommon, 2=rare, 3=epic, 4=legendary
			"behaviors": [],
			"flags": {
				"friendly_fire": false,
				"allow_self_damage": false
			},
			"sprite_path": "res://assets/sprites/weapons/sword/basic_sword.png"
		},
		"staff": {
			"name": "Magic Staff",
			"weapon_type": "staff",
			"weapon_style": "projectile",
			"stats": {
				"damage": 8,
				"knockback_force": 400.0,
				"attack_speed": 0.8,
				"cooldown": 1.25
			},
			"range": {
				"x": 60,
				"y": 30
			},
			"projectile": {
				"speed": 400,
				"lifetime": 0.8
			},
			"description": "Magical staff with medium range",
			"effects": [],
			"tier": 0,
			"behaviors": [],
			"flags": {
				"friendly_fire": false,
				"allow_self_damage": false
			},
			"sprite_path": "res://assets/weapons/staff/magic_staff.png"
		}
	}

func load_weapons_from_json(file_path):
	if !FileAccess.file_exists(file_path):
		print("ERROR: Weapons JSON not found at: " + file_path)
		return false
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if !file:
		print("ERROR: Could not open weapons JSON file")
		return false
	
	# Read the entire file as text
	var json_text = file.get_as_text()
	file.close()
	
	# Parse JSON
	var json = JSON.new()
	var error = json.parse(json_text)
	
	if error != OK:
		print("JSON Parse Error: " + json.get_error_message())
		return false
	
	var data = json.get_data()
	
	# Validate data format
	if !data.has("weapons") or typeof(data.weapons) != TYPE_ARRAY:
		print("ERROR: Invalid JSON format - missing weapons array")
		return false
	
	# Clear existing weapons
	weapons.clear()
	
	# Process each weapon
	for weapon_data in data.weapons:
		if !weapon_data.has("id"):
			print("WARNING: Skipping weapon without ID")
			continue
		
		var weapon_id = weapon_data.id
		
		# Process the weapon into a flattened dictionary for compatibility
		var processed_weapon = process_json_weapon(weapon_data)
		weapons[weapon_id] = processed_weapon
	
	print("Successfully loaded " + str(weapons.size()) + " weapons from JSON")
	return true

# Process a JSON weapon into a compatible dictionary
func process_json_weapon(json_weapon):
	var weapon = {}
	
	# Store the original JSON structure
	weapon.json_data = json_weapon
	
	# Basic properties
	weapon.weapon_id = json_weapon.id
	weapon.name = json_weapon.name
	weapon.weapon_type = json_weapon.weapon_type
	weapon.weapon_style = json_weapon.weapon_style
	weapon.tier = json_weapon.tier
	weapon.description = json_weapon.get("description", "")
	weapon.sprite_path = json_weapon.get("sprite_path", "")
	
	# Stats
	if json_weapon.has("stats"):
		weapon.damage = json_weapon.stats.get("damage", 10)
		weapon.attack_speed = json_weapon.stats.get("attack_speed", 1.0)
		weapon.cooldown = json_weapon.stats.get("cooldown", 1.0)
		weapon.knockback_force = json_weapon.stats.get("knockback_force", 500)
	
	# Range
	if json_weapon.has("range"):
		weapon.attack_range_x = json_weapon.range.get("x", 50)
		weapon.attack_range_y = json_weapon.range.get("y", 30)
		weapon.attack_range = Vector2(weapon.attack_range_x, weapon.attack_range_y)
	
	# Projectile
	if json_weapon.has("projectile") and json_weapon.projectile != null:
		weapon.projectile_speed = json_weapon.projectile.get("speed", 0)
		weapon.projectile_lifetime = json_weapon.projectile.get("lifetime", 0)
	
	# Effects
	weapon.effects = json_weapon.get("effects", [])
	
	# Store behaviors in a way that's compatible with both formats
	weapon.behaviors = json_weapon.get("behaviors", [])
	
	# Legacy behavior columns for compatibility
	for i in range(min(json_weapon.behaviors.size(), 4)):
		var behavior = json_weapon.behaviors[i]
		weapon["behavior" + str(i+1)] = behavior.type
		
		# Convert params to string format
		var param_strings = []
		for key in behavior.params:
			param_strings.append(key + "=" + str(behavior.params[key]))
		
		if param_strings.size() > 0:
			weapon["behavior" + str(i+1) + "_params"] = "|".join(param_strings)
	
	# Flags
	if json_weapon.has("flags"):
		weapon.friendly_fire = json_weapon.flags.get("friendly_fire", false)
		weapon.allow_self_damage = json_weapon.flags.get("allow_self_damage", false)
	
	return weapon

# Get weapon data by ID (with JSON structure)
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
			"weapon_style": "melee",
			"stats": {
				"damage": 10,
				"knockback_force": 500.0,
				"attack_speed": 1.0,
				"cooldown": 1.0
			},
			"range": {
				"x": 50,
				"y": 30
			},
			"description": "A simple weapon",
			"effects": [],
			"tier": 0,
			"behaviors": [],
			"flags": {
				"friendly_fire": false,
				"allow_self_damage": false
			}
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

# Get weapon effects
func get_effect(effect_name: String) -> Dictionary:
	# Define effects data - you could expand this into a full dictionary like weapons
	var effects_data = {
		"fire": {
			"damage_over_time": 2,
			"duration": 3.0,
			"visual_color": Color(1.0, 0.5, 0.0)
		},
		"ice": {
			"slow_factor": 0.5,
			"duration": 2.0,
			"visual_color": Color(0.5, 0.8, 1.0)
		},
		"lightning": {
			"chain_damage": 5,
			"chain_range": 100.0,
			"visual_color": Color(0.7, 0.7, 1.0)
		},
		"poison": {
			"damage_over_time": 1,
			"duration": 5.0,
			"visual_color": Color(0.4, 0.8, 0.4)
		}
		# Add more effects as needed
	}
	
	if effects_data.has(effect_name):
		return effects_data[effect_name]
	return {}
