#Player 1
extends CharacterBody2D

# Base movement attributes
@export var SPEED = 300.0
@export var JUMP_VELOCITY = -400.0
@export var FALL_MULTIPLIER = 1.5
@export var LOW_JUMP_MULTIPLIER = 1.2

# Base attack attributes
@export var ATTACK_DAMAGE = 15
@export var ATTACK_KNOCKBACK = 600
@export var ATTACK_DURATION = 0.3
@export var ATTACK_COOLDOWN = 0.2
@export var ATTACK_RANGE = Vector2(50, 30)  # Width and height of attack hitbox

# Dash attributes
@export var DASH_SPEED = 800.0
@export var VERTICAL_DASH_SPEED = 800.0
@export var DOWNWARD_DASH_SPEED = 1200.0  # Faster for ground pound effect
@export var DASH_DURATION = 0.2
@export var DASH_COOLDOWN = 0.8
@export var MAX_DASH_CHARGES = 1
@export var MAX_JUMPS = 2
@export var GROUND_POUND_IMPACT_RADIUS = 50.0  # Area of effect for damaging others

# Wall grab attributes
@export var WALL_SLIDE_SPEED = 100.0  # How fast you slide down walls
@export var WALL_GRAB_TIME = 2.0      # Maximum time you can hold onto a wall
@export var WALL_JUMP_STRENGTH = Vector2(400, -400)  # Horizontal and vertical strength

# Health attributes
@export var MAX_HEALTH = 100
@export var KNOCKBACK_SCALING = 1.5  # Higher damage = more knockback

# Character state tracking
var jumps_made = 0
var dash_charges = 0
var is_dashing = false
var is_ground_pounding = false
var dash_recharge_timer = null
var base_gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var is_wall_grabbing = false
var wall_grab_direction = 0  # -1 for left wall, 1 for right wall
var wall_grab_timer = 0.0    # Tracks how long you've been on the wall
var is_attacking = false
var can_attack = true

# Health tracking
var health = MAX_HEALTH
var is_defeated = false
var health_bar = null
var health_fill = null
signal player_defeated(player_number)

# Weapon variables
var current_weapon = null
var weapons_inventory = []

func _ready():
	# Initialize dash charges to max at start
	dash_charges = MAX_DASH_CHARGES
	
	# Initialize health
	health = MAX_HEALTH
	is_defeated = false
	
	# Create a Timer for dash cooldown
	dash_recharge_timer = Timer.new()
	dash_recharge_timer.one_shot = true
	dash_recharge_timer.wait_time = DASH_COOLDOWN
	dash_recharge_timer.timeout.connect(recharge_dash)
	add_child(dash_recharge_timer)
	
	# Create health bar
	create_health_bar()
	
	# Start with a default weapon
	equip_default_weapon()

func create_health_bar():
	# Create a CanvasLayer for UI elements
	var ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	
	# Create health bar container
	health_bar = ColorRect.new()
	health_bar.name = "HealthBar"
	health_bar.color = Color(0.2, 0.2, 0.2, 0.8)  # Dark background
	health_bar.size = Vector2(200, 20)
	health_bar.position = Vector2(20, 20)  # Top-left corner
	ui_layer.add_child(health_bar)
	
	# Create health fill
	health_fill = ColorRect.new()
	health_fill.name = "HealthFill"
	health_fill.color = Color(1.0, 0.2, 0.2, 1.0)  # Red for health
	health_fill.size = Vector2(200, 20)
	health_fill.position = Vector2(30, 0)
	health_bar.add_child(health_fill)

