# Controller for weapon attack execution
extends Node

# Configuration
var weapon = null
var wielder = null
var attack_style = null
var current_style_id = ""  # Track the current attack style ID

func _ready():
	print("Weapon Attack System Ready")

func initialize(weapon_ref):
	weapon = weapon_ref
	wielder = weapon.wielder if weapon else null
	print("Weapon attacks initializing with: ", weapon.weapon_id if weapon else "None")
	
	# Attempt to create the initial attack style
	if weapon and "weapon_data" in weapon:
		var style_id = weapon.weapon_data.get("weapon_style", "melee")
		create_attack_style(style_id)
	
	return self

func execute_attack(style_id = null):
	# Add debug prints
	print("Execute attack called with style_id: " + str(style_id))
	print("Current attack_style reference: " + str(attack_style))
	
	# If a specific style is requested, create it if needed
	if style_id != null and style_id != current_style_id:
		# Need to create or switch to the requested style
		create_attack_style(style_id)
	elif attack_style == null:
		# No style created yet, use default from weapon
		var default_style = "melee"
		if weapon and "weapon_data" in weapon:
			default_style = weapon.weapon_data.get("weapon_style", "melee")
		create_attack_style(default_style)
	
	# Now use the current attack style to execute the attack
	if attack_style and attack_style.has_method("execute_attack"):
		print("Executing attack with style: " + attack_style.get_style_name())
		return attack_style.execute_attack()
	else:
		print("ERROR: No valid attack style available")
		return false

func create_attack_style(style_id):
	print("Creating attack style: " + style_id)
	current_style_id = style_id
	
	# Clean up existing attack style if any
	if attack_style != null:
		attack_style.queue_free()
		attack_style = null
	
	# Map to correct style script paths
	var style_paths = {
		"melee": "res://scripts/attack_styles/melee_attack_style.gd",
		"projectile": "res://scripts/attack_styles/projectile_attack_style.gd",
		"area": "res://scripts/attack_styles/area_attack_style.gd",
		"pull": "res://scripts/attack_styles/pull_attack_style.gd",
		"push": "res://scripts/attack_styles/push_attack_style.gd",
		"singularity": "res://scripts/attack_styles/projectile_attack_style.gd",
		"dagger": "res://scripts/attack_styles/dagger_attack_style.gd"
	}
	
	# Load and initialize the style
	if style_paths.has(style_id):
		var style_path = style_paths[style_id]
		print("Looking for attack style at path: " + style_path)
		
		if ResourceLoader.exists(style_path):
			attack_style = load(style_path).new()
			if attack_style.has_method("initialize"):
				attack_style.initialize(weapon, {})
			print("Attack style created successfully")
		else:
			print("ERROR: Attack style not found at: " + style_path)
	else:
		print("ERROR: Unknown attack style: " + style_id)
	
	return attack_style
