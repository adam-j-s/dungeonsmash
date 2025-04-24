# New Player.gd Unified player script supporting character classes and dynamic weapon system
extends CharacterBody2D

# Player identification
var player_number = 0  # Will be set automatically
var input_prefix = ""  # Will be set based on player number

#DEBUG
const DEBUG = false

# Character class
@export var character_class_id: String = "knight"  # Default class ID
var character_stats = {}  # Will hold the stats for this character

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

# New Aiming System ----------remove all of this
@export var use_twin_stick_aiming: bool = false
var aim_direction: Vector2 = Vector2.RIGHT
@onready var sprite_node = $Sprite2D
#--------------- remove all of this

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
signal player_defeated(player_number)

# Weapon variables
var current_weapon = null
var weapons_inventory = []

func _ready():
	# Do these immediately
	assign_player_number()
	# Set player number based on name (adjust logic as needed)
	if name == "Player1" or name.begins_with("Player1"):
		player_number = 1
		collision_layer = 2 #Layer2 for player 1
		print("Player 1 initialized with player_number: ", player_number, " and collision layer: ", collision_layer)
	elif name == "Player2" or name.begins_with("Player2"):
		player_number = 2
		collision_layer = 4 #Layer 4 for player 2
		print("Player 2 initialized with player_number: ", player_number, " and collision layer: ", collision_layer)
	else:
		print("WARNING: Unknown player name: ", name, " - cannot determine player number")
		
	setup_controls()
	
	# Create a Timer for dash cooldown
	dash_recharge_timer = Timer.new()
	dash_recharge_timer.one_shot = true
	dash_recharge_timer.wait_time = DASH_COOLDOWN
	dash_recharge_timer.timeout.connect(recharge_dash)
	add_child(dash_recharge_timer)
	
	# Create health bar
	create_health_bar()
	
	# Add player to players group
	add_to_group("players")
	
	# Delay these to let battle_arena set character_class_id first
	call_deferred("initialize_character")

	
func initialize_character():
	# Load character stats from registry
	load_character_stats()
	
	# Initialize dash charges to max at start
	dash_charges = MAX_DASH_CHARGES
	
	# Initialize health
	health = MAX_HEALTH
	is_defeated = false
	
	# Equip default weapon after character class is set
	equip_default_weapon()
	
	print("Player " + str(player_number) + " initialized as " + character_stats.name)

func assign_player_number():
	# Get existing players before we add ourselves to the group
	var existing_players = get_tree().get_nodes_in_group("players")
	
	# Assign player number based on number of existing players
	player_number = existing_players.size() + 1
	
	# Verify valid player number (failsafe)
	if player_number <= 0 or player_number > 4:  # Support up to 4 players
		player_number = 1  # Default to player 1 if something goes wrong

func setup_controls():
	# Set input prefix based on player number
	match player_number:
		1:
			input_prefix = "ui_"  # Player 1 uses default inputs (ui_left, ui_right, etc.)
		2:
			input_prefix = "p2_"  # Player 2 uses p2_ prefixed inputs
		3:
			input_prefix = "p3_"
		4:
			input_prefix = "p4_"

func load_character_stats():
	# Load character stats from the registry
	character_stats = CharacterClasses.get_character_class(character_class_id)
	
	# Apply character-specific attributes
	# (Visual appearances could be updated here later)
	
	# Adjust stats based on character class
	MAX_HEALTH = character_stats.vitality * 10  # Example of deriving max health from stats
	health = MAX_HEALTH

func get_weapon_multiplier(weapon_type: String) -> float:
	var multiplier = 1.0
	
	match weapon_type:
		"sword":
			multiplier = character_stats.sword_affinity * (character_stats.strength / 10.0)
		"staff":
			multiplier = character_stats.staff_affinity * (character_stats.intelligence / 10.0)
		# Add more weapon types as needed
	
	return multiplier

# Now uses the dedicated health bar scene
func create_health_bar():
	call_deferred("add_health_bar")

# Add health bar UI component
func add_health_bar():
	# Check if a health bar already exists and remove it
	var existing_bar = get_node_or_null("HealthBar")
	if existing_bar:
		existing_bar.queue_free()
	
	# Create new health bar
	var health_bar = preload("res://scenes/ui/health_bar.tscn").instantiate()
	add_child(health_bar)
	health_bar.name = "HealthBar"
	
	# Set up to track this player
	health_bar.setup(self)

