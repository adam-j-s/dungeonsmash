# weapon_pickup.gd
extends Area2D

# Create an enum for weapon types
enum PickupMode {SPECIFIC, RANDOM_BY_TYPE, RANDOM_BY_TIER, FULLY_RANDOM}
# Use the enum for the export variable
@export var pickup_mode: PickupMode = PickupMode.SPECIFIC
@export var specific_weapon_id: String = "sword"  # Used when mode is SPECIFIC
@export var weapon_type: String = "sword"  # Used when mode is RANDOM_BY_TYPE
@export var max_tier: int = 0  # Used when mode is RANDOM_BY_TIER
@export var pickup_respawn_time: float = 15.0  # Time until respawn

# Runtime variables
var current_weapon_id: String = ""
var is_available = true
var sprite: ColorRect = null

func _ready():
	# We'll use a physics process to check for overlapping bodies
	set_physics_process(true)
	
	# Initialize the weapon based on selected mode
	select_weapon()
	
	# Create visuals if they don't exist
	if get_child_count() == 0:
		setup_pickup()
	
	# Debug print
	var weapon_data = WeaponDatabase.get_weapon(current_weapon_id)
	print("Weapon pickup initialized: " + weapon_data.name)

# Added method for directly setting a specific weapon ID
func set_weapon_id(id: String):
	current_weapon_id = id
	specific_weapon_id = id  # Also update specific ID for consistency
	pickup_mode = PickupMode.SPECIFIC  # Set mode to SPECIFIC
	
	# Update visual if already initialized
	if sprite:
		sprite.color = get_weapon_color()
		
	# Debug print
	var weapon_data = WeaponDatabase.get_weapon(current_weapon_id)
	print("Weapon pickup set to: " + weapon_data.name)

# Added method for weapon spawner to use
func set_pickup_mode(mode: int):
	pickup_mode = mode
	select_weapon()
	if sprite:
		sprite.color = get_weapon_color()

# Added method for weapon spawner to use
func update_pickup_mode(mode: int):
	pickup_mode = mode
	select_weapon()
	if sprite:
		sprite.color = get_weapon_color()

func select_weapon():
	match pickup_mode:
		PickupMode.SPECIFIC:
			current_weapon_id = specific_weapon_id
			
		PickupMode.RANDOM_BY_TYPE:
			var weapons_of_type = WeaponDatabase.get_weapons_by_type(weapon_type)
			if weapons_of_type.size() > 0:
				current_weapon_id = weapons_of_type[randi() % weapons_of_type.size()]
			else:
				current_weapon_id = "sword"  # Default fallback
				
		PickupMode.RANDOM_BY_TIER:
			var weapons_of_tier = WeaponDatabase.get_weapons_by_tier(max_tier)
			if weapons_of_tier.size() > 0:
				current_weapon_id = weapons_of_tier[randi() % weapons_of_tier.size()]
			else:
				current_weapon_id = "sword"  # Default fallback
				
		PickupMode.FULLY_RANDOM:
			var all_weapons = WeaponDatabase.weapons.keys()
			current_weapon_id = all_weapons[randi() % all_weapons.size()]

func setup_pickup():
	# Make sure we have a collision shape
	if !has_node("CollisionShape2D"):
		var collision = CollisionShape2D.new()
		var shape = CircleShape2D.new()
		shape.radius = 25
		collision.shape = shape
		add_child(collision)
	
	# Create visual representation
	sprite = ColorRect.new()
	sprite.name = "Sprite"
	sprite.color = get_weapon_color()
	sprite.size = Vector2(30, 30)
	sprite.position = Vector2(-15, -15)
	add_child(sprite)
	
	# Set collision properties
	collision_layer = 0  # This doesn't collide with anything
	collision_mask = 6   # This detects both players (layers 2 and 4)

func get_weapon_color():
	var weapon_data = WeaponDatabase.get_weapon(current_weapon_id)
	
	# Base colors for weapon types
	var type_colors = {
		"sword": Color(0.8, 0.2, 0.2),  # Red for sword
		"staff": Color(0.2, 0.2, 0.8),  # Blue for staff
	}
	
	# Get base color by type
	var base_color = type_colors.get(weapon_data.weapon_type, Color(0.5, 0.5, 0.5))
	
	# Add some gold tint based on tier
	var tier = weapon_data.tier
	var tier_factor = min(tier * 0.2, 0.8)  # Up to 80% gold tint for higher tiers
	
	# Mix with gold color
	var gold_color = Color(1.0, 0.8, 0.0)
	return base_color.lerp(gold_color, tier_factor)

func _physics_process(_delta):
	# Only check for pickup if available
	if is_available:
		var bodies = get_overlapping_bodies()
		for body in bodies:
			# More permissive check - any players group member
			if body.is_in_group("players"):
				# Print available methods to debug
				print("Player methods available: ", body.get_method_list().size())
				give_weapon_to_player(body)
				break

func give_weapon_to_player(player):
	var weapon_data = WeaponDatabase.get_weapon(current_weapon_id)
	print("Giving " + weapon_data.name + " to " + player.name)
	
	# Try different approaches to equip the weapon
	var weapon_equipped = false
	
	# Approach 1: Direct method call
	if player.has_method("equip_weapon_by_id"):
		print("Using equip_weapon_by_id method")
		player.equip_weapon_by_id(current_weapon_id)
		weapon_equipped = true
	# Approach 2: Alternative method
	elif player.has_method("equip_weapon"):
		print("Trying alternate approach with equip_weapon")
		var weapon = Weapon.new()
		weapon.load_weapon(current_weapon_id)
		player.equip_weapon(weapon)
		weapon_equipped = true
	# Log error if no approach works
	else:
		print("ERROR: Player has no methods to equip weapons!")
		
	if weapon_equipped:
		print("Weapon " + weapon_data.name + " successfully equipped on " + player.name)
	
	# Make pickup unavailable
	is_available = false
	sprite.visible = false
	
	# Respawn after delay
	await get_tree().create_timer(pickup_respawn_time).timeout
	
	# Select a new weapon based on the pickup mode
	select_weapon()
	
	# Update color to match new weapon
	sprite.color = get_weapon_color()
	
	# Make available again
	is_available = true
	sprite.visible = true
	
	var new_weapon_data = WeaponDatabase.get_weapon(current_weapon_id)
	print("Weapon pickup respawned as " + new_weapon_data.name)
