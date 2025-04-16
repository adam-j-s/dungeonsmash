# jumper_enemy.gd with extensive debugging
extends BaseEnemy

# --- Jump Parameters ---
@export var jump_force: float = 300.0
@export var jump_interval: float = 2.0
@export var horizontal_jump_force: float = 150.0
@export var telegraph_time: float = 0.5
@export var detection_range: float = 300.0
@export var idle_movement: bool = true
@export var idle_speed: float = 20.0

# --- Internal State ---
var jump_timer: float = 0.0
var is_telegraphing: bool = false
var telegraph_timer: float = 0.0
var idle_direction: float = 1.0
var idle_direction_timer: float = 0.0
var debug_frames = 0

# --- References ---
@onready var sprite = $Sprite2D

func _ready():
	print("JUMPER ENEMY: _ready() called - THIS IS THE JUMPER SCRIPT")
	print("JUMPER ENEMY: Script path: ", get_script().resource_path)
	
	# Verify this is actually a jumper
	if not "jump_force" in self:
		print("ERROR: This object doesn't have jump_force. Wrong script loaded?")
	
	# Randomize initial timers
	jump_timer = randf() * jump_interval * 0.5
	idle_direction_timer = randf() * 3.0
	
	# Add a visual debug indicator
	if not sprite:
		print("JUMPER ENEMY: No sprite found, creating debug sprite")
		sprite = Sprite2D.new()
		add_child(sprite)
		
		# Set color to distinguish from bouncer
		var debug_polygon = Polygon2D.new()
		debug_polygon.polygon = PackedVector2Array([
			Vector2(-10, -10), Vector2(10, -10), Vector2(10, 10), Vector2(-10, 10)
		])
		debug_polygon.color = Color.BLUE  # Blue to distinguish from bouncer
		add_child(debug_polygon)
	
	print("JUMPER ENEMY: Initialization complete")

func _physics_process(delta):
	# Debug output every 60 frames
	debug_frames += 1
	if debug_frames >= 60:
		debug_frames = 0
		print("JUMPER ENEMY: State - is_telegraphing:", is_telegraphing, 
			  ", is_on_floor:", is_on_floor(),
			  ", jump_timer:", jump_timer, 
			  ", jump_interval:", jump_interval)
	
	# Apply gravity
	velocity.y += gravity * delta
	
	# State-based behavior
	if is_telegraphing:
		print("JUMPER ENEMY: In telegraphing state")
		# Update telegraph timer
		telegraph_timer += delta
		
		# Apply visual squash effect
		if sprite:
			var squash_factor = telegraph_timer / telegraph_time
			sprite.scale = Vector2(1.0 + squash_factor * 0.3, 1.0 - squash_factor * 0.3)
		
		# Keep the enemy stationary during telegraph
		velocity.x = 0
		
		# Execute jump when telegraph complete
		if telegraph_timer >= telegraph_time:
			print("JUMPER ENEMY: Telegraph complete, executing jump!")
			
			# Calculate and perform jump
			if _target_node:
				# Calculate jump direction toward player
				var to_target = _target_node.global_position - global_position
				var dir = sign(to_target.x)
				
				# Apply jump forces
				velocity.x = dir * horizontal_jump_force
				velocity.y = -jump_force
				
				print("JUMPER ENEMY: Jumping toward player! X: ", velocity.x, ", Y: ", velocity.y)
			else:
				# Jump in random direction if no target
				velocity.x = (randf() * 2.0 - 1.0) * horizontal_jump_force * 0.5
				velocity.y = -jump_force
				
				print("JUMPER ENEMY: Jumping randomly! X: ", velocity.x, ", Y: ", velocity.y)
			
			# Reset telegraph state
			is_telegraphing = false
			telegraph_timer = 0.0
			
			# Reset sprite scale
			if sprite:
				sprite.scale = Vector2(1.0, 1.0)
	elif is_on_floor():
		# Update jump timer
		jump_timer += delta
		
		# Slow horizontal movement
		velocity.x = move_toward(velocity.x, 0, move_speed * delta)
		
		# Check if it's time to jump
		if jump_timer >= jump_interval:
			# Only jump if player is within range
			if _target_node:
				var distance = global_position.distance_to(_target_node.global_position)
				print("JUMPER ENEMY: Jump timer expired, distance to player: ", distance, 
					  ", detection range: ", detection_range)
				if distance < detection_range:
					print("JUMPER ENEMY: Starting telegraph for jump!")
					is_telegraphing = true
					telegraph_timer = 0.0
					jump_timer = 0.0
				else:
					print("JUMPER ENEMY: Player out of range, resetting timer")
					jump_timer = 0.0
			else:
				print("JUMPER ENEMY: No target, resetting jump timer")
				jump_timer = 0.0
		
		# Idle movement when not about to jump
		if idle_movement and jump_timer < jump_interval - 0.5:
			# Update idle direction timer
			idle_direction_timer -= delta
			if idle_direction_timer <= 0:
				# Change direction
				idle_direction = -idle_direction
				idle_direction_timer = randf_range(1.0, 3.0)
				print("JUMPER ENEMY: Changed idle direction to: ", idle_direction)
			
			# Move slowly in idle direction
			velocity.x = idle_direction * idle_speed
			
			# Check for obstacles
			if is_on_wall():
				idle_direction = -idle_direction
				print("JUMPER ENEMY: Hit wall, reversed direction to: ", idle_direction)
	
	# Apply movement
	move_and_slide()

# This is called when the player enters/attacks
func take_damage(amount, hit_direction = Vector2.ZERO, knockback_strength = 0):
	print("JUMPER ENEMY: Taking damage: ", amount)
	super.take_damage(amount, hit_direction, knockback_strength)
	
	# Jump away when hit
	if is_on_floor() and not is_telegraphing:
		print("JUMPER ENEMY: Damage response - jumping away!")
		# Jump in the opposite direction from the hit
		velocity.x = -hit_direction.x * horizontal_jump_force * 0.8
		velocity.y = -jump_force * 0.7

# Make sure this is compatible with your battle arena
func set_target(target):
	print("JUMPER ENEMY: Setting target: ", target)
	_target_node = target
