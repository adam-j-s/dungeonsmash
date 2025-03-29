# Handles behavior loading and execution efficiently
class_name BehaviorManager
extends Node

# Debug flag
const DEBUG = true

# Parent weapon reference
var weapon = null

# Active behaviors
var behaviors = []

# Registered behavior types
var behavior_types = {}

# Behavior categories for optimization
var cooldown_behaviors = []
var projectile_movement_behaviors = []
var projectile_physics_behaviors = []
var projectile_hit_behaviors = []
var attack_behaviors = []

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
	
	# Add null check
	if weapon == null:
		printerr("BehaviorManager initialized with null weapon reference")
		return
	
	if DEBUG:
		print("Behavior manager initialized for weapon: ", weapon.get_weapon_name())
	
	# Load behaviors immediately
	load_behaviors_from_weapon()

# Load behaviors from the weapon's data
func load_behaviors_from_weapon():
	# Clear existing behaviors
	clear_behaviors()
	
	# Skip if weapon is null
	if weapon == null:
		printerr("Cannot load behaviors: weapon reference is null")
		return
	
	# Check if weapon_data exists
	if !("weapon_data" in weapon) or weapon.weapon_data == null:
		printerr("Cannot load behaviors: weapon data is null or missing")
		return
	
	if DEBUG:
		print("DEBUG: Loading behaviors from weapon: " + weapon.weapon_id)
		print("DEBUG: Weapon data: " + str(weapon.weapon_data))
	
	# Get the behaviors list from weapon data
	var behavior_list = []
	
	# Create a map to store parameters for each behavior
	var behavior_param_map = {}
	
	# Check "behaviors" field
	if "behaviors" in weapon.weapon_data:
		var behaviors_data = weapon.weapon_data["behaviors"]
		
		if DEBUG:
			print("DEBUG: Found behaviors field: " + str(behaviors_data))
		
		# Handle different behavior formats
		match typeof(behaviors_data):
			TYPE_STRING:
				# Handle string format: "behavior1;behavior2" or "behavior1:param=value"
				var behavior_entries = []
				
				# Split by semicolons or commas
				if behaviors_data.contains(";"):
					behavior_entries = behaviors_data.split(";")
				elif behaviors_data.contains(","):
					behavior_entries = behaviors_data.split(",")
				else:
					behavior_entries = [behaviors_data]  # Single behavior
				
				# Process each behavior entry
				for entry in behavior_entries:
					var behavior_name = entry
					
					# Extract behavior name if it has parameters
					if entry.contains(":"):
						behavior_name = entry.split(":")[0].strip_edges()
					
					# Add to behavior list
					if behavior_name and behavior_name.strip_edges() != "":
						behavior_list.append(behavior_name.strip_edges())
						if DEBUG:
							print("Added behavior from string: " + behavior_name)
			
			TYPE_ARRAY:
				# Process the array elements with a better understanding of the format
				for item in behaviors_data:
					if typeof(item) != TYPE_STRING:
						continue
						
					# Check if this is a behavior with parameters (has a colon)
					if item.contains(":"):
						var parts = item.split(":")
						var behavior_name = parts[0].strip_edges()
						
						# Add the behavior to our list
						if behavior_name not in behavior_list:
							behavior_list.append(behavior_name)
							if DEBUG:
								print("Added behavior: " + behavior_name)
						
						# Initialize the parameter dictionary for this behavior if needed
						if behavior_name not in behavior_param_map:
							behavior_param_map[behavior_name] = {}
						
						# If there are parameters after the colon, process them
						if parts.size() > 1:
							var param_string = parts[1]
							var param_pairs = []
							
							# Handle both semicolon and comma separators
							if param_string.contains(";"):
								param_pairs = param_string.split(";")
							else:
								param_pairs = param_string.split(",")
							
							# Process each parameter pair
							for pair in param_pairs:
								var kv = pair.split("=")
								if kv.size() == 2:
									var param_name = kv[0].strip_edges()
									var param_value = kv[1].strip_edges()
									behavior_param_map[behavior_name][param_name] = param_value
									if DEBUG:
										print("Added parameter for " + behavior_name + ": " + param_name + " = " + param_value)
					
					# Handle standalone parameters (no colon, but has equals sign)
					elif item.contains("="):
						var kv = item.split("=")
						if kv.size() == 2:
							var param_name = kv[0].strip_edges()
							var param_value = kv[1].strip_edges()
							
							# Try to associate with the previous behavior 
							# (this assumes parameters follow their behavior in the array)
							if behavior_list.size() > 0:
								var last_behavior = behavior_list[behavior_list.size() - 1]
								
								# Initialize the parameter dictionary if needed
								if last_behavior not in behavior_param_map:
									behavior_param_map[last_behavior] = {}
								
								behavior_param_map[last_behavior][param_name] = param_value
								if DEBUG:
									print("Added standalone parameter for " + last_behavior + ": " + param_name + " = " + param_value)
					
					# Just a behavior name without parameters
					else:
						var behavior_name = item.strip_edges()
						if behavior_name != "":
							behavior_list.append(behavior_name)
							if DEBUG:
								print("Added plain behavior: " + behavior_name)
				
				# Log the parameter map
				if DEBUG and behavior_param_map.size() > 0:
					print("Behavior parameter map: " + str(behavior_param_map))
	
	# Now add behaviors based on weapon properties
	
	# SPECIAL CASE: Check for behaviors needed by the wave wand
	if weapon.weapon_id == "wave_wand":
		if "wave" not in behavior_list:
			behavior_list.append("wave")
			if DEBUG:
				print("Added wave behavior for wave_wand weapon")
				
	# SPECIAL CASE: Check for singularity weapons
	if weapon.weapon_id == "singularity_bomb" or weapon.weapon_data.get("weapon_style", "") == "singularity":
		if "singularity" not in behavior_list:
			behavior_list.append("singularity")
			if DEBUG:
				print("Added singularity behavior for singularity weapon")
	
	# Other automatic behavior detection
	if "bounce_count" in weapon.weapon_data and int(weapon.weapon_data["bounce_count"]) > 0:
		behavior_list.append("bounce")
	
	if "homing_strength" in weapon.weapon_data and float(weapon.weapon_data["homing_strength"]) > 0:
		behavior_list.append("homing")
	
	if "gravity_factor" in weapon.weapon_data and float(weapon.weapon_data["gravity_factor"]) > 0:
		behavior_list.append("gravity")
	
	if "explosion_radius" in weapon.weapon_data and float(weapon.weapon_data["explosion_radius"]) > 0:
		behavior_list.append("explosive")
	
	if "piercing" in weapon.weapon_data and int(weapon.weapon_data["piercing"]) > 0:
		behavior_list.append("piercing")
	
	if "projectile_count" in weapon.weapon_data and int(weapon.weapon_data["projectile_count"]) > 1:
		behavior_list.append("multishot")
	
	# Process effects for behaviors
	if "effects" in weapon.weapon_data:
		var effects = weapon.weapon_data["effects"]
		var effect_list = []
		
		# Convert effects to list format
		if typeof(effects) == TYPE_STRING:
			if effects.strip_edges() != "":
				effect_list = effects.split(",")
		elif typeof(effects) == TYPE_ARRAY:
			effect_list = effects
			
		# Add behaviors based on effects
		for effect in effect_list:
			if typeof(effect) == TYPE_STRING:
				effect = effect.strip_edges()
				if effect == "fire":
					behavior_list.append("fire")
				elif effect == "freeze":
					behavior_list.append("freeze")
				elif effect == "poison":
					behavior_list.append("poison")
	
	# Create unique behavior list (remove duplicates)
	var unique_behaviors = []
	for behavior_id in behavior_list:
		behavior_id = behavior_id.strip_edges()
		if behavior_id not in unique_behaviors and behavior_id != "":
			unique_behaviors.append(behavior_id)
	
	if DEBUG:
		print("Unique behaviors to load: " + str(unique_behaviors))
	
	# Load each behavior
	for behavior_id in unique_behaviors:
		# Get base behavior ID without parameter part
		var base_behavior_id = behavior_id
		if base_behavior_id.contains(":"):
			base_behavior_id = base_behavior_id.split(":")[0].strip_edges()
		
		# Initialize parameters
		var params = {}
		
		# Check if we have stored parameters for this behavior
		if base_behavior_id in behavior_param_map:
			params = behavior_param_map[base_behavior_id].duplicate()
			if DEBUG:
				print("Using stored parameters for " + base_behavior_id + ": " + str(params))
		
		# Also check for direct parameters in the behavior_id
		var id_parts = behavior_id.split(":")
		
		# Extract parameters if present (format: "behavior:param1=value1,param2=value2" or "behavior:param1=value1;param2=value2")
		if id_parts.size() > 1:
			var param_string = id_parts[1]
			var param_parts = []
		
			# Handle both comma and semicolon separators
			if param_string.contains(";"):
				param_parts = param_string.split(";")
			else:
				param_parts = param_string.split(",")
		
			for param in param_parts:
				var kv = param.split("=")
				if kv.size() == 2:
					params[kv[0].strip_edges()] = kv[1].strip_edges()
		
		# SPECIAL CASE: Force parameters for singularity bomb
		if base_behavior_id == "singularity" and weapon.weapon_id == "singularity_bomb":
			params["pull_strength"] = "2000.0"
			if DEBUG:
				print("FORCE SET: singularity pull_strength = 2000.0 for singularity_bomb")
		
		# Add parameters from weapon data - but don't override existing ones
		_add_weapon_data_params(base_behavior_id, params)
		
		if DEBUG:
			print("Final parameters for " + base_behavior_id + ": " + str(params))
		
		# Create the behavior
		var behavior = create_behavior(base_behavior_id, params)
		if behavior:
			if DEBUG:
				print("Successfully created behavior: " + base_behavior_id)
		else:
			print("Failed to create behavior: " + base_behavior_id)
	
	if DEBUG:
		print("Loaded " + str(behaviors.size()) + " behaviors for weapon: " + weapon.get_weapon_name())
		# Print each loaded behavior
		for behavior in behaviors:
			if behavior and behavior.has_method("get_behavior_name"):
				print("- " + behavior.get_behavior_name())
				
