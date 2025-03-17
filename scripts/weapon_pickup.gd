extends Area2D

# Create an enum for weapon types
enum WeaponType {SWORD, STAFF, RANDOM}
# Use the enum for the export variable
@export var weapon_type: WeaponType = WeaponType.SWORD
@export var pickup_respawn_time: float = 15.0  # Time until respawn

# List of available weapons for random selection
var available_weapons = [WeaponType.SWORD, WeaponType.STAFF]
var current_weapon_type = WeaponType.SWORD
var sprite = null
var is_available = true

func _ready():
	# We'll use a physics process to check for overlapping bodies
	# This is more reliable than the body_entered signal in some cases
	set_physics_process(true)
	
	# If set to random, pick a random weapon type
	if weapon_type == WeaponType.RANDOM:
		randomize_weapon()
	else:
		current_weapon_type = weapon_type
	
	# Create visuals if they don't exist
	if get_child_count() == 0:
		setup_pickup()
	
	# Debug print
	print("Weapon pickup initialized: " + get_weapon_name(current_weapon_type))

func randomize_weapon():
	# Choose a random weapon from available types (excluding RANDOM)
	current_weapon_type = available_weapons[randi() % available_weapons.size()]

func get_weapon_name(type: WeaponType) -> String:
	match type:
		WeaponType.SWORD:
			return "sword"
		WeaponType.STAFF:
			return "staff"
		WeaponType.RANDOM:
			return "random"
		_:
			return "unknown"

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

func _physics_process(_delta):
	# Only check for pickup if available
	if is_available:
		var bodies = get_overlapping_bodies()
		for body in bodies:
			if body.is_in_group("players") and body.has_method("equip_weapon"):
				give_weapon_to_player(body)
				break

func give_weapon_to_player(player):
	var weapon_name = get_weapon_name(current_weapon_type)
	print("Giving " + weapon_name + " to " + player.name)
	
	# Create the proper weapon
	var weapon = null
	match current_weapon_type:
		WeaponType.SWORD:
			weapon = load("res://scripts/sword.gd").new()
		WeaponType.STAFF:
			weapon = load("res://scripts/magic_staff.gd").new()
	
	if weapon:
		# Give it to the player
		player.equip_weapon(weapon)
		
		# Make pickup unavailable
		is_available = false
		sprite.visible = false
		
		# Respawn after delay
		await get_tree().create_timer(pickup_respawn_time).timeout
		
		# If set to random, pick a new random weapon type
		if weapon_type == WeaponType.RANDOM:
			randomize_weapon()
			# Update color to match new weapon
			sprite.color = get_weapon_color()
		
		# Make available again
		is_available = true
		sprite.visible = true
		print("Weapon pickup respawned as " + get_weapon_name(current_weapon_type))

func get_weapon_color():
	match current_weapon_type:
		WeaponType.SWORD:
			return Color(0.8, 0.2, 0.2)  # Red for sword
		WeaponType.STAFF:
			return Color(0.2, 0.2, 0.8)  # Blue for staff
		_:
			return Color(0.8, 0.8, 0.2)  # Yellow default