func _physics_process(delta):
	# Update health bar
	update_health_bar()
	
	# Skip processing if defeated
	if is_defeated:
		return
		
	# Handle gravity
	if is_dashing:
		# Skip gravity when dashing
		pass
	elif not is_on_floor():
		# Apply gravity with better game feel
		if velocity.y > 0:
			velocity.y += base_gravity * FALL_MULTIPLIER * delta
		elif velocity.y < 0 && !Input.is_action_pressed("ui_accept"):
			velocity.y += base_gravity * LOW_JUMP_MULTIPLIER * delta
		else:
			velocity.y += base_gravity * delta
	else:
		# Reset jumps when touching the floor
		jumps_made = 0
		
		# Check if we just landed from a ground pound
		if is_ground_pounding:
			ground_pound_impact()
			is_ground_pounding = false
	
	# Wall grab logic
	if !is_on_floor():
		# Check if touching a wall
		var is_touching_wall_left = test_move(transform, Vector2(-1, 0))
		var is_touching_wall_right = test_move(transform, Vector2(1, 0))
		
		# Determine if we can grab the wall
		if (is_touching_wall_left or is_touching_wall_right) and !is_dashing and !is_ground_pounding:
			# If pressing LB and against a wall, grab it
			var horizontal_input = Input.get_axis("ui_left", "ui_right")
			
			if Input.is_action_pressed("ui_wall_grab") and ((is_touching_wall_left and horizontal_input < 0) or (is_touching_wall_right and horizontal_input > 0)):
				# Start wall grab
				if !is_wall_grabbing:
					wall_grab_timer = 0.0
					is_wall_grabbing = true
					
					# Determine wall direction
					wall_grab_direction = -1 if is_touching_wall_left else 1
					
					# Reset jumps when grabbing a wall
					jumps_made = 0
				
				# Limit wall grab time
				if wall_grab_timer < WALL_GRAB_TIME:
					# Slow falling while grabbing
					velocity.y = WALL_SLIDE_SPEED
					wall_grab_timer += delta
				else:
					# Time's up, let go
					is_wall_grabbing = false
					
				# Allow wall jump
				if Input.is_action_just_pressed("ui_accept"):
					# Jump away from wall
					velocity.x = -wall_grab_direction * WALL_JUMP_STRENGTH.x
					velocity.y = WALL_JUMP_STRENGTH.y
					is_wall_grabbing = false
			else:
				# Not pressing wall grab button, let go
				is_wall_grabbing = false
		else:
			# Not touching a wall
			is_wall_grabbing = false
	
	# Handle Jump (only when not wall grabbing)
	if Input.is_action_just_pressed("ui_accept") and jumps_made < MAX_JUMPS and !is_wall_grabbing:
		velocity.y = JUMP_VELOCITY
		jumps_made += 1
	
	# Get directional inputs
	var horizontal_input = Input.get_axis("ui_left", "ui_right")
	var vertical_input = Input.get_axis("ui_down", "ui_up")
	
	# Handle all dash variants (only when not wall grabbing)
	if Input.is_action_just_pressed("ui_dash") and dash_charges > 0 and !is_wall_grabbing:
		if horizontal_input != 0 and vertical_input != 0:
			# Diagonal dash
			start_diagonal_dash(horizontal_input, vertical_input)
		elif horizontal_input != 0:
			# Horizontal dash
			start_horizontal_dash(horizontal_input)
		elif vertical_input > 0:
			# Upward dash
			start_vertical_dash(-1)  # -1 for up
		elif vertical_input < 0:
			# Downward dash / ground pound
			start_ground_pound()
	
	# Normal movement (only when not dashing and not wall grabbing)
	if !is_dashing and !is_wall_grabbing:
		if horizontal_input:
			velocity.x = horizontal_input * SPEED
			# Update sprite direction
			if horizontal_input > 0:
				$Sprite2D.flip_h = true  # Adjust based on your sprite's default direction
			elif horizontal_input < 0:
				$Sprite2D.flip_h = false # Adjust based on your sprite's default direction
		else:
			# Stop horizontal movement when no direction pressed
			velocity.x = move_toward(velocity.x, 0, SPEED)
			
		# Handle attack input
		if Input.is_action_just_pressed("ui_attack") and can_attack and !is_dashing and !is_wall_grabbing:
			perform_attack()
	
	# Apply all movement
	move_and_slide()

func update_health_bar():
	# Update the width of the health fill based on current health
	if health_fill:
		var health_percent = float(health) / MAX_HEALTH
		health_fill.size.x = 200 * health_percent

func start_horizontal_dash(direction):
	consume_dash_charge()
	
	# Set dash velocity
	velocity.x = direction * DASH_SPEED
	velocity.y = 0  # No vertical movement during horizontal dash
	
	# End dash after duration
	await get_tree().create_timer(DASH_DURATION).timeout
	is_dashing = false

func start_vertical_dash(direction):
	consume_dash_charge()
	
	# Set dash velocity (negative Y is up in Godot)
	velocity.x = 0  # No horizontal movement during vertical dash
	velocity.y = direction * VERTICAL_DASH_SPEED
	
	# End dash after duration
	await get_tree().create_timer(DASH_DURATION).timeout
	is_dashing = false

func start_diagonal_dash(h_direction, v_direction):
	consume_dash_charge()
	
	# For diagonal movement, normalize the vector to maintain consistent speed
	var direction = Vector2(h_direction, -v_direction).normalized()
	
	# Set dash velocity
	velocity.x = direction.x * DASH_SPEED
	velocity.y = direction.y * VERTICAL_DASH_SPEED
	
	# End dash after duration
	await get_tree().create_timer(DASH_DURATION).timeout
	is_dashing = false

func start_ground_pound():
	consume_dash_charge()
	is_ground_pounding = true
	
	# Cancel horizontal momentum and set downward velocity
	velocity.x = 0
	velocity.y = DOWNWARD_DASH_SPEED
	
	# End the dashing state after duration, but keep ground_pounding flag
	await get_tree().create_timer(DASH_DURATION).timeout
	is_dashing = false
	
	# The impact will be handled in _physics_process when we hit the floor
func consume_dash_charge():
	is_dashing = true
	dash_charges -= 1
	print("Dash used. Remaining charges:", dash_charges)
	
	# If this was our first used charge, start the recharge timer
	if dash_charges == MAX_DASH_CHARGES - 1 and dash_recharge_timer.is_stopped():
		dash_recharge_timer.start()

func recharge_dash():
	# Add a dash charge
	if dash_charges < MAX_DASH_CHARGES:
		dash_charges += 1
		print("Dash recharged. Current charges:", dash_charges)
	
	# If we're still not at max charges, restart the timer
	if dash_charges < MAX_DASH_CHARGES:
		dash_recharge_timer.start()

