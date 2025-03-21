# behavior_manager.gd - Handles behavior loading and execution
class_name BehaviorManager
extends Node

# Debug flag
const DEBUG = false

# Parent weapon reference
var weapon = null

# Active behaviors
var behaviors = []

# Registered behavior types
var behavior_types = {}

func _ready():
	# Register the built-in behavior types
	_register_default_behaviors()

# Register built-in behavior types
func _register_default_behaviors():
	# Movement behaviors
	register_behavior("homing", "res://scripts/behaviors/homing_behavior.gd")
	register_behavior("bounce", "res://scripts/behaviors/bounce_behavior.gd")
	register_behavior("gravity", "res://scripts/behaviors/gravity_behavior.gd")
	register_behavior("wave", "res://scripts/behaviors/wave_behavior.gd")
	
	# Impact behaviors
	register_behavior("explosive", "res://scripts/behaviors/explosive_behavior.gd")
	register_behavior("piercing", "res://scripts/behaviors/piercing_behavior.gd")
	register_behavior("multishot", "res://scripts/behaviors/multishot_behavior.gd")
	register_behavior("singularity", "res://scripts/behaviors/singularity_behavior.gd")
	
	# Effect behaviors
	register_behavior("fire", "res://scripts/behaviors/fire_behavior.gd") 
	register_behavior("freeze", "res://scripts/behaviors/freeze_behavior.gd")
	register_behavior("poison", "res://scripts/behaviors/poison_behavior.gd")
	
	# Cooldown behaviors
	register_behavior("rapid", "res://scripts/behaviors/rapid_cooldown_behavior.gd")
	
	if DEBUG:
		print("Registered ", behavior_types.size(), " behavior types")

# Register a new behavior type
func register_behavior(behavior_id: String, script_path: String):
	behavior_types[behavior_id] = script_path
	
	if DEBUG:
		print("Registered behavior: ", behavior_id, " at path: ", script_path)

# Initialize the manager with a weapon
func initialize(weapon_ref):
	weapon = weapon_ref
	
	if DEBUG:
		print("Behavior manager initialized for weapon: ", weapon.get_weapon_name())

# Load behaviors from the weapon's data
func load_behaviors_from_weapon():
	# Clear existing behaviors
	clear_behaviors()
	
	# Get the behaviors list from weapon data
	var behavior_list = []
	
	# Check both "behaviors" field and special flags
	if "behaviors" in weapon.weapon_data:
		# Direct behaviors field (comma separated)
		var behaviors_str = weapon.weapon_data["behaviors"]
		if behaviors_str and behaviors_str.strip_edges() != "":
			behavior_list.append_array(behaviors_str.split(";"))
	
	# Check other weapon parameters that might imply behaviors
	
	# Bouncing implies bounce behavior
	if "bounce_count" in weapon.weapon_data and int(weapon.weapon_data["bounce_count"]) > 0:
		behavior_list.append("bounce")
	
	# Homing implies homing behavior
	if "homing_strength" in weapon.weapon_data and float(weapon.weapon_data["homing_strength"]) > 0:
		behavior_list.append("homing")
	
	# Gravity factor implies gravity behavior  
	if "gravity_factor" in weapon.weapon_data and float(weapon.weapon_data["gravity_factor"]) > 0:
		behavior_list.append("gravity")
	
	# Explosion radius implies explosive behavior
	if "explosion_radius" in weapon.weapon_data and float(weapon.weapon_data["explosion_radius"]) > 0:
		behavior_list.append("explosive")
	
	# Piercing implies piercing behavior
	if "piercing" in weapon.weapon_data and int(weapon.weapon_data["piercing"]) > 0:
		behavior_list.append("piercing")
	
	# Multiple projectiles implies multishot
	if "projectile_count" in weapon.weapon_data and int(weapon.weapon_data["projectile_count"]) > 1:
		behavior_list.append("multishot")
	
	# Check effects for status behaviors
	if "effects" in weapon.weapon_data:
		var effects = weapon.weapon_data["effects"]
		if effects is String and effects.strip_edges() != "":
			var effect_list = effects.split(",")
			for effect in effect_list:
				effect = effect.strip_edges()
				if effect == "fire":
					behavior_list.append("fire")
				elif effect == "freeze":
					behavior_list.append("freeze")
				elif effect == "poison":
					behavior_list.append("poison")
	
	# Create unique behavior list
	var unique_behaviors = []
	for behavior_id in behavior_list:
		behavior_id = behavior_id.strip_edges()
		if behavior_id not in unique_behaviors:
			unique_behaviors.append(behavior_id)
	
	# Load each behavior
	for behavior_id in unique_behaviors:
		# Parse behavior and parameters
		var params = {}
		var id_parts = behavior_id.split(":")
		
		behavior_id = id_parts[0]
		
		# Extract parameters if present (format: "behavior:param1=value1,param2=value2")
		if id_parts.size() > 1:
			var param_parts = id_parts[1].split(",")
			for param in param_parts:
				var kv = param.split("=")
				if kv.size() == 2:
					params[kv[0]] = kv[1]
		
		# Load the weapon data parameters
		_add_weapon_data_params(behavior_id, params)
		
		# Create the behavior
		create_behavior(behavior_id, params)
	
	if DEBUG:
		print("Loaded ", behaviors.size(), " behaviors for weapon: ", weapon.get_weapon_name())

