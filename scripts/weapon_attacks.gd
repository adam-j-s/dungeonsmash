# weapon_attacks.gd - Handles attack execution using the attack style system
extends Node

# References
var weapon = null  # Reference to parent weapon
var wielder = null  # Direct reference to wielder for convenience

# Attack style manager
var style_manager = null

const DEBUG = true  # Set to true for debugging

# Initialize the attack handler
func _ready():
	print("Weapon attacks handler ready")
	# Create the style manager
	var style_manager_script = load("res://scripts/attack_style_manager.gd")
	style_manager = style_manager_script.new()
	style_manager.name = "StyleManager"
	add_child(style_manager)
	print("Style manager created")
	
	# Direct initialization if weapon is already set
	if weapon:
		print("Weapon already set, initializing style manager")
		initialize()

# Set up when weapon and wielder references are available
func initialize():
	print("Weapon attacks initializing with weapon: ", weapon.weapon_id if weapon else "None")
	
	# Store the wielder reference
	if weapon:
		wielder = weapon.wielder
		print("Wielder set to: ", wielder.name if wielder else "None")
	else:
		print("ERROR: No weapon reference in attack handler")
		return
		
	# Initialize the style manager
	if style_manager:
		# Set weapon and wielder before initialization
		style_manager.weapon = weapon
		style_manager.wielder = wielder
		
		# Initialize with weapon reference
		style_manager.initialize(weapon)
		print("Style manager initialized with weapon and wielder")
	else:
		print("ERROR: Style manager not created")
	
	print("Weapon attacks initialization complete")

# Execute the appropriate attack based on style
func execute_attack(attack_style: String):
	print("Executing attack style: ", attack_style)
	
	# Make sure style manager is initialized
	if style_manager and weapon and style_manager.weapon != weapon:
		print("Style manager not initialized with current weapon, initializing now")
		style_manager.initialize(weapon)
	
	# Execute using the style manager
	if style_manager:
		var result = style_manager.execute_attack()
		print("Attack execution result: ", result)
		return result
	else:
		print("ERROR: Style manager not initialized")
		return false
