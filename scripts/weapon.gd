class_name Weapon
extends Node2D

# Base weapon properties
@export var weapon_name: String = "Basic Weapon"
@export var damage: int = 10
@export var knockback_force: float = 500.0
@export var attack_speed: float = 1.0  # Attacks per second
@export var attack_range: Vector2 = Vector2(50, 30)  # Hitbox size

# Current state
var cooldown_timer: Timer
var can_attack: bool = true
var wielder = null  # Reference to the character wielding the weapon

func _ready():
	# Set up cooldown timer
	cooldown_timer = Timer.new()
	cooldown_timer.one_shot = true
	cooldown_timer.wait_time = 1.0 / attack_speed
	cooldown_timer.timeout.connect(_on_cooldown_timeout)
	add_child(cooldown_timer)

func initialize(character):
	# Called when a character equips this weapon
	wielder = character

func perform_attack():
	if !can_attack:
		return false
		
	# Start cooldown
	can_attack = false
	cooldown_timer.start()
	
	# Create attack hitbox
	create_hitbox()
	
	# Weapon-specific effects
	attack_effects()
	
	return true

func create_hitbox():
	# Create basic hitbox - to be overridden by specific weapons
	var hitbox = Area2D.new()
	hitbox.name = "WeaponHitbox"
	
	# Add collision shape
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = attack_range
	collision.shape = shape
	hitbox.add_child(collision)
	
	# Position the hitbox in front of the wielder
	var attack_direction = 1 if wielder.get_node("Sprite2D").flip_h else -1
	hitbox.position.x = attack_direction * (attack_range.x / 2)
	
	# Set collision properties
	hitbox.collision_layer = 0
	if wielder.name == "Player1":
		hitbox.collision_mask = 4  # Detect Player 2
	else:
		hitbox.collision_mask = 2  # Detect Player 1
	
	# Connect signal to detect hits
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	
	# Add to wielder
	wielder.add_child(hitbox)
	
	# Remove after short duration
	await get_tree().create_timer(0.2).timeout
	if hitbox and is_instance_valid(hitbox):
		hitbox.queue_free()

func _on_hitbox_body_entered(body):
	if body == wielder:
		return  # Don't hit yourself
		
	print("Weapon hit: ", body.name)
	
	# Check if the body can take damage
	if body.has_method("take_damage"):
		# Calculate knockback direction
		var attack_direction = 1 if wielder.get_node("Sprite2D").flip_h else -1
		var knockback_dir = Vector2(attack_direction, -0.3).normalized()
		
		# Apply damage and knockback
		body.take_damage(damage, knockback_dir, knockback_force)
		
		# Weapon hit effects
		on_hit_effects(body)

func attack_effects():
	# Visual or sound effects when attacking
	# Override in specific weapons
	pass

func on_hit_effects(target):
	# Effects that happen when a target is hit
	# Override in specific weapons
	pass

func _on_cooldown_timeout():
	can_attack = true
