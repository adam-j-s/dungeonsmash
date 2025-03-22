# attack_style_manager.gd
extends Node

var weapon = null  # Reference to the weapon
var wielder = null  # Reference to the character wielding the weapon
var current_style = null  # Currently loaded attack style

# Dictionary of style types and their script paths
var style_types = {}

const DEBUG = true  # Enable debug output

func _ready():
	print("Attack style manager ready")
	_register_default_styles()

# Initialize the manager with a weapon
func initialize(weapon_ref):
	print("Attack style manager initializing with weapon: ", weapon_ref.get_weapon_name() if weapon_ref else "None")
	weapon = weapon_ref
	
	# Get wielder reference
	if weapon:
		wielder = weapon.wielder
		print("Wielder set to: ", wielder.name if wielder else "None")
		
		# Try to load style immediately
		var style_id = weapon.weapon_data.get("weapon_style", "melee")
		print("Attempting to load style: ", style_id)
		current_style = create_style(style_id)
		
		if current_style:
			print("Successfully loaded style: ", style_id)
		else:
			print("Failed to load style: ", style_id, " - trying fallback")
			current_style = create_fallback_style(style_id)
			if current_style:
				print("Successfully created fallback style")
	else:
		print("No weapon reference provided")

# Register built-in attack styles
func _register_default_styles():
	style_types = {
		"melee": "res://scripts/attack styles/melee_attack_style.gd",
		"projectile": "res://scripts/attack styles/projectile_attack_style.gd",
		"wave": "res://scripts/attack styles/wave_attack_style.gd",
		"pull": "res://scripts/attack styles/pull_attack_style.gd",
		"push": "res://scripts/attack styles/push_attack_style.gd",
		"area": "res://scripts/attack styles/area_attack_style.gd",
		"singularity": "res://scripts/attack styles/singularity_attack_style.gd"
	}
	
	# Verify files exist
	for style_id in style_types:
		var path = style_types[style_id]
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			print("Style script exists: ", style_id)
			file.close()
		else:
			print("WARNING: Style script missing: ", style_id, " at path ", path)
	
	print("Registered styles: ", style_types.keys())

# Create an attack style instance
func create_style(style_id: String):
	print("Creating attack style: ", style_id)
	
	if style_id in style_types:
		var script_path = style_types[style_id]
		print("Script path: ", script_path)
		
		var style_script = load(script_path)
		if style_script:
			print("Script loaded successfully")
			var style_instance = style_script.new()
			print("Instance created: ", style_instance)
			
			# Initialize the style
			if style_instance.has_method("initialize"):
				print("Calling initialize method")
				style_instance.initialize(weapon)
				print("Style initialized")
			else:
				print("WARNING: Style doesn't have initialize method")
			
			return style_instance
		else:
			print("Failed to load script: ", script_path)
			
			# Try creating a fallback style
			print("Creating fallback style")
			return create_fallback_style(style_id)
	else:
		print("Unknown attack style: ", style_id)
	
	return null

# Create a fallback style if script loading fails
func create_fallback_style(style_id: String):
	print("Creating fallback style for: ", style_id)
	
	# Create a script for the fallback style
	var script = GDScript.new()
	
	var source_code = """
	extends Resource
	
	var weapon = null
	var wielder = null
	const DEBUG = true
	
	func initialize(weapon_ref):
		weapon = weapon_ref
		if weapon:
			wielder = weapon.wielder
		print("Fallback %s style initialized")
	
	func get_style_name() -> String:
		return "Fallback%sStyle"
	
	func execute_attack():
		print("Executing fallback %s attack")
		
		if !wielder or !weapon:
			print("Missing wielder or weapon reference")
			return
		
		# Create basic attack 
		var hitbox = Area2D.new()
		hitbox.name = "FallbackHitbox"
		
		# Add collision shape
		var collision = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = Vector2(50, 30)
		collision.shape = shape
		hitbox.add_child(collision)
		
		# Position the hitbox in front of the wielder
		if wielder and wielder.has_node("Sprite2D"):
			var attack_direction = 1 if wielder.get_node("Sprite2D").flip_h else -1
			hitbox.position.x = attack_direction * (shape.size.x / 2)
		
		# Set collision properties
		hitbox.collision_layer = 0
		if wielder and wielder.name == "Player1":
			hitbox.collision_mask = 4  # Detect Player 2
		else:
			hitbox.collision_mask = 2  # Detect Player 1
		
		# Apply hit logic
		hitbox.body_entered.connect(_on_body_entered)
		
		# Add to scene
		if wielder:
			wielder.add_child(hitbox)
			
			# Remove after delay
			var timer = Timer.new()
			timer.wait_time = 0.2
			timer.one_shot = true
			wielder.add_child(timer)
			timer.timeout.connect(func():
				if hitbox and is_instance_valid(hitbox):
					hitbox.queue_free()
				timer.queue_free()
			)
			timer.start()
		
		# Apply visual effects
		if weapon:
			weapon.apply_effects(null, "visual")
			weapon.on_attack_end()
	
	func _on_body_entered(body):
		if body == wielder:
			return
		print("Fallback hit: ", body.name)
		if body.has_method("take_damage"):
			var attack_direction = 1
			if wielder and wielder.has_node("Sprite2D"):
				attack_direction = 1 if wielder.get_node("Sprite2D").flip_h else -1
			var knockback_dir = Vector2(attack_direction, -0.3).normalized()
			var damage = weapon.calculate_damage()
			body.take_damage(damage, knockback_dir, 500.0)
			if weapon:
				weapon.apply_effects(body, "hit")
	""" % [style_id, style_id, style_id]
	
	script.source_code = source_code
	script.reload()
	
	# Create instance
	var fallback = Resource.new()
	fallback.set_script(script)
	
	# Initialize
	if fallback.has_method("initialize"):
		fallback.initialize(weapon)
	
	return fallback

# Execute the current attack style
func execute_attack():
	print("AttackStyleManager.execute_attack called")
	
	# If no style is loaded, try to load based on weapon
	if current_style == null and weapon:
		var style_id = weapon.weapon_data.get("weapon_style", "melee")
		print("No style loaded, trying to create style: ", style_id)
		current_style = create_style(style_id)
		
		# If still null, use fallback
		if current_style == null:
			print("Still no style, creating fallback")
			current_style = create_fallback_style(style_id)
	
	if current_style:
		print("Executing with style: ", current_style.get_script().resource_path)
		
		# Direct call to execute_attack without argument
		if current_style.has_method("execute_attack"):
			print("Calling execute_attack on style")
			current_style.execute_attack()
			return true
		else:
			print("ERROR: Style doesn't have execute_attack method")
	else:
		print("ERROR: No attack style loaded!")
	
	return false

# Check if a style is available
func has_style(style_id: String) -> bool:
	print("Checking for style: ", style_id, " - current style: ", current_style != null)
	return style_id in style_types and current_style != null