# NEW CENTRALIZED FUNCTION: Get attack direction value in a consistent way
# This function returns the attack direction that attack styles expect
func get_attack_direction_value() -> Vector2:
	if DEBUG:
		print("DEBUG DIRECTION: Player returning direction: ", "LEFT" if (sprite_node and sprite_node.flip_h) else "RIGHT")
	if use_twin_stick_aiming:
		# When using twin stick, direction comes from aim_direction
		return aim_direction.normalized()
	else:
		# When not using twin stick, direction is based on sprite flipping
		# Sprite flipped (facing left) = Vector2.LEFT, Not flipped (facing right) = Vector2.RIGHT
		if sprite_node and sprite_node.flip_h:
			return Vector2.LEFT
		else:
			return Vector2.RIGHT

# Helper function for simple left/right direction as integer (-1 or 1)
func get_attack_direction_sign() -> int:
	var direction = get_attack_direction_value()
	return sign(direction.x)

func update_aim_direction():
	if use_twin_stick_aiming:
		var aim_input = Input.get_vector(input_prefix + "aim_left", input_prefix + "aim_right", input_prefix + "aim_up", input_prefix + "aim_down")
		if aim_input.length_squared() > 0.1: # Deadzone
			aim_direction = aim_input.normalized()
			# Aiming dictates visual flip - KEEP THIS CONSISTENT
			if sprite_node: sprite_node.flip_h = aim_direction.x < 0
	else:
		# Default aiming based on sprite facing direction
		if sprite_node:
			aim_direction = Vector2.RIGHT if not sprite_node.flip_h else Vector2.LEFT

func apply_gravity(delta, jump_action_name):
	"""Applies gravity, considering jump height control."""
	# Note: Assumes called only when not is_on_floor() / dashing / wall_grabbing
	# Check if jump button ISN'T held for low jump (use is_action_pressed here)
	if velocity.y < 0 and not Input.is_action_pressed(jump_action_name):
		velocity.y += base_gravity * LOW_JUMP_MULTIPLIER * delta
	elif velocity.y > 0: # Faster fall
		velocity.y += base_gravity * FALL_MULTIPLIER * delta
	else: # Normal gravity
		velocity.y += base_gravity * delta


func handle_wall_interaction(delta, wall_grab_action_name):
	"""Handles wall grab starting, sliding, and timeout."""
	# Note: Assumes called only when not is_on_floor() / dashing

	var touching_wall = is_on_wall() # Use built-in check

	if touching_wall and Input.is_action_pressed(wall_grab_action_name):
		var wall_normal = get_wall_normal()
		var horizontal_input_for_grab = Input.get_axis(input_prefix + "left", input_prefix + "right")
		# Check if holding grab AND pressing towards the wall
		if (wall_normal.x > 0.1 and horizontal_input_for_grab < -0.1) or \
		   (wall_normal.x < -0.1 and horizontal_input_for_grab > 0.1):
				# Start wall grab if not already grabbing
				if not is_wall_grabbing:
					wall_grab_timer = 0.0
					is_wall_grabbing = true
					# wall_grab_direction = -wall_normal.x # Set if needed elsewhere
					jumps_made = 0 # Reset jumps on grab
					velocity.x = 0 # Stop horizontal movement against wall
					# print("Wall Grab Started") # Optional Debug

				# Limit wall grab time while sliding
				if wall_grab_timer < WALL_GRAB_TIME:
					# Slide down smoothly
					velocity.y = move_toward(velocity.y, WALL_SLIDE_SPEED, base_gravity * 2 * delta)
					wall_grab_timer += delta
				else:
					is_wall_grabbing = false # Time's up
					# print("Wall Grab Timed Out") # Optional Debug
		else:
			is_wall_grabbing = false # Not pressing towards wall
	else:
		is_wall_grabbing = false # Not touching wall or not holding grab
		