# Add relevant weapon data parameters to the behavior params
func _add_weapon_data_params(behavior_id: String, params: Dictionary):
	match behavior_id:
		"bounce":
			params["bounce_count"] = weapon.weapon_data.get("bounce_count", 0)
		"homing":
			params["homing_strength"] = weapon.weapon_data.get("homing_strength", 0.0)
		"gravity":
			params["gravity_factor"] = weapon.weapon_data.get("gravity_factor", 0.0)
		"explosive":
			params["explosion_radius"] = weapon.weapon_data.get("explosion_radius", 0.0)
		"piercing":
			params["piercing"] = weapon.weapon_data.get("piercing", 0)
		"multishot":
			params["projectile_count"] = weapon.weapon_data.get("projectile_count", 1)
			params["projectile_spread"] = weapon.weapon_data.get("projectile_spread", 0.0)
		"wave":
			params["wave_amplitude"] = weapon.weapon_data.get("wave_amplitude", 50.0)
			params["wave_frequency"] = weapon.weapon_data.get("wave_frequency", 3.0)

# Create a behavior instance
func create_behavior(behavior_id: String, params: Dictionary = {}):
	if behavior_id in behavior_types:
		var script_path = behavior_types[behavior_id]
		
		# Try to load the script
		var behavior_script = load(script_path)
		if behavior_script:
			var behavior = behavior_script.new()
			behavior.initialize(weapon, params)
			behaviors.append(behavior)
			
			if DEBUG:
				print("Created behavior: ", behavior_id, " for weapon: ", weapon.get_weapon_name())
			
			return behavior
		else:
			printerr("Failed to load behavior script: ", script_path)
	else:
		if DEBUG:
			print("Unknown behavior type: ", behavior_id)
	
	return null

# Clear all behaviors
func clear_behaviors():
	behaviors.clear()
	
	if DEBUG:
		print("Cleared all behaviors for weapon: ", weapon.get_weapon_name())

# Call on_weapon_used for all behaviors
func on_weapon_used():
	for behavior in behaviors:
		behavior.on_weapon_used()

# Call on_projectile_created for all behaviors
func on_projectile_created(projectile):
	for behavior in behaviors:
		behavior.on_projectile_created(projectile)

# Call on_hit for all behaviors
func on_hit(target):
	for behavior in behaviors:
		behavior.on_hit(target)

# Call on_attack_executed for all behaviors
func on_attack_executed(attack_style: String):
	for behavior in behaviors:
		behavior.on_attack_executed(attack_style)

# Call on_attack_end for all behaviors
func on_attack_end():
	for behavior in behaviors:
		behavior.on_attack_end()

# Calculate cooldown modification based on behaviors
func calculate_cooldown_multiplier() -> float:
	var multiplier = 1.0
	
	for behavior in behaviors:
		multiplier = behavior.modify_cooldown(multiplier)
	
	return multiplier
