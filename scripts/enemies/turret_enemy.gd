# turret_enemy.gd
extends BaseEnemy

@export var projectile_scene: PackedScene
@export var fire_interval: float = 2.0
@export var projectile_speed: float = 200.0
@export var attack_range: float = 400.0
@export var telegraph_time: float = 0.5

var fire_timer: float = 0.0
var is_telegraphing: bool = false
var telegraph_timer: float = 0.0

@onready var sprite = $Sprite2D

func _ready():
	super._ready()
	
	# Randomize initial timer
	fire_timer = randf() * fire_interval * 0.5
	
	print("Turret enemy initialized")

func _physics_process(delta):
	# Apply gravity to stay grounded
	velocity.y += gravity * delta
	velocity.x = 0  # Stay in place horizontally
	
	# Process firing logic
	if is_telegraphing:
		telegraph_timer += delta
		
		# Visual feedback
		if sprite:
			var flash_intensity = sin(telegraph_timer * 15)
			sprite.modulate = Color(1, 1 - flash_intensity * 0.5, 1 - flash_intensity * 0.5)
		
		# Fire when telegraph complete
		if telegraph_timer >= telegraph_time:
			fire_projectile()
			is_telegraphing = false
			telegraph_timer = 0.0
			fire_timer = 0.0
			
			# Reset visuals
			if sprite:
				sprite.modulate = Color.WHITE
	else:
		# Update firing timer
		fire_timer += delta
		
		# Check if it's time to prepare firing
		if fire_timer >= fire_interval:
			# Only fire if player is within range and visible
			if _target_node and can_see_target():
				is_telegraphing = true
				telegraph_timer = 0.0
			else:
				# Reset timer if target not suitable
				fire_timer = fire_interval * 0.5
	
	move_and_slide()

func can_see_target() -> bool:
	if not _target_node:
		return false
		
	# Check distance
	var distance = global_position.distance_to(_target_node.global_position)
	if distance > attack_range:
		return false
		
	# Line of sight check
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		_target_node.global_position,
		collision_mask,
		[self]
	)
	var result = space_state.intersect_ray(query)
	
	# Return true if no obstacles or if the only thing hit is the target
	return !result or result.collider == _target_node

func fire_projectile():
	if not _target_node or not projectile_scene:
		return
		
	print("Turret firing projectile at player")
	
	# Create projectile instance
	var projectile = projectile_scene.instantiate()
	
	# Set projectile properties
	projectile.global_position = global_position
	
	# Calculate direction to target with slight lead
	var dir_to_target = (_target_node.global_position - global_position).normalized()
	
	# Add some variation to make it slightly inaccurate
	var angle_variation = randf_range(-0.1, 0.1)
	dir_to_target = dir_to_target.rotated(angle_variation)
	
	# Set projectile properties if available
	if projectile.has_method("set_direction"):
		projectile.set_direction(dir_to_target)
	
	if projectile.has_method("set_speed"):
		projectile.set_speed(projectile_speed)
	
	if projectile.has_method("set_damage"):
		projectile.set_damage(15)  # Standard damage
	
	if projectile.has_method("set_source"):
		projectile.set_source(self)
	
	# Add to the scene tree
	get_tree().root.add_child(projectile)

# For player to set target
func set_target(target):
	_target_node = target