# --- ADD or REPLACE the _input function ---
func _input(event):
	# Ignore input if defeated
	if is_defeated:
		return

	# Determine correct action names based on aiming mode and player prefix
	var fire_action = input_prefix + ("fire_alt" if use_twin_stick_aiming else "attack")
	var jump_action = input_prefix + ("jump_alt" if use_twin_stick_aiming else "accept")
	var dash_action = input_prefix + ("dash_alt" if use_twin_stick_aiming else "dash")
	
	# Debug action checking
	if DEBUG and event.is_action_pressed("debug_print_actions"):
		print("P", player_number, " Checking Actions -> Fire:'", fire_action, 
			  "' Jump:'", jump_action, "' Dash:'", dash_action, 
			  "' TwinStick:", use_twin_stick_aiming)

	# --- Handle Attack ---
	if Input.is_action_just_pressed(fire_action):
		if DEBUG:
			print("P", player_number, " Input: '", fire_action, "' JUST PRESSED.")
			
		if can_attack and not is_dashing and not is_wall_grabbing:
			if DEBUG:
				print("P", player_number, " Conditions met, calling perform_attack()")
			perform_attack()
		elif DEBUG:
			print("P", player_number, " Attack conditions NOT met (can_attack:", can_attack, 
				  ", is_dashing:", is_dashing, ", is_wall_grabbing:", is_wall_grabbing, ")")

	# --- Handle Jump ---
	if Input.is_action_just_pressed(jump_action):
		if DEBUG:
			print("P", player_number, " Input: '", jump_action, "' JUST PRESSED.")
			
		if not is_dashing: # Allow jump press even if wall grabbing to trigger wall jump
			if is_wall_grabbing:
				# Perform Wall Jump
				var wall_normal = get_wall_normal()
				velocity.x = wall_normal.x * WALL_JUMP_STRENGTH.x
				velocity.y = WALL_JUMP_STRENGTH.y
				is_wall_grabbing = false
				jumps_made = 1 # Reset jumps_made for wall jump consistency
				
				if DEBUG:
					print("P", player_number, " Wall Jump performed!")
					
			elif is_on_floor() or jumps_made < MAX_JUMPS:
				# Perform Regular Jump / Double Jump
				velocity.y = JUMP_VELOCITY
				jumps_made += 1
				
				if DEBUG:
					print("P", player_number, " Jump performed! (Jumps made: ", jumps_made, ")")
			elif DEBUG:
				print("P", player_number, " Jump prevented (Max jumps reached or invalid state)")
		elif DEBUG:
			print("P", player_number, " Jump prevented (Dashing)")

	# --- Handle Dash ---
	if Input.is_action_just_pressed(dash_action):
		if DEBUG: print("P", player_number, " Input: '", dash_action, "' JUST PRESSED.")

		if dash_charges > 0 and not is_wall_grabbing and not is_dashing:
			if DEBUG: print("P", player_number, " Conditions met, determining dash type...")

			# Read inputs once
			var horizontal_input = Input.get_axis(input_prefix + "left", input_prefix + "right")
			var vertical_input = Input.get_axis(input_prefix + "up", input_prefix + "down") # Assumes Up is Negative Y

			if DEBUG: print("P", player_number, " Dash Input - H:", horizontal_input, " V:", vertical_input)

			# --- Decision Tree - Prioritize Diagonal, then Horizontal ---
			# Use a deadzone constant for clarity
			var deadzone = 0.1
			var h_abs = abs(horizontal_input)
			var v_abs = abs(vertical_input)

			if h_abs > deadzone and v_abs > deadzone:
				# Diagonal Dash
				if DEBUG: print("P", player_number, " Dash Type: Diagonal")
				start_diagonal_dash(horizontal_input, vertical_input)
				get_viewport().set_input_as_handled()

			elif h_abs > deadzone:
				# Pure Horizontal Dash
				if DEBUG: print("P", player_number, " Dash Type: Horizontal")
				start_horizontal_dash(horizontal_input)
				get_viewport().set_input_as_handled()

			elif vertical_input < -deadzone: # Check against negative deadzone for UP
				# Pure Vertical Up Dash
				if DEBUG: print("P", player_number, " Dash Type: Vertical Up")
				start_vertical_dash(-1)
				get_viewport().set_input_as_handled()

			elif vertical_input > deadzone: # Check against positive deadzone for DOWN
				# Pure Ground Pound
				if DEBUG: print("P", player_number, " Dash Type: Ground Pound")
				start_ground_pound()
				get_viewport().set_input_as_handled()

			else:
				# Neutral Dash (No significant direction held)
				if DEBUG: print("P", player_number, " Dash Type: Neutral (using aim_direction: ", aim_direction, ")")
				start_horizontal_dash(sign(aim_direction.x)) # Use sign to get 1 or -1
				get_viewport().set_input_as_handled()
			# --- End Decision Tree ---

		else: # Conditions for dash not met
			if DEBUG: print("P", player_number, " Dash conditions NOT met (charges:", dash_charges, ", is_wall_grabbing:", is_wall_grabbing, ", is_dashing:", is_dashing, ")")