func ground_pound_impact():
	# Create impact effect
	print("GROUND POUND IMPACT!")
	
	# Check for nearby players to damage
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	
	# Create a circle shape for the impact area
	var collision_shape = CircleShape2D.new()
	collision_shape.radius = GROUND_POUND_IMPACT_RADIUS
	
	query.shape = collision_shape
	query.transform = Transform2D(0, global_position)
	query.collision_mask = 4  # Adjust to match your player collision layer
	
	# Exclude self from the query
	query.exclude = [self]
	
	# Find all colliding bodies
	var results = space_state.intersect_shape(query)
	
	# Apply damage/knockback to each hit player
	for result in results:
		var collider = result.collider
		if collider.has_method("take_damage"):
			# Horizontal knockback away from impact point
			var knockback_dir = (collider.global_position - global_position).normalized()
			collider.take_damage(20, knockback_dir, 800)  # Damage, direction, force

func perform_attack():
	if !can_attack or is_attacking or is_dashing or is_wall_grabbing:
		return
		
	is_attacking = true
	can_attack = false
	
	print("Attempting to attack with weapon")
	
	# Use weapon if available
	if current_weapon != null:
		current_weapon.perform_attack()
	else:
		# Fallback to basic attack if no weapon
		create_basic_attack_hitbox()
	
	# Attack recovery
	await get_tree().create_timer(ATTACK_DURATION).timeout
	is_attacking = false
	
	# Attack cooldown
	await get_tree().create_timer(ATTACK_COOLDOWN).timeout
	can_attack = true

# Keep the existing attack code as a fallback
func create_basic_attack_hitbox():
	# Get attack direction based on sprite direction
	var attack_direction = 1 if $Sprite2D.flip_h else -1
	
	# Create a hitbox for the attack
	var hitbox = Area2D.new()
	hitbox.name = "AttackHitbox"
	
	# Add collision shape
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = ATTACK_RANGE
	collision.shape = shape
	hitbox.add_child(collision)
	
	# Position the hitbox in front of the player
	hitbox.position.x = attack_direction * (ATTACK_RANGE.x / 2)
	
	# Set collision mask to detect other players
	hitbox.collision_layer = 0
	hitbox.collision_mask = 4 # Adjust to match other players' layers
	
	# Connect signal to detect hits
	hitbox.body_entered.connect(_on_attack_hit)
	
	# Add to scene
	add_child(hitbox)
	
	# Remove hitbox after duration
	await get_tree().create_timer(ATTACK_DURATION).timeout
	hitbox.queue_free()

func _on_attack_hit(body):
	if body == self:
		return  # Don't hit yourself
		
	print("Hit ", body.name)
	
	# Check if the body can take damage
	if body.has_method("take_damage"):
		# Calculate knockback direction based on hit position
		var attack_direction = 1 if $Sprite2D.flip_h else -1
		var knockback_dir = Vector2(attack_direction, -0.5).normalized()
		
		# Apply damage and knockback
		body.take_damage(ATTACK_DAMAGE, knockback_dir, ATTACK_KNOCKBACK)

func take_damage(damage, knockback_dir, knockback_force):
	# Reduce health
	health -= damage
	print("Took ", damage, " damage! Health: ", health, "/", MAX_HEALTH)
	
	# Calculate scaled knockback (more damage = stronger knockback)
	var health_percent = 1.0 - (health / float(MAX_HEALTH))
	var scaled_knockback = knockback_force * (1 + health_percent * KNOCKBACK_SCALING)
	
	# Apply knockback
	velocity = knockback_dir * scaled_knockback
	
	# Check if player is defeated
	if health <= 0 and !is_defeated:
		defeated()

func defeated():
	is_defeated = true
	print("Player defeated!")
	
	# Disable controls for defeated player
	set_physics_process(false)
	emit_signal("player_defeated", 1)
	# Visual indication of defeat
	modulate = Color(0.5, 0.5, 0.5, 0.7)  # Make the character appear faded
	
	# You could also emit a signal here to track score
	# emit_signal("player_defeated")
	
	# Respawn after delay
	await get_tree().create_timer(2.0).timeout
	respawn()

func respawn():
	# Reset player state
	health = MAX_HEALTH
	is_defeated = false
	position = Vector2(100, 100)  # Respawn position - adjust as needed
	modulate = Color(1, 1, 1, 1)  # Reset appearance
	
	# Re-enable controls
	set_physics_process(true)

# --------- WEAPON SYSTEM FUNCTIONS ---------

func equip_default_weapon():
	# Create a basic weapon
	var weapon
	weapon = load("res://scripts/sword.gd").new()
	
	equip_weapon(weapon)

func equip_weapon(weapon):
	# Remove current weapon if exists
	if current_weapon != null:
		current_weapon.queue_free()
	
	# Set the new weapon
	current_weapon = weapon
	add_child(current_weapon)
	current_weapon.initialize(self)
	
	print(name + " equipped: " + current_weapon.weapon_name)
