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
	style_manager = AttackStyleManager.new()
	style_manager.name = "StyleManager"
	add_child(style_manager)
	print("Style manager created")

# Set up when weapon and wielder references are available
func initialize():
	print("Weapon attacks initializing with weapon: ", weapon.weapon_id if weapon else "None")
	
	# Store the wielder reference
	if weapon:
		wielder = weapon.wielder
		print("Wielder set to: ", wielder.name if wielder else "None")
		
	# Initialize the style manager
	if style_manager and weapon:
		style_manager.initialize(weapon)
		print("Style manager initialized")
	else:
		print("ERROR: Cannot initialize style manager")
	
	print("Weapon attacks initialization complete")

# Execute the appropriate attack based on style
func execute_attack(attack_style: String):
	print("Executing attack style: ", attack_style)
	
	# Execute using the style manager
	if style_manager:
		var result = style_manager.execute_attack()
		print("Attack execution result: ", result)
		return result
	else:
		print("ERROR: Style manager not initialized")
		return false
