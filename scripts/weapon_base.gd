# weapon_base.gd - Core weapon class
class_name Weapon
extends Node2D

const DEBUG = false  # Set to true only when debugging

# Weapon properties (loaded from database)
var weapon_id: String = "sword"  # Default ID
var weapon_data: Dictionary = {}

# Visual components
var weapon_sprite: Sprite2D = null

# Current state
var cooldown_timer: Timer = null
var can_attack: bool = true
var wielder = null  # Reference to the character wielding the weapon

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

# Create the specialized handler components
func _setup_handlers():
	# Create attack handler
	attack_handler = load("res://scripts/weapon_attacks.gd").new()
	attack_handler.name = "AttackHandler"
	attack_handler.weapon = self
	add_child(attack_handler)
	
	# Create effect handler
	effect_handler = load("res://scripts/weapon_effects.gd").new()
	effect_handler.name = "EffectHandler"
	effect_handler.weapon = self
	add_child(effect_handler)
	
	# Create behavior manager
	behavior_manager = load("res://scripts/behavior_manager.gd").new()
	behavior_manager.name = "BehaviorManager"
	add_child(behavior_manager)
	behavior_manager.initialize(self)

# Load weapon data from the database
func load_weapon(id: String):
	weapon_id = id
	weapon_data = WeaponDatabase.get_weapon(id)
	
	# Update cooldown timer
	if cooldown_timer != null:
		cooldown_timer.wait_time = 1.0 / float(weapon_data.get("attack_speed", 1.0))
	
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
	wielder = character
	
	# Also update references in handlers
	if attack_handler:
		attack_handler.wielder = character
	if effect_handler:
		effect_handler.wielder = character

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
	if !can_attack:
		return false
	
	# Start cooldown
	can_attack = false
	if cooldown_timer:
		cooldown_timer.start()
	
	# Debug output
	if DEBUG:
		print("Weapon performing attack: " + get_weapon_name())
	else:
		print("Weapon performing attack: " + get_weapon_name())
	
	# Get attack style
	var attack_style = weapon_data.get("weapon_style", "melee")
	if DEBUG:
		print("Attack style: " + attack_style)
	else:
		print("Attack style: " + attack_style)
	
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
		behavior_manager.on_projectile_created(projectile)

# Notify the behavior system of attack end
func on_attack_end():
	if behavior_manager:
		behavior_manager.on_attack_end()

# Cooldown timer callback
func _on_cooldown_timeout():
	can_attack = true
	
	# Apply cooldown modifications from behaviors
	if behavior_manager:
		var cooldown_multiplier = behavior_manager.calculate_cooldown_multiplier()
		if cooldown_multiplier != 1.0 and cooldown_timer:
			cooldown_timer.wait_time = (1.0 / float(weapon_data.get("attack_speed", 1.0))) * cooldown_multiplier
