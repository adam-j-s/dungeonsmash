# Core weapon class - Updated cooldown system
class_name Weapon
extends Node2D

const DEBUG = true  # Set to true only when debugging

# Weapon properties (loaded from database)
var weapon_id: String = "sword"  # Default ID
var weapon_data: Dictionary = {}

# Visual components
var weapon_sprite: Sprite2D = null

# Current state
var cooldown_timer: Timer = null
var can_attack: bool = true
var wielder = null  # Reference to the character wielding the weapon

# NEW: Direct cooldown handling
var base_cooldown = 0.1  # Default if not specified in weapon data
var min_safety_cooldown = 0.016  # ~60fps, absolute minimum for safety

# Input buffering system
var input_buffer_time = 0.08  # 80ms buffer window
var buffered_attack = false

# Helper components
var attack_handler = null
var effect_handler = null
var behavior_manager = null

# Signal when weapon is used
signal weapon_used(weapon_id)

func _ready():
	# Set up cooldown timer
	cooldown_timer = Timer.new()
	cooldown_timer.one_shot = true
	cooldown_timer.timeout.connect(_on_cooldown_timeout)
	add_child(cooldown_timer)
	
	# Create helper components
	_setup_handlers()
	
	# Load the default weapon if no ID has been set yet
	if weapon_data.is_empty():
		load_weapon(weapon_id)

func _process(delta):
	# Check for buffered attacks
	if buffered_attack and can_attack:
		buffered_attack = false
		perform_attack()
	
	# If cooldown is almost complete, check for input to buffer
	if cooldown_timer and cooldown_timer.time_left <= input_buffer_time:
		# This would normally check direct input, but we'll rely on the player script
		# to call perform_attack(), which will be buffered if within the window
		pass
	
	# Update cooldown visualization if needed
	if wielder and cooldown_timer and cooldown_timer.time_left > 0:
		# Calculate cooldown percentage
		var cooldown_percent = cooldown_timer.time_left / cooldown_timer.wait_time
		
		# Update wielder's UI if available
		if wielder.has_node("CooldownBar"):
			wielder.get_node("CooldownBar").value = 1.0 - cooldown_percent

# Create the specialized handler components
func _setup_handlers():
	# Create attack handler
	attack_handler = load("res://scripts/weapon_attacks.gd").new()
	attack_handler.name = "AttackHandler"
	attack_handler.weapon = self
	if wielder:
		attack_handler.wielder = wielder
	add_child(attack_handler)
	
	# Create effect handler
	effect_handler = load("res://scripts/weapon_effects.gd").new()
	effect_handler.name = "EffectHandler"
	effect_handler.weapon = self
	add_child(effect_handler)
	
	# Create behavior manager
	behavior_manager = load("res://scripts/behaviors/behavior_manager.gd").new()
	behavior_manager.name = "BehaviorManager"
	add_child(behavior_manager)
	behavior_manager.initialize(self)

# Load weapon data from the database
func load_weapon(id: String):
	weapon_id = id
	weapon_data = WeaponDatabase.get_weapon(id)
	
	# Get cooldown directly from weapon data with fallback calculations
	if cooldown_timer != null:
		# First try to get explicit cooldown
		if "cooldown" in weapon_data:
			base_cooldown = float(weapon_data["cooldown"])
		# Fall back to calculating from attack_speed if needed
		elif "attack_speed" in weapon_data:
			base_cooldown = 1.0 / float(weapon_data.get("attack_speed", 1.0))
		else:
			base_cooldown = 0.5  # Default if neither is specified
			
		cooldown_timer.wait_time = base_cooldown
	
	# Update visuals
	update_appearance()
	
	# Load behaviors for this weapon
	if behavior_manager:
		behavior_manager.load_behaviors_from_weapon()
	
	if DEBUG:
		print("Loaded weapon: " + weapon_data.get("name", "Unknown"))
	else:
		print("Loaded weapon: " + weapon_data.get("name", "Unknown"))

# Update the weapon's visual appearance
func update_appearance():
	# Create a visual for the weapon if it doesn't exist
	if weapon_sprite == null:
		weapon_sprite = Sprite2D.new()
		add_child(weapon_sprite)
		
		# Remove any existing children
		for child in weapon_sprite.get_children():
			child.queue_free()
		
		# Create weapon visual based on type
		var weapon_type = get_weapon_type()
		match weapon_type:
			"sword":
				# Create a sword-like rectangle
				var rect = ColorRect.new()
				rect.size = Vector2(20, 5)  # Long rectangle for sword
				rect.position = Vector2(-10, -2.5)  # Center it
				weapon_sprite.add_child(rect)
			"staff":
				# Create a staff-like shape (stick with orb)
				var stick = ColorRect.new()
				stick.size = Vector2(4, 25)  # Thin, tall rectangle for staff
				stick.position = Vector2(-2, -15)  # Center it
				weapon_sprite.add_child(stick)
				
				var orb = ColorRect.new()
				orb.size = Vector2(12, 12)  # Circle-like shape for staff top
				orb.position = Vector2(-6, -25)  # Position at top of staff
				weapon_sprite.add_child(orb)
			_:
				# Default shape
				var rect = ColorRect.new()
				rect.size = Vector2(15, 15)  # Square for unknown
				rect.position = Vector2(-7.5, -7.5)  # Center it
				weapon_sprite.add_child(rect)
	
	# Set color based on weapon type
	var base_colors = {
		"sword": Color(0.8, 0.2, 0.2),  # Red for sword
		"staff": Color(0.2, 0.2, 0.8),  # Blue for staff
	}
	
	# Get the correct color for this weapon type
	var weapon_type = weapon_data.get("weapon_type", "sword")
	var base_color = base_colors.get(weapon_type, Color(0.5, 0.5, 0.5))
	
	# Apply tier tinting
	var tier = int(weapon_data.get("tier", 0))
	var tier_factor = min(tier * 0.2, 0.8)  # Up to 80% gold tint for higher tiers
	var gold_color = Color(1.0, 0.8, 0.0)
	var final_color = base_color.lerp(gold_color, tier_factor)
	
	# Apply the color to all ColorRect children
	for child in weapon_sprite.get_children():
		if child is ColorRect:
			child.color = final_color
	
	# Make the sprite visible
	weapon_sprite.visible = true
	
	# Debug print the appearance
	if DEBUG:
		print("Updated weapon appearance: " + get_weapon_name() + " (" + weapon_type + ")")
	else:
		print("Updated weapon appearance: " + get_weapon_name() + " (" + weapon_type + ")")

