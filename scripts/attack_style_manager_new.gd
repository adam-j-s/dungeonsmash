# attack_style_manager.gd - Manages weapon attack styles
# No class_name to avoid conflicts
extends Node

# Debug flag
const DEBUG = true  # Set to true to see debug messages

# Parent weapon reference
var weapon = null

# Current active attack style
var current_style = null

# Registered attack styles
var style_types = {}

func _ready():
	print("[STYLE_MANAGER] Ready")
	
	# Direct test to load scripts
	_test_direct_script_loading()
	
	# Register built-in attack styles
	_register_default_styles()
	
	print("[STYLE_MANAGER] Registered styles: ", style_types.keys())

# Direct test of script loading
func _test_direct_script_loading():
	var test_files = [
		"res://scripts/attack styles/melee_attack_style.gd",
		"res://scripts/attack styles/projectile_attack_style.gd"
	]
	
	for file_path in test_files:
		print("[STYLE_MANAGER] Testing direct load of: ", file_path)
		
		# Check if file exists
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file:
			print("[STYLE_MANAGER] - File exists and can be opened")
			var content = file.get_as_text()
			print("[STYLE_MANAGER] - File content length: ", content.length(), " characters")
			file.close()
		else:
			print("[STYLE_MANAGER] - File does NOT exist or cannot be opened, error: ", FileAccess.get_open_error())
		
		# Try to load as resource
		var res = load(file_path)
		if res:
			print("[STYLE_MANAGER] - Successfully loaded as resource")
			
			# Try to instantiate
			var instance = res.new()
			if instance:
				print("[STYLE_MANAGER] - Successfully created instance")
				if instance.has_method("get_style_name"):
					print("[STYLE_MANAGER] - Instance has get_style_name method: ", instance.get_style_name())
				else:
					print("[STYLE_MANAGER] - Instance does NOT have get_style_name method")
			else:
				print("[STYLE_MANAGER] - Failed to create instance")
		else:
			print("[STYLE_MANAGER] - Failed to load as resource")

# Register built-in attack styles
func _register_default_styles():
	# Register styles with simplified paths
	register_style("melee", "res://scripts/attack styles/melee_attack_style.gd")
	register_style("projectile", "res://scripts/attack styles/projectile_attack_style.gd")
	register_style("wave", "res://scripts/attack styles/wave_attack_style.gd")
	register_style("pull", "res://scripts/attack styles/pull_attack_style.gd")
	register_style("push", "res://scripts/attack styles/push_attack_style.gd")
	register_style("area", "res://scripts/attack styles/area_attack_style.gd")
	register_style("singularity", "res://scripts/attack styles/singularity_attack_style.gd")

# Register a new attack style
func register_style(style_id: String, script_path: String):
	style_types[style_id] = script_path
	print("[STYLE_MANAGER] Registered attack style: ", style_id, " at path: ", script_path)

# Initialize the manager with a weapon
func initialize(weapon_ref):
	print("[STYLE_MANAGER] Initialize called with weapon: ", weapon_ref.weapon_id if weapon_ref else "None")
	weapon = weapon_ref
	
	# Print all weapon properties for debugging
	if weapon:
		print("[STYLE_MANAGER] WEAPON DEBUG:")
		print("[STYLE_MANAGER] - ID: ", weapon.weapon_id)
		print("[STYLE_MANAGER] - Data keys: ", weapon.weapon_data.keys())
		for key in weapon.weapon_data:
			print("[STYLE_MANAGER]   ", key, " = ", weapon.weapon_data[key])
		
		var style_id = "melee"  # Default
		
		if weapon.weapon_data.has("weapon_style"):
			style_id = weapon.weapon_data["weapon_style"]
			print("[STYLE_MANAGER] Weapon style from data: ", style_id)
		else:
			print("[STYLE_MANAGER] Weapon missing weapon_style in data, using default: ", style_id)
		
		# Create the attack style
		current_style = create_style(style_id)
		
		if current_style:
			print("[STYLE_MANAGER] Successfully loaded attack style: ", style_id)
		else:
			print("[STYLE_MANAGER] FAILED to load attack style: ", style_id)
			
			# Try again with "melee" as fallback if not already trying melee
			if style_id != "melee":
				print("[STYLE_MANAGER] Trying fallback to melee style...")
				current_style = create_style("melee")
				if current_style:
					print("[STYLE_MANAGER] Successfully loaded fallback melee style")
				else:
					print("[STYLE_MANAGER] Even fallback melee style failed to load")
	else:
		print("[STYLE_MANAGER] ERROR: Cannot load styles, weapon reference is null")
	
	print("[STYLE_MANAGER] Initialize complete, current style: ", current_style)

# Create a specific attack style
func create_style(style_id: String):
	print("[STYLE_MANAGER] Creating attack style: ", style_id)
	
	if style_id in style_types:
		var script_path = style_types[style_id]
		print("[STYLE_MANAGER] Found script path: ", script_path)
		
		# Try to load the script
		print("[STYLE_MANAGER] Attempting to load script: ", script_path)
		var style_script = load(script_path)
		
		if style_script:
			print("[STYLE_MANAGER] Successfully loaded script")
			
			# Create instance
			var style = style_script.new()
			print("[STYLE_MANAGER] Created style instance: ", style)
			
			# Initialize
			style.initialize(weapon)
			print("[STYLE_MANAGER] Initialized style with weapon")
			
			return style
		else:
			print("[STYLE_MANAGER] Failed to load attack style script: ", script_path)
	else:
		print("[STYLE_MANAGER] Unknown attack style: ", style_id)
	
	return null

# Execute the current attack style
func execute_attack():
	print("[STYLE_MANAGER] Execute attack called")
	print("[STYLE_MANAGER] Current style: ", current_style)
	
	if current_style:
		print("[STYLE_MANAGER] Executing attack with style: ", current_style.get_style_name())
		current_style.execute_attack()
		return true
	else:
		print("[STYLE_MANAGER] ERROR: No attack style loaded!")
	return false