# --- REPLACE your existing _physics_process with this ---
func _physics_process(delta):
	# Skip processing if defeated
	if is_defeated:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# --- Update Aim Direction (Based on stick or facing dir) ---
	var prev_aim = aim_direction # Store for debug comparison
	update_aim_direction() # Call helper function
	# DEBUG Aiming
	if aim_direction != prev_aim and use_twin_stick_aiming:
		print("P", player_number, " Physics: Aim direction updated to ", aim_direction.round())


	# --- Determine Action Names (for continuous checks like holding jump/grab) ---
	var jump_action = input_prefix + ("jump_alt" if use_twin_stick_aiming else "accept")
	var wall_grab_action = input_prefix + "wall_grab"

	# --- Handle Gravity ---
	if not is_on_floor() and not is_dashing and not is_wall_grabbing:
		apply_gravity(delta, jump_action)
	elif is_on_floor():
		if jumps_made != 0: # Reset jumps only when actually grounded
			# print("P", player_number, " Physics: Touched floor, resetting jumps.") # DEBUG
			jumps_made = 0
		if is_ground_pounding: # Handle ground pound landing
			# print("P", player_number, " Physics: Ground pound landed.") # DEBUG
			ground_pound_impact()
			is_ground_pounding = false

	# --- Wall Interaction (Holding Grab, Sliding) ---
	handle_wall_interaction(delta, wall_grab_action)

	# --- Handle Horizontal Movement ---
	if not is_dashing and not is_wall_grabbing:
		var horizontal_input = Input.get_axis(input_prefix + "left", input_prefix + "right")
		if horizontal_input != 0:
			velocity.x = horizontal_input * SPEED
			# Update sprite direction ONLY if not twin-stick aiming
			if not use_twin_stick_aiming and sprite_node:
				var current_flip = sprite_node.flip_h
				var new_flip = horizontal_input < 0
				if current_flip != new_flip:
					sprite_node.flip_h = new_flip
					# print("P", player_number," Physics: Sprite flipped based on movement. New flip_h:", new_flip) # DEBUG
		else:
			# Apply friction when no input
			velocity.x = move_toward(velocity.x, 0, SPEED * 1.5) # Adjust friction factor

	# --- Apply final velocity and handle collisions ---
	move_and_slide()
func create_dash_timer():
	# Use a scene timer to avoid issues with await during physics
	var timer = get_tree().create_timer(DASH_DURATION, true, false) # process_in_physics=true, ignore_pause=false
	timer.name = "DashEndTimer" # Give it a name
	# Connect timeout safely using bind, ensure one-shot connection
	timer.timeout.connect(_on_dash_timer_timeout.bind(timer), CONNECT_ONE_SHOT)

func _on_dash_timer_timeout(timer_node = null): # Accept optional arg
	is_dashing = false
	# Ground pound state persists until landing, so don't reset it here
	# print("Dash timer finished") # Optional Debug
	# Clean up timer node if passed and still valid
	if timer_node and is_instance_valid(timer_node):
		# Check if it's still in the tree before freeing (extra safety)
		if timer_node.get_parent() == get_tree().root or timer_node.get_parent() == self:
			timer_node.queue_free()
			
func start_horizontal_dash(direction):
	# Don't proceed if already dashing
	if is_dashing:
		return
		
	consume_dash_charge()
	
	# Set dash velocity
	velocity.x = direction * DASH_SPEED
	velocity.y = 0  # No vertical movement during horizontal dash
	
	# Create a one-shot timer for ending the dash
	var timer = Timer.new()
	timer.wait_time = DASH_DURATION
	timer.one_shot = true
	timer.autostart = false
	add_child(timer)
	
	# Connect to the timeout signal to end the dash
	timer.timeout.connect(func():
		is_dashing = false
		timer.queue_free()
	)
	
	# Start the timer
	timer.start()

func start_vertical_dash(direction):
	# Don't proceed if already dashing
	if is_dashing:
		return
		
	consume_dash_charge()
	
	# Set dash velocity (negative Y is up in Godot)
	velocity.x = 0  # No horizontal movement during vertical dash
	velocity.y = direction * VERTICAL_DASH_SPEED
	
	# Create a one-shot timer for ending the dash
	var timer = Timer.new()
	timer.wait_time = DASH_DURATION
	timer.one_shot = true
	timer.autostart = false
	add_child(timer)
	
	# Connect to the timeout signal to end the dash
	timer.timeout.connect(func():
		is_dashing = false
		timer.queue_free()
	)
	
	# Start the timer
	timer.start()