# Add relevant weapon data parameters to the behavior params
func _add_weapon_data_params(behavior_id: String, params: Dictionary):
	match behavior_id:
		"bounce":
			if !("bounce_count" in params):
				params["bounce_count"] = str(weapon.weapon_data.get("bounce_count", 0))
		"homing":
			if !("homing_strength" in params):
				params["homing_strength"] = str(weapon.weapon_data.get("homing_strength", 0.0))
				# Enhance homing strength for more obvious effect
				if "homing_strength" in params and float(params["homing_strength"]) > 0:
					params["homing_strength"] = str(float(params["homing_strength"]) * 3.0)
		"gravity":
			if !("gravity_factor" in params):
				params["gravity_factor"] = str(weapon.weapon_data.get("gravity_factor", 0.0))
		"explosive":
			if !("explosion_radius" in params):
				params["explosion_radius"] = str(weapon.weapon_data.get("explosion_radius", 0.0))
		"piercing":
			if !("piercing" in params):
				params["piercing"] = str(weapon.weapon_data.get("piercing", 0))
		"multishot":
			if !("projectile_count" in params):
				params["projectile_count"] = str(weapon.weapon_data.get("projectile_count", 1))
			if !("projectile_spread" in params):
				params["projectile_spread"] = str(weapon.weapon_data.get("projectile_spread", 0.0))
		"wave":
			if !("wave_amplitude" in params):
				params["wave_amplitude"] = str(weapon.weapon_data.get("wave_amplitude", 50.0))
			if !("wave_frequency" in params):
				params["wave_frequency"] = str(weapon.weapon_data.get("wave_frequency", 3.0))
		"singularity":
			if !("pull_radius" in params):
				params["pull_radius"] = str(weapon.weapon_data.get("pull_radius", 150.0))
			if !("pull_strength" in params):
				params["pull_strength"] = str(weapon.weapon_data.get("pull_strength", 600.0))
			if !("max_singularity_duration" in params):
				params["max_singularity_duration"] = str(weapon.weapon_data.get("singularity_duration", 2.0))
			if !("explosion_radius" in params):
				params["explosion_radius"] = str(weapon.weapon_data.get("explosion_radius", 120.0))
			
			if DEBUG:
				print("Singularity params after adding defaults: " + str(params))
	
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
			
			# Categorize behavior for optimization
			categorize_behavior(behavior)
			
			if DEBUG:
				print("Created behavior: ", behavior_id, " for weapon: ", weapon.get_weapon_name())
			
			return behavior
		else:
			printerr("Failed to load behavior script: ", script_path)
	else:
		if DEBUG:
			print("Unknown behavior type: ", behavior_id)
	
	return null

