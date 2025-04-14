# Core weapon class - JSON Format
class_name Weapon
extends Node2D

const DEBUG = false  # Set to true only when debugging

# Weapon properties
var weapon_id: String = "sword"  # Default ID
var weapon_data: Dictionary = {}

# Visual components
var weapon_sprite: Sprite2D = null

# Current state
var cooldown_timer: Timer = null
var can_attack: bool = true
var wielder = null  # Reference to the character wielding the weapon

# Twin-stick aiming support
var aim_direction = Vector2.RIGHT  # Default aim direction

# Direct cooldown handling
var base_cooldown = 0.1  # Default if not specified in weapon data
var min_safety_cooldown = 0.008  # ~60fps, absolute minimum for safety

# Input buffering system
var input_buffer_time = 0.08  # 80ms buffer window
var buffered_attack = false

# Helper components
var attack_handler = null
var effect_handler = null
var behavior_manager = null

# Signal when weapon is used
signal weapon_used(weapon_id)
# Signal when cooldown changes (progress from 0.0 to 1.0)
signal cooldown_changed
# Signal when cooldown is complete
signal cooldown_completed

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
	# Update aim direction from wielder if available
	if wielder != null:
		# Use the wielder's centralized direction function if available
		if wielder.has_method("get_attack_direction_value"):
			aim_direction = wielder.get_attack_direction_value()
			if DEBUG:
				print("Using player's get_attack_direction_value(): ", aim_direction)
		# Fallback to old direction method
		elif "aim_direction" in wielder:
			aim_direction = wielder.aim_direction
		
		# Update attack handler with new aim direction
		if attack_handler:
			attack_handler.aim_direction = aim_direction
	
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
	if cooldown_timer and cooldown_timer.time_left > 0:
		# Calculate cooldown progress (0.0 = just started, 1.0 = complete)
		var progress = 1.0 - (cooldown_timer.time_left / cooldown_timer.wait_time)
		
		# Emit signal for cooldown meter
		emit_signal("cooldown_changed", progress)
		
		# Legacy UI update if it exists
		if wielder and wielder.has_node("CooldownBar"):
			wielder.get_node("CooldownBar").value = progress

# Create the specialized handler components
func _setup_handlers():
	# Create attack handler
	attack_handler = load("res://scripts/weapon_attacks.gd").new()
	attack_handler.name = "AttackHandler"
	attack_handler.weapon = self
	if wielder:
		attack_handler.wielder = wielder
	# Pass aim direction to attack handler
	attack_handler.aim_direction = aim_direction
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

# Load weapon data from the database - JSON version
func load_weapon(id: String):
	weapon_id = id
	weapon_data = WeaponDatabase.get_weapon(id)
	
	# Get cooldown from weapon data with proper JSON structure
	if cooldown_timer != null:
		# Get from stats section if available
		if "stats" in weapon_data and "cooldown" in weapon_data.stats:
			base_cooldown = float(weapon_data.stats.cooldown)
		elif "cooldown" in weapon_data:
			base_cooldown = float(weapon_data.cooldown)
		# Fall back to calculating from attack_speed if needed
		elif "stats" in weapon_data and "attack_speed" in weapon_data.stats:
			base_cooldown = 1.0 / float(weapon_data.stats.attack_speed)
		elif "attack_speed" in weapon_data:
			base_cooldown = 1.0 / float(weapon_data.attack_speed)
		else:
			base_cooldown = 0.5  # Default if neither is specified
			
		cooldown_timer.wait_time = base_cooldown
	
	# Load flags (friendly fire, self-damage)
	if "flags" in weapon_data:
		# Load flags from JSON structure
		var friendly_fire = weapon_data.flags.get("friendly_fire", false)
		var allow_self_damage = weapon_data.flags.get("allow_self_damage", false)
		
		set_meta("friendly_fire", friendly_fire)
		set_meta("allow_self_damage", allow_self_damage)
		
		if DEBUG:
			print("WEAPON LOADING: Loaded flags - friendly_fire: ", friendly_fire, 
				  ", allow_self_damage: ", allow_self_damage)
	else:
		# Fallback for flat structure
		var friendly_fire_raw = weapon_data.get("friendly_fire", false)
		var allow_self_damage_raw = weapon_data.get("allow_self_damage", false)
		
		# Process flags with better type handling
		var friendly_fire = _process_bool_value(friendly_fire_raw)
		var allow_self_damage = _process_bool_value(allow_self_damage_raw)
		
		set_meta("friendly_fire", friendly_fire)
		set_meta("allow_self_damage", allow_self_damage)
		
		if DEBUG:
			print("WEAPON LOADING: Loaded flat flags - friendly_fire: ", friendly_fire, 
				  ", allow_self_damage: ", allow_self_damage)
	
	# Update visual appearance
	update_appearance()
	
	# Load behaviors for this weapon
	if behavior_manager:
		behavior_manager.load_behaviors_from_weapon()
	
	if DEBUG:
		print("Loaded weapon: " + weapon_data.get("name", "Unknown"))