func start_diagonal_dash(h_direction, v_direction):
	# Don't proceed if already dashing
	if is_dashing:
		return
		
	consume_dash_charge()
	
	# For diagonal movement, normalize the vector to maintain consistent speed
	var direction = Vector2(h_direction, v_direction).normalized()
	
	# Set dash velocity
	velocity.x = direction.x * DASH_SPEED
	velocity.y = direction.y * VERTICAL_DASH_SPEED
	
	# Create a one-shot timer for ending the dash
	var timer = Timer.new()
	timer.wait_time = DASH_DURATION
	timer.one_shot = true
	timer.autostart = false
	add_child(timer)
	
	# Connect to the timeout signal to end the dash
	timer.timeout.connect(func():
		is_dashing = false
		timer.queue_free()
	)
	
	# Start the timer
	timer.start()

func start_ground_pound():
	# Don't proceed if already dashing
	if is_dashing:
		return
		
	consume_dash_charge()
	is_ground_pounding = true
	
	# Cancel horizontal momentum and set downward velocity
	velocity.x = 0
	velocity.y = DOWNWARD_DASH_SPEED
	
	# Create a one-shot timer for ending the dash state
	var timer = Timer.new()
	timer.wait_time = DASH_DURATION
	timer.one_shot = true
	timer.autostart = false
	add_child(timer)
	
	# Connect to the timeout signal to end the dash
	timer.timeout.connect(func():
		is_dashing = false
		timer.queue_free()
	)
	
	# Start the timer
	timer.start()

func consume_dash_charge():
	is_dashing = true
	dash_charges -= 1
	if DEBUG:
		print("Dash used. Remaining charges:", dash_charges)
	
	# If this was our first used charge, start the recharge timer
	if dash_charges == MAX_DASH_CHARGES - 1 and dash_recharge_timer.is_stopped():
		dash_recharge_timer.start()

func recharge_dash():
	# Add a dash charge
	if dash_charges < MAX_DASH_CHARGES:
		dash_charges += 1
		if DEBUG:
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
	
	# Set collision mask based on player number
	query.collision_mask = 4 if player_number == 1 else 2  # Target other player's layer
	
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
		if DEBUG:
			print("Cannot attack: can_attack=", can_attack, " is_attacking=", is_attacking, " is_dashing=", is_dashing, " is_wall_grabbing=", is_wall_grabbing)
		return
		
	is_attacking = true
	can_attack = false
	
	# Check what weapon we have
	if current_weapon != null:
		if DEBUG:
			print("Attacking with weapon: ", current_weapon.get_weapon_name(), " (Type: ", current_weapon.get_weapon_type(), ")")
		
		# IMPORTANT: Always ensure the signal is connected
		# Disconnect first to avoid multiple connections
		if current_weapon.is_connected("cooldown_completed", Callable(self, "_on_weapon_cooldown_complete")):
			current_weapon.disconnect("cooldown_completed", Callable(self, "_on_weapon_cooldown_complete"))
		
		# Reconnect the signal
		current_weapon.connect("cooldown_completed", Callable(self, "_on_weapon_cooldown_complete"))
		
		# Try to perform the attack
		var attack_result = current_weapon.perform_attack()
		if !attack_result:
			print("Weapon attack failed!")
			# For failed weapon attacks, use the default cooldown
			finish_attack_with_default_cooldown()
		else:
			# Weapon attack succeeded - weapon handles cooldown
			
			# Just set attacking to false after a short recovery time
			await get_tree().create_timer(0.05).timeout
			is_attacking = false
			
			# Signal connection is already established above
	else:
		print("No weapon equipped, using basic attack")
		# Fallback to basic attack if no weapon
		create_basic_attack_hitbox()
		
		# For basic attacks, use the default cooldown
		finish_attack_with_default_cooldown()

# Helper to handle default cooldowns for basic attacks or failed weapon attacks
func finish_attack_with_default_cooldown():
	# Attack recovery
	await get_tree().create_timer(ATTACK_DURATION).timeout
	is_attacking = false
	print("Attack recovery complete")
	
	# Attack cooldown
	await get_tree().create_timer(ATTACK_COOLDOWN).timeout
	can_attack = true
	print("Attack cooldown complete, can attack again")