# Categorize behavior for optimization
func categorize_behavior(behavior):
	#Skip null behaviors
	if behavior == null:
		return
		
	# Check behavior capabilities by name (faster than method checks) and check behavior provides a valid name
	var behavior_name = ""
	if behavior.has_method("get_behavior_name"):
		behavior_name = behavior.get_behavior_name()
	else:
		#Can't categorize without a name
		return
		
	# Check for specific behaviors and categorize them
	match behavior_name:
		"RapidCooldownBehavior":
			cooldown_behaviors.append(behavior)
		"HomingBehavior", "WaveBehavior", "GravityBehavior":
			projectile_movement_behaviors.append(behavior)
		"BounceBehavior":
			projectile_physics_behaviors.append(behavior)
		"ExplosiveBehavior", "PiercingBehavior", "SingularityBehavior":
			projectile_hit_behaviors.append(behavior)
		_:
			# General categorization based on method presence
			if behavior.has_method("modify_cooldown"):
				cooldown_behaviors.append(behavior)
			if behavior.has_method("on_projectile_process"):
				projectile_movement_behaviors.append(behavior)
			if behavior.has_method("on_projectile_physics_process"):
				projectile_physics_behaviors.append(behavior)
			if behavior.has_method("on_projectile_hit"):
				projectile_hit_behaviors.append(behavior)
			if behavior.has_method("on_attack_executed"):
				attack_behaviors.append(behavior)