# Helper to process boolean values with better type handling
func _process_bool_value(value) -> bool:
	match typeof(value):
		TYPE_BOOL:
			return value
		TYPE_INT:
			return value != 0
		TYPE_STRING:
			return value.to_lower() == "true"
		_:
			return bool(value)

# Update the weapon's visual appearance
func update_appearance():
	# Check for sprite path in weapon data
	var sprite_path = ""
	if "sprite_path" in weapon_data:
		sprite_path = weapon_data.sprite_path
	
	if sprite_path != "":
		print("Loading sprite from path: " + sprite_path)
		
		# Try to load the sprite
		var texture = load(sprite_path)
		if texture:
			print("Sprite loaded successfully")
			
			# Create sprite node if needed
			if not weapon_sprite or not is_instance_valid(weapon_sprite):
				weapon_sprite = Sprite2D.new()
				add_child(weapon_sprite)
			
			# Update the texture
			weapon_sprite.texture = texture
			
			# Adjust scale if needed
			weapon_sprite.scale = Vector2(1, 1)  # Adjust this value to fit your game
			
			# Hide any existing visual elements
			for child in weapon_sprite.get_children():
				child.visible = false
			
			return  # Skip the rest of the appearance code
		else:
			print("Failed to load sprite from path: " + sprite_path)
	
	# Fall back to creating a color rectangle visual
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
	var weapon_type = get_weapon_type()
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

# Initialize this weapon with a character
func initialize(character):
	print("Weapon initializing with character: ", character.name if character else "None")
	wielder = character
	
	# Get initial aim direction from wielder using the centralized function if available
	if wielder != null:
		if wielder.has_method("get_attack_direction_value"):
			aim_direction = wielder.get_attack_direction_value()
			if DEBUG:
				print("Setting initial aim_direction from player's get_attack_direction_value(): ", aim_direction)
		elif "aim_direction" in wielder:
			aim_direction = wielder.aim_direction
	
	# Also update references in handlers
	if attack_handler:
		attack_handler.weapon = self
		attack_handler.wielder = character
		attack_handler.aim_direction = aim_direction  # Pass aim direction
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
	var base_damage = 0
	
	# Get damage from proper place in JSON structure
	if "stats" in weapon_data and "damage" in weapon_data.stats:
		base_damage = int(weapon_data.stats.damage)
	else:
		base_damage = int(weapon_data.get("damage", 10))
	
	if wielder and wielder.has_method("get_weapon_multiplier"):
		var multiplier = wielder.get_weapon_multiplier(get_weapon_type())
		base_damage = round(base_damage * multiplier)
		
	return base_damage

# Get attack direction from wielder using centralized direction function
func get_attack_direction_from_wielder():
	print("DEBUG DIRECTION: Weapon using direction: ", aim_direction)
	if wielder == null:
		return aim_direction
		
	# Try to use the player's centralized direction function
	if wielder.has_method("get_attack_direction_value"):
		return wielder.get_attack_direction_value()
	
	# Fallback to the aim_direction property
	if "aim_direction" in wielder:
		return wielder.aim_direction
		
	# Default fallback
	return aim_direction