# New method to handle the weapon cooldown signal
func _on_weapon_cooldown_complete():
	can_attack = true
	print("Weapon cooldown complete, ready to attack again")

# Keep the existing attack code as a fallback
func create_basic_attack_hitbox():
	# Get attack direction using our centralized function to maintain consistency
	var attack_direction = get_attack_direction_sign()
	
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
	hitbox.collision_mask = 4 if player_number == 1 else 2  # Target other player's layer
	
	# Connect signal to detect hits
	hitbox.body_entered.connect(_on_attack_hit)
	
	# Add to scene
	add_child(hitbox)
	
	# Remove hitbox after duration
	await get_tree().create_timer(ATTACK_DURATION).timeout
	hitbox.queue_free()
	
func _on_body_entered(body):
	if DEBUG:
		print("Player ", name, " detected collision with: ", body.name)
		print("Player collision layer: ", collision_layer)
	if body.has_method("get_meta") and body.get_meta("friendly_fire", false):
		if DEBUG:
			print("Collided with projectile that has friendly_fire enabled")
		
func _on_attack_hit(body):
	if body == self:
		return  # Don't hit yourself
		
	print("Hit ", body.name)
	
	# Check if the body can take damage
	if body.has_method("take_damage"):
		# Use our centralized direction function to get the correct direction
		var attack_direction = get_attack_direction_sign()
		var knockback_dir = Vector2(attack_direction, -0.5).normalized()
		
		# Calculate damage based on character stats
		var effective_damage = ATTACK_DAMAGE
		if current_weapon != null and current_weapon.has_method("get_weapon_type"):
			effective_damage *= get_weapon_multiplier(current_weapon.get_weapon_type())
		
		# Apply damage and knockback
		body.take_damage(effective_damage, knockback_dir, ATTACK_KNOCKBACK)

func take_damage(damage, knockback_dir, knockback_force):
	# Reduce health
	health -= damage
	print("Player " + str(player_number) + " took " + str(damage) + " damage! Health: " + str(health) + "/" + str(MAX_HEALTH))
	
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
	print("Player " + str(player_number) + " defeated!")
	
	# Disable controls for defeated player
	set_physics_process(false)
	
	# Emit signal with the correct player number
	emit_signal("player_defeated", player_number)
	
	# Visual indication of defeat
	modulate = Color(0.5, 0.5, 0.5, 0.7)  # Make the character appear faded
	
	# Respawn after delay
	await get_tree().create_timer(2.0).timeout
	respawn()

func respawn():
	# Reset player state
	health = MAX_HEALTH
	is_defeated = false
	
	# Different respawn positions based on player
	if player_number == 1:
		position = Vector2(100, 100)
	else:
		position = Vector2(900, 100)
		
	modulate = Color(1, 1, 1, 1)  # Reset appearance
	
	# Re-enable controls
	set_physics_process(true)

# Equip the default weapon based on character class
func equip_default_weapon():
	# Get the default weapon type from character stats
	var weapon_type = character_stats.default_weapon
	print("Default weapon for " + character_stats.name + " should be: " + str(weapon_type))
	
	# Check if the default weapon is valid
	if weapon_type == null or weapon_type == "":
		print("ERROR: No default weapon specified for " + character_stats.name)
		weapon_type = "sword"  # Fallback to sword
	
	# Create new weapon instance
	var weapon = Weapon.new()
	weapon.load_weapon(weapon_type)
	
	# Equip it
	equip_weapon(weapon)

# Equip a specific weapon by ID
func equip_weapon_by_id(weapon_id: String):
	print("Player " + str(player_number) + " attempting to equip weapon ID: " + weapon_id)
	
	# Verify that the weapon exists in the database
	if weapon_id in WeaponDatabase.weapons:
		# Create new weapon instance
		var weapon = Weapon.new()
		print("Weapon instance created")
		
		# Load the weapon data
		weapon.load_weapon(weapon_id)
		print("Weapon data loaded: " + WeaponDatabase.weapons[weapon_id].name)
		
		# Equip it
		equip_weapon(weapon)
		print("Weapon successfully equipped")
	else:
		print("ERROR: Weapon ID '" + weapon_id + "' not found in WeaponDatabase")