# Clear all behaviors
func clear_behaviors():
	behaviors.clear()
	cooldown_behaviors.clear()
	projectile_movement_behaviors.clear()
	projectile_physics_behaviors.clear()
	projectile_hit_behaviors.clear()
	attack_behaviors.clear()
	
	if DEBUG:
		print("Cleared all behaviors for weapon: ", weapon.get_weapon_name() if weapon else "None")

# Call on_weapon_used for all behaviors
func on_weapon_used():
	for behavior in behaviors:
		behavior.on_weapon_used()

# Attach behaviors to a projectile
func apply_behaviors_to_projectile(projectile):
	# Skip if no behaviors to apply
	if behaviors.size() == 0 or projectile == null:
		print("No behaviors to apply or null projectile")
		return
	
	print("Applying " + str(behaviors.size()) + " behaviors to projectile")
	
	# Apply registered behaviors
	for behavior in behaviors:
		if behavior != null and behavior.has_method("on_projectile_created"):
			print("Applying behavior: " + behavior.get_behavior_name())
			behavior.on_projectile_created(projectile)
		
		# Also attach behavior directly if projectile supports it
		if behavior != null and projectile.has_method("add_behavior"):
			projectile.add_behavior(behavior)
			print("Added behavior to projectile")
			
# In behavior_manager.gd, add:
func on_projectile_created(projectile):
	# Apply behaviors to the projectile
	apply_behaviors_to_projectile(projectile)
	
	# Also notify behaviors
	for behavior in behaviors:
		if behavior.has_method("on_projectile_created"):
			behavior.on_projectile_created(projectile)
# Process projectile movement - optimized to only check relevant behaviors
# Returns true if any behavior handled movement
func process_projectile(projectile, delta):
	# Skip if no movement behaviors
	if projectile_movement_behaviors.empty():
		return false
		
	# Try only movement behaviors
	for behavior in projectile_movement_behaviors:
		if behavior.on_projectile_process(projectile, delta):
			return true
	
	return false

# Process projectile physics - optimized to only check relevant behaviors
# Returns true if any behavior handled physics
func process_projectile_physics(projectile, delta):
	# Skip if no physics behaviors
	if projectile_physics_behaviors.empty():
		return false
		
	# Try only physics behaviors
	for behavior in projectile_physics_behaviors:
		if behavior.on_projectile_physics_process(projectile, delta):
			return true
	
	return false

# Handle projectile hit - optimized to only check relevant behaviors
func on_projectile_hit(projectile, target):
	# Skip if no hit behaviors
	if projectile == null or target == null or projectile_hit_behaviors.empty():
		return
		
	# Apply only hit behaviors
	for behavior in projectile_hit_behaviors:
		#Add null check for each behavior
		if behavior != null and behavior.has_method("on_projectile_hit"):
			behavior.on_projectile_hit(projectile, target)

