# attack_style_manager.gd - Manages weapon attack styles
class_name AttackStyleManager
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
	# Register built-in attack styles
	_register_default_styles()
	print("Attack style manager ready, registered styles: ", style_types.keys())

# Register built-in attack styles with path checking
func _register_default_styles():
	# First, check if the directory exists
	var dir = DirAccess.open("res://scripts/")
	if dir:
		print("Scripts directory exists")
		# Check if attack_styles subdirectory exists
		if dir.dir_exists("attack styles"):
			print("Attack styles directory exists")
		#else:
			#print("Attack styles directory does NOT exist")
			# Try to make the directory
			#dir.make_dir("attack_styles")
	else:
		print("ERROR: Could not open scripts directory")
	
	# Now register the styles
	register_style("melee", "res://scripts/attack styles/melee_attack_style.gd")
	register_style("projectile", "res://scripts/attack styles/projectile_attack_style.gd")
	register_style("wave", "res://scripts/attack styles/wave_attack_style.gd")
	register_style("pull", "res://scripts/attack styles/pull_attack_style.gd")
	register_style("push", "res://scripts/attack styles/push_attack_style.gd")
	register_style("area", "res://scripts/attack styles/area_attack_style.gd")
	register_style("singularity", "res://scripts/attack styles/singularity_attack_style.gd")
	
	# Try to load one to verify
	var test_script = load("res://scripts/attack styles/melee_attack_style.gd")
	if test_script:
		print("Successfully loaded test script")
	else:
		print("ERROR: Could not load test script")
	
	print("Registered ", style_types.size(), " attack styles")

# Register a new attack style
func register_style(style_id: String, script_path: String):
	style_types[style_id] = script_path
	
	if DEBUG:
		print("Registered attack style: ", style_id, " at path: ", script_path)

# Initialize the manager with a weapon
func initialize(weapon_ref):
	print("Attack style manager initializing with weapon: ", weapon_ref.weapon_id if weapon_ref else "None")
	weapon = weapon_ref
	
	# Load the attack style based on the weapon's data
	if weapon:
		load_style_from_weapon()
	else:
		print("ERROR: Cannot load styles, weapon reference is null")
	
	print("Attack style manager initialized, current style: ", current_style)

# Load the appropriate style based on weapon data
func load_style_from_weapon():
	var style_id = "melee"  # Default
	
	if weapon and weapon.weapon_data.has("weapon_style"):
		style_id = weapon.weapon_data["weapon_style"]
	
	print("Loading attack style: ", style_id, " for weapon: ", weapon.weapon_id)
	
	# Create the attack style
	current_style = create_style(style_id)
	
	if current_style:
		print("Successfully loaded attack style: ", style_id)
	else:
		print("FAILED to load attack style: ", style_id)

# Create a specific attack style
func create_style(style_id: String):
	print("Creating attack style: ", style_id)
	
	if style_id in style_types:
		var script_path = style_types[style_id]
		print("Found script path: ", script_path)
		
		# Try to load the script
		var style_script = load(script_path)
		if style_script:
			print("Successfully loaded script")
			var style = style_script.new()
			print("Created style instance")
			style.initialize(weapon)
			print("Initialized style")
			
			return style
		else:
			print("Failed to load attack style script: ", script_path)
	else:
		print("Unknown attack style: ", style_id)
		
		# Try to load the default melee style if this isn't already a fallback
		if style_id != "melee":
			print("Trying fallback to melee")
			return create_style("melee")
	
	return null

# Execute the current attack style
func execute_attack():
	print("AttackStyleManager.execute_attack called")
	print("Current style: ", current_style)
	
	if current_style:
		print("Attempting to execute attack with style: ", current_style.get_style_name())
		current_style.execute_attack()
		return true
	else:
		print("ERROR: No attack style loaded!")
	return false