func equip_weapon(weapon):
	# First set is_attacking to false to cancel any attack in progress
	is_attacking = false
	
	# Clean up any active hitboxes
	clean_up_weapon_hitboxes()
	
	# Clean up projectiles safely
	clean_up_active_projectiles()
	
	# Add a brief delay to ensure all processes complete
	await get_tree().create_timer(0.05).timeout
	
	# Remove current weapon if exists
	if current_weapon != null:
		# Disconnect signals if connected
		if current_weapon.is_connected("weapon_used", Callable(self, "_on_weapon_used")):
			current_weapon.disconnect("weapon_used", Callable(self, "_on_weapon_used"))
			
		if current_weapon.is_connected("cooldown_completed", Callable(self, "_on_weapon_cooldown_complete")):
			current_weapon.disconnect("cooldown_completed", Callable(self, "_on_weapon_cooldown_complete"))
			
		if current_weapon.is_connected("cooldown_changed", Callable(self, "_on_weapon_cooldown_changed")):
			current_weapon.disconnect("cooldown_changed", Callable(self, "_on_weapon_cooldown_changed"))
		
		# Remove from tree
		remove_child(current_weapon)
		current_weapon.queue_free()
		current_weapon = null
	
	# Set the new weapon
	current_weapon = weapon
	add_child(current_weapon)
	
	# Initialize properly
	current_weapon.initialize(self)
	
	# Connect signals
	if current_weapon.has_signal("weapon_used"):
		current_weapon.connect("weapon_used", Callable(self, "_on_weapon_used"))
		
	# Connect cooldown completed signal
	if current_weapon.has_signal("cooldown_completed"):
		current_weapon.connect("cooldown_completed", Callable(self, "_on_weapon_cooldown_complete"))
		
	# Connect cooldown changed signal for UI updates
	if current_weapon.has_signal("cooldown_changed"):
		current_weapon.connect("cooldown_changed", Callable(self, "_on_weapon_cooldown_changed"))
	
	# Reset attack state
	can_attack = true
		
	# Setup the cooldown meter to track the new weapon
	call_deferred("add_cooldown_meter")
	
# Handler
func _on_weapon_cooldown_changed(progress):
	print("Cooldown changed: ", progress)
	var cooldown_meter = get_node_or_null("CooldownMeter")
	if cooldown_meter:
		# Access the set_progress method through the CooldownMeter node
		if "progress" in cooldown_meter:
			# Directly set the property if it exists
			cooldown_meter.progress = progress
			
			# Force a redraw if there's a CircleControl node
			if cooldown_meter.has_node("Control/CircleControl"):
				cooldown_meter.get_node("Control/CircleControl").queue_redraw()
		else:
			print("Warning: CooldownMeter has no 'progress' property")
	else:
		print("Warning: CooldownMeter not found")
		
# Clean up projectiles:
func clean_up_active_projectiles():
	# Find all projectiles in the scene
	var scene = get_tree().current_scene
	if scene:
		for node in scene.get_children():
			# Check if it's a projectile with this player as wielder
			if node is CharacterBody2D and node.has_meta("wielder") and node.get_meta("wielder") == self:
				# Make the projectile "orphaned" - detach from wielder but let it complete its path
				node.set_meta("wielder", null)
	
# Callback function
func _on_weapon_used(weapon_id):
	print("Player " + str(player_number) + " used weapon: " + weapon_id)

# New function to clean up any active weapon hitboxes
func clean_up_weapon_hitboxes():
	# Find and remove any active weapon hitboxes
	for child in get_children():
		if child is Area2D and (child.name == "WeaponHitbox" or child.name == "AttackHitbox"):
			print("Cleaning up leftover hitbox: " + child.name)
			child.queue_free()

# Add cooldown meter UI component
func add_cooldown_meter():
	# Check if the weapon exists
	if current_weapon == null:
		print("ERROR: Can't add cooldown meter - no weapon equipped")
		return

	# Remove any existing cooldown UI elements
	for child in get_children():
		if child.name == "CooldownBar" or child.name == "CooldownMeter":
			print("Removing existing cooldown UI: " + child.name)
			child.queue_free()
	
	# Create new cooldown meter
	var cooldown_meter = preload("res://scenes/ui/cooldown_meter.tscn").instantiate()
	add_child(cooldown_meter)
	cooldown_meter.name = "CooldownMeter"
	
	# Set up to track current weapon without calling set_progress directly
	cooldown_meter.setup(current_weapon)
	
	print("Cooldown meter created for weapon:", current_weapon.get_weapon_name())