# Handle projectile destroyed
func on_projectile_destroyed(projectile):
	for behavior in behaviors:
		behavior.on_projectile_destroyed(projectile)

# Call on_hit for all behaviors
func on_hit(target):
	for behavior in behaviors:
		behavior.on_hit(target)

# Call on_attack_executed for relevant behaviors
func on_attack_executed(attack_style: String):
	# Skip if no attack behaviors
	if attack_behaviors.size() == 0 or attack_style == null or attack_style.is_empty():  # Using size() == 0 instead of empty()
		return
		
	# Apply only attack behaviors
	for behavior in attack_behaviors:
		# Add null check for each behavior
		if behavior != null and behavior.has_method("on_attack_executed"):
			behavior.on_attack_executed(attack_style)

# Call on_attack_end for all behaviors
func on_attack_end():
	for behavior in behaviors:
		behavior.on_attack_end()

# Calculate cooldown modification based on behaviors - optimized
func calculate_cooldown_multiplier() -> float:
	# Skip if no cooldown behaviors
	if cooldown_behaviors.size() == 0 or weapon == null:# Changed from empty()
		return 1.0
		
	var multiplier = 1.0
	
	# Apply only cooldown behaviors
	for behavior in cooldown_behaviors:
		# Null check for each behaviour
		if behavior != null and behavior.has_method(("modify_cooldown")):
			multiplier = behavior.modify_cooldown(multiplier)
	
	return multiplier

# Get all behaviors for a specific weapon
func get_behaviors_for_weapon_id(weapon_id: String):
	# If this manager already has the requested weapon, return its behaviors
	if weapon_id == null or weapon_id.is_empty():
		return[]
		
	#If this manager already has the requested weapon, return it's behaviors
	if weapon != null and "weapon_id" in weapon and weapon.weapon_id == weapon_id:
		return behaviors
	
	# Otherwise, we need to access the global BehaviorManager that has all weapon behaviors
	if is_inside_tree() and get_tree() != null and get_tree().current_scene != null:
		var scene = get_tree().current_scene
		if scene.has_node("BehaviorManager"):
			return scene.get_node("BehaviorManager").get_behaviors_for_weapon_id(weapon_id)
	
	return []

# Expose a direct behavior query method for debugging
func has_behavior(behavior_name: String) -> bool:
	for behavior in behaviors:
		if behavior.get_behavior_name() == behavior_name:
			return true
	return false

# Get behavior by name
func get_behavior(behavior_name: String):
	for behavior in behaviors:
		if behavior.get_behavior_name() == behavior_name:
			return behavior
	return null
	
# Helper function to create a timer safely
func create_safe_timer(wait_time, one_shot = true):
	# Validate we have a parent node to attach to
	if !weapon or !is_instance_valid(weapon):
		return null
		
	# Create the timer
	var timer = Timer.new()
	timer.wait_time = wait_time
	timer.one_shot = one_shot
	weapon.add_child(timer)  # Attach to weapon to ensure proper lifetime
	
	return timer

# Start a timer with a callback
func start_timer_with_callback(timer, callback_object, callback_method, binds = []):
	# Validate timer
	if !timer or !is_instance_valid(timer):
		return false
		
	# Create a callable
	var callable
	if binds.size() > 0:
		callable = Callable(callback_object, callback_method).bind(binds)
	else:
		callable = Callable(callback_object, callback_method)
		
	# Store the callable for cleanup
	timer.set_meta("timeout_callable", callable)
	
	# Connect and start
	timer.timeout.connect(callable)
	timer.start()
	
	return true

# Create simple one-shot timer with callback
func create_timer(wait_time, callback_object, callback_method, binds = []):
	var timer = create_safe_timer(wait_time, true)
	if timer:
		start_timer_with_callback(timer, callback_object, callback_method, binds)
	return timer

# Cleanup timer safely
func cleanup_timer(timer):
	if timer and is_instance_valid(timer):
		# Stop the timer
		timer.stop()
		
		# Disconnect any connected signals
		if timer.has_meta("timeout_callable"):
			var callable = timer.get_meta("timeout_callable")
			if timer.is_connected("timeout", callable):
				timer.disconnect("timeout", callable)
				
		# Remove from tree and free
		timer.queue_free()
		return true
	
	return false
