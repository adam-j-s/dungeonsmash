# weapon_pickup.gd
extends Area2D

@export var weapon_type: String = "sword"  # Options: sword, staff, etc.
@export var pickup_respawn_time: float = 15.0  # Time until respawn

var weapon_scene = null
var sprite = null
var is_available = true

func _ready():
	# Set up collision
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 25
	collision.shape = shape
	add_child(collision)
	
	# Set up visual
	sprite = ColorRect.new()
	sprite.color = get_weapon_color()
	sprite.size = Vector2(30, 30)
	sprite.position = Vector2(-15, -15)
	add_child(sprite)
	
	# Set up signals
	body_entered.connect(_on_body_entered)
	
	# Determine weapon scene
	match weapon_type:
		"sword":
			weapon_scene = load("res://scripts/sword.gd")
		"staff":
			weapon_scene = load("res://scripts/magic_staff.gd")
		# Add more weapons as you create them

func get_weapon_color():
	match weapon_type:
		"sword":
			return Color(0.8, 0.2, 0.2)  # Red
		"staff":
			return Color(0.2, 0.2, 0.8)  # Blue
		_:
			return Color(0.8, 0.8, 0.2)  # Yellow

func _on_body_entered(body):
	if !is_available:
		return
		
	if body.has_method("equip_weapon") and weapon_scene != null:
		# Create the weapon
		var weapon = weapon_scene.new()
		
		# Give it to the player
		body.equip_weapon(weapon)
		
		# Make pickup unavailable
		is_available = false
		sprite.visible = false
		
		# Respawn after delay
		await get_tree().create_timer(pickup_respawn_time).timeout
		is_available = true
		sprite.visible = true