# Perform an attack - Main entry point that delegates to attack handler
func perform_attack():
	# Update aim direction from wielder using the centralized function
	aim_direction = get_attack_direction_from_wielder()
	
	# Debug output
	if DEBUG:
		print("Weapon aim direction updated for attack: ", aim_direction)
	
	# Buffer the attack if we're close to being able to attack
	if !can_attack and cooldown_timer and cooldown_timer.time_left <= input_buffer_time:
		buffered_attack = true
		print("Attack buffered - will execute when cooldown completes")
		return true
	
	# Return if not ready to attack and not in buffer window
	if !can_attack:
		if DEBUG:
			print("Cannot attack - cooldown active")
		return false
	
	# Debug behavior manager
	if behavior_manager:
		print("Weapon has BehaviorManager with ", behavior_manager.behaviors.size(), " behaviors")
	
	# Create a visual flash for attack feedback
	create_attack_flash()
	
	# Debug output
	print("Starting cooldown on weapon:", get_weapon_name())
	print("Base cooldown:", base_cooldown, "s")
	
	# Start cooldown immediately
	start_cooldown()
	
	# Debug output
	if DEBUG:
		print("Weapon performing attack: " + get_weapon_name())
	
	# Get attack style from proper location in JSON structure
	var attack_style = ""
	if "weapon_style" in weapon_data:
		attack_style = weapon_data.weapon_style
	else:
		attack_style = weapon_data.get("weapon_style", "melee")
		
	if DEBUG:
		print("Attack style: " + attack_style)
	
	# Check if attack handler has been properly initialized
	if attack_handler and attack_handler.has_method("initialize"):
		if attack_handler.weapon != self or attack_handler.wielder != wielder:
			print("Attack handler not properly initialized, reinitializing")
			attack_handler.weapon = self
			attack_handler.wielder = wielder
			attack_handler.aim_direction = aim_direction  # Pass updated aim direction
			attack_handler.initialize(self)
		else:
			# Just update aim direction if already initialized
			attack_handler.aim_direction = aim_direction
	
	# Notify behaviors of attack
	if behavior_manager:
		behavior_manager.on_weapon_used()
	
	# Delegate to attack handler
	var attack_success = true
	if attack_handler:
		attack_success = attack_handler.execute_attack(attack_style)
		
		# If attack failed, reset state and cancel cooldown
		if !attack_success:
			can_attack = true
			if cooldown_timer and !cooldown_timer.is_stopped():
				cooldown_timer.stop()
			return false
		
		# Notify behaviors of attack execution
		if behavior_manager:
			behavior_manager.on_attack_executed(attack_style)
	else:
		# No attack handler - attack fails
		can_attack = true
		if cooldown_timer and !cooldown_timer.is_stopped():
			cooldown_timer.stop()
		return false
	
	# Emit signal
	emit_signal("weapon_used", weapon_id)
	
	return true

# Separated cooldown start function
func start_cooldown():
	can_attack = false
	if cooldown_timer:
		# Apply cooldown modifications from behaviors before starting timer
		var modified_cooldown = calculate_cooldown_time()
		cooldown_timer.wait_time = modified_cooldown
		cooldown_timer.start()
		
		#emit signal with zero progress when cooldown starts
		emit_signal("cooldown_changed", 0.0)
		
		if DEBUG:
			print("Starting cooldown: ", modified_cooldown, "s, timer active:", !cooldown_timer.is_stopped())

# Calculate cooldown with modifiers
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
	# First, emit a final update with progress at 1.0
	emit_signal("cooldown_changed", 1.0)
	
	# Then proceed with the normal cooldown completion logic
	call_deferred("set_can_attack", true)
	emit_signal("cooldown_completed")
	
# Set attack state with proper timing
func set_can_attack(value):
	var old_value = can_attack
	can_attack = value
	
	# Process any buffered attacks immediately
	if can_attack and buffered_attack:
		print("Executing buffered attack")
		buffered_attack = false
		perform_attack()
	if !old_value && can_attack:
		print("Weapon cooldown complete:", get_weapon_name())
