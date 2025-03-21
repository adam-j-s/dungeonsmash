# weapon_database.gd - Add this as an autoload/singleton
extends Node

# Dictionary of all weapons
var weapons = {}

# Tier multipliers for damage
var tier_multipliers = [1.0, 1.3, 1.7, 2.2, 3.0]

func _ready():
	# Load hardcoded weapons first as fallback
	initialize_default_weapons()
	
	# Then try to load from CSV
	var success = load_weapons_from_csv("res://data/weapons.csv")
	if success:
		print("Successfully loaded weapons from CSV. Total weapons: " + str(weapons.size()))
	else:
		print("Failed to load weapons from CSV, using default weapons")

# Default weapon initialization (keep your current weapons as fallback)
func initialize_default_weapons():
	weapons = {
		"sword": {
			"name": "Sword",
			"weapon_type": "sword",
			"weapon_style": "melee",
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
			"weapon_style": "projectile",
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
			"weapon_style": "melee",
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
			"weapon_style": "projectile",
			"damage": 10,
			"knockback_force": 450.0,
			"attack_speed": 0.9,
			"attack_range": Vector2(70, 35),
			"description": "Staff imbued with fire magic",
			"effects": ["fire"],
			"tier": 1
		}
	}

func load_weapons_from_csv(file_path):
	if !FileAccess.file_exists(file_path):
		print("ERROR: Weapons CSV not found at: " + file_path)
		return false
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if !file:
		print("ERROR: Could not open weapons CSV file")
		return false
	
	# Read header row but don't process it as a weapon
	var headers = file.get_csv_line()
	
	# Extract the actual field names without descriptions
	var cleaned_headers = []
	for header in headers:
		# Extract just the field name before any space or parenthesis
		var clean_name = header.strip_edges().split(" ")[0].split("(")[0]
		cleaned_headers.append(clean_name)
	
	print("Processing CSV with fields: ", cleaned_headers)
	
	# Define field type categories for easier processing
	var int_fields = ["damage", "tier", "bounce_count", "projectile_count", "piercing"]
	var float_fields = ["attack_speed", "knockback_force", "projectile_speed", "projectile_lifetime", 
						"homing_strength", "gravity_factor", "projectile_spread", "explosion_radius"]
	var array_fields = ["effects", "special_flags"]
	
	# Track processed weapons for debugging
	var processed_count = 0
	
	# Read weapons
	while !file.eof_reached():
		var values = file.get_csv_line()
		print("Line read: ", values, " Size: ", values.size())
		
		# Skip empty or short lines
		if values.size() <= 1 or (values.size() > 0 and values[0].strip_edges() == ""):
			print("Skipping empty line")
			continue  # Skip empty lines
		
		# Skip if not enough values
		if values.size() < 3:
			print("WARNING: Skipping incomplete weapon data: " + str(values))
			continue
			
		var weapon_data = {}
		
		# Process each field
		for i in range(min(cleaned_headers.size(), values.size())):
			var field_name = cleaned_headers[i]
			var value = values[i].strip_edges()
			
			# Skip empty fields
			if value == "":
				continue
			
			# Handle each field based on type
			if field_name in int_fields:
				weapon_data[field_name] = int(value) if value else 0
			elif field_name in float_fields:
				weapon_data[field_name] = float(value) if value else 0.0
			elif field_name == "attack_range_x" or field_name == "attack_range_y":
				# Special case for attack range
				if !weapon_data.has("attack_range"):
					weapon_data["attack_range"] = Vector2.ZERO
				if field_name == "attack_range_x":
					weapon_data["attack_range"].x = float(value) if value else 0.0
				else:
					weapon_data["attack_range"].y = float(value) if value else 0.0
			elif field_name == "behaviors":
				# Handle behavior parameters (semicolon-separated)
				if value:
					if value.contains(";"):
						weapon_data[field_name] = value.split(";")
					else:
						weapon_data[field_name] = [value] if value.length() > 0 else []
			elif field_name in array_fields:
				# Split comma-separated lists into arrays
				if value.contains(","):
					weapon_data[field_name] = value.split(",")
				else:
					weapon_data[field_name] = [value] if value.length() > 0 else []
			else:
				# String values
				weapon_data[field_name] = value
		
		# Check if this is the weapon ID (first column)
		if values.size() > 0 and values[0].strip_edges() != "":
			weapon_data["weapon_id"] = values[0].strip_edges()
		
		# Skip if no ID
		if !weapon_data.has("weapon_id"):
			print("WARNING: Skipping weapon with no ID: ", str(values[0]))
			continue
			
		# Store in weapons dictionary
		weapons[weapon_data["weapon_id"]] = weapon_data
		processed_count += 1
		print("Added weapon: ", weapon_data["weapon_id"])
	
	print("Successfully processed " + str(processed_count) + " weapons from CSV")
	return true

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
			"weapon_style": "melee",
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