# Initialize this weapon with a character
func initialize(character):
	print("Weapon initializing with character: ", character.name if character else "None")
	wielder = character
	
	# Also update references in handlers
	if attack_handler:
		attack_handler.weapon = self
		attack_handler.wielder = character
		# Force initialize the attack handler
		if attack_handler.has_method("initialize"):
			attack_handler.initialize(self)
	
	if effect_handler:
		effect_handler.weapon = self
		effect_handler.wielder = character
	
	if behavior_manager:
		behavior_manager.initialize(self)

# Get the weapon's type
func get_weapon_type() -> String:
	return weapon_data.get("weapon_type", "sword")

# Get the weapon's name
func get_weapon_name() -> String:
	return weapon_data.get("name", "Basic Weapon")

# Calculate damage based on weapon stats and wielder's stats
func calculate_damage() -> int:
	var base_damage = int(weapon_data.get("damage", 10))
	
	if wielder and wielder.has_method("get_weapon_multiplier"):
		var multiplier = wielder.get_weapon_multiplier(get_weapon_type())
		base_damage = round(base_damage * multiplier)
		
	return base_damage

# Perform an attack - Main entry point that delegates to attack handler
func perform_attack():
	# Buffer the attack if we're close to being able to attack
	if !can_attack and cooldown_timer and cooldown_timer.time_left <= input_buffer_time:
		buffered_attack = true
		print("Attack buffered - will execute when cooldown completes")
		return true
	
	# Return if not ready to attack and not in buffer window
	if !can_attack:
		return false
		
	# Debug behavior manager
	if behavior_manager:
		print("Weapon has BehaviorManager with ", behavior_manager.behaviors.size(), " behaviors")
	
	# Create a visual flash for attack feedback
	create_attack_flash()
	
	# Start cooldown immediately
	start_cooldown()
	
	# Debug output
	if DEBUG:
		print("Weapon performing attack: " + get_weapon_name())
	
	# Get attack style
	var attack_style = weapon_data.get("weapon_style", "melee")
	if DEBUG:
		print("Attack style: " + attack_style)
	
	# Check if attack handler has been properly initialized
	if attack_handler and attack_handler.has_method("initialize"):
		if attack_handler.weapon != self or attack_handler.wielder != wielder:
			print("Attack handler not properly initialized, reinitializing")
			attack_handler.weapon = self
			attack_handler.wielder = wielder
			attack_handler.initialize(self)
	
	# Notify behaviors of attack
	if behavior_manager:
		behavior_manager.on_weapon_used()
	
	# Delegate to attack handler
	if attack_handler:
		attack_handler.execute_attack(attack_style)
		
		# Notify behaviors of attack execution
		if behavior_manager:
			behavior_manager.on_attack_executed(attack_style)
	
	# Emit signal
	emit_signal("weapon_used", weapon_id)
	
	return true

# NEW: Separated cooldown start function
func start_cooldown():
	can_attack = false
	if cooldown_timer:
		# Apply cooldown modifications from behaviors before starting timer
		var modified_cooldown = calculate_cooldown_time()
		cooldown_timer.wait_time = modified_cooldown
		cooldown_timer.start()
		
		if DEBUG:
			print("Starting cooldown: ", modified_cooldown, "s")

# NEW: Calculate cooldown with modifiers
func calculate_cooldown_time() -> float:
	var modified_cooldown = base_cooldown
	
	# Apply behavior modifiers
	if behavior_manager:
		modified_cooldown = behavior_manager.modify_cooldown(base_cooldown)
	
	# Safety minimum
	return max(modified_cooldown, min_safety_cooldown)

# Create a brief flash for attack feedback
func create_attack_flash():
	if !wielder:
		return
		
	var flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0.3)
	flash.size = Vector2(50, 50)
	flash.position = Vector2(-25, -25)
	wielder.add_child(flash)
	
	# Quick fade out
	var tween = flash.create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.1)
	tween.tween_callback(flash.queue_free)

# Apply effects - delegate to effect handler
func apply_effects(target, effect_type="hit"):
	if effect_handler:
		effect_handler.apply_effects(target, effect_type)
	
	# Notify behaviors of hit
	if effect_type == "hit" and behavior_manager and target:
		behavior_manager.on_hit(target)

# Notify the behavior system of a projectile creation
func on_projectile_created(projectile):
	if behavior_manager:
		print("Applying behaviors from weapon to projectile")
		behavior_manager.apply_behaviors_to_projectile(projectile)

# Notify the behavior system of attack end
func on_attack_end():
	if behavior_manager:
		behavior_manager.on_attack_end()

# Cooldown timer callback - use deferred call to ensure frame sync
func _on_cooldown_timeout():
	call_deferred("set_can_attack", true)

# Set attack state with proper timing
func set_can_attack(value):
	can_attack = value
	
	# Process any buffered attacks immediately
	if can_attack and buffered_attack:
		print("Executing buffered attack")
		buffered_attack = false
		perform_attack()
