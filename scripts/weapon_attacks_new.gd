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
	var manager_script = load("res://scripts/attack_style_manager.gd")
	style_manager = manager_script.new()
	style_manager.name = "StyleManager"
	add_child(style_manager)
	print("Style manager created")

# Set up when weapon and wielder references are available
func initialize():
	print("[WEAPON_ATTACKS] Initialize called")
	print("[WEAPON_ATTACKS] Weapon reference: ", weapon)
	
	# Store the wielder reference
	if weapon:
		wielder = weapon.wielder
		print("[WEAPON_ATTACKS] Weapon ID: ", weapon.weapon_id)
		print("[WEAPON_ATTACKS] Wielder set to: ", wielder.name if wielder else "None")
		
		# Check weapon data
		print("[WEAPON_ATTACKS] Weapon data keys: ", weapon.weapon_data.keys())
		print("[WEAPON_ATTACKS] Weapon style: ", weapon.weapon_data.get("weapon_style", "NOT FOUND"))
		
		# Initialize the style manager
		if style_manager:
			print("[WEAPON_ATTACKS] Calling style_manager.initialize...")
			style_manager.initialize(weapon)
			print("[WEAPON_ATTACKS] Style manager initialized, current style: ", style_manager.current_style)
		else:
			print("[WEAPON_ATTACKS] ERROR: style_manager is null!")
	else:
		print("[WEAPON_ATTACKS] ERROR: weapon reference is null!")
	
	print("[WEAPON_ATTACKS] Initialization complete")

# Execute the appropriate attack based on style
func execute_attack(attack_style: String):
	print("[WEAPON_ATTACKS] Execute attack called with style: ", attack_style)
	
	# Double-check initialization
	if !style_manager:
		print("[WEAPON_ATTACKS] ERROR: style_manager is null in execute_attack!")
		return false
		
	if !style_manager.current_style:
		print("[WEAPON_ATTACKS] WARNING: No current style set. Trying to initialize again...")
		style_manager.initialize(weapon)
	
	# Execute using the style manager
	var result = style_manager.execute_attack()
	print("[WEAPON_ATTACKS] Attack execution result: ", result)
	return result
