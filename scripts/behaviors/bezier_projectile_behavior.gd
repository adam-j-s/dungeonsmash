# bezier_projectile_behavior.gd - Controls projectile movement along a bezier curve
class_name BezierProjectileBehavior
extends BehaviorBase

# Configuration
var arc_height = 120.0
var arc_duration = 1.0
var speed_factor = 1.5
var auto_explode_at_end = true
var ground_landing = true  # Whether the curve should end at ground level
var multishot_count = 0    # Track how many projectiles have been processed

func _init_behavior():
	# Get parameters with improved JSON structure handling
	var height_param = get_param("arc_height", "120.0")
	var duration_param = get_param("arc_duration", "1.0")
	var speed_param = get_param("speed_factor", "1.5")
	var explode_param = get_param("auto_explode", "true")
	var landing_param = get_param("ground_landing", "true")
	
	# Parse height parameter with type checking
	if typeof(height_param) == TYPE_DICTIONARY and height_param.has("value"):
		arc_height = float(height_param.value)
	elif typeof(height_param) == TYPE_FLOAT or typeof(height_param) == TYPE_INT:
		arc_height = float(height_param)
	else:
		arc_height = float(height_param)
	
	# Parse duration parameter with type checking
	if typeof(duration_param) == TYPE_DICTIONARY and duration_param.has("value"):
		arc_duration = float(duration_param.value)
	elif typeof(duration_param) == TYPE_FLOAT or typeof(duration_param) == TYPE_INT:
		arc_duration = float(duration_param)
	else:
		arc_duration = float(duration_param)
	
	# Parse speed factor with type checking
	if typeof(speed_param) == TYPE_DICTIONARY and speed_param.has("value"):
		speed_factor = float(speed_param.value)
	elif typeof(speed_param) == TYPE_FLOAT or typeof(speed_param) == TYPE_INT:
		speed_factor = float(speed_param)
	else:
		speed_factor = float(speed_param)
	
	# Parse boolean parameters with type checking
	if typeof(explode_param) == TYPE_BOOL:
		auto_explode_at_end = explode_param
	elif typeof(explode_param) == TYPE_DICTIONARY and explode_param.has("value"):
		auto_explode_at_end = str(explode_param.value).to_lower() == "true"
	else:
		auto_explode_at_end = str(explode_param).to_lower() == "true"
	
	if typeof(landing_param) == TYPE_BOOL:
		ground_landing = landing_param
	elif typeof(landing_param) == TYPE_DICTIONARY and landing_param.has("value"):
		ground_landing = str(landing_param.value).to_lower() == "true"
	else:
		ground_landing = str(landing_param).to_lower() == "true"
	
	# Check for any custom parameters in behaviors section of JSON
	if weapon and "weapon_data" in weapon:
		if "behaviors" in weapon.weapon_data and typeof(weapon.weapon_data.behaviors) == TYPE_ARRAY:
			for behavior in weapon.weapon_data.behaviors:
				if typeof(behavior) == TYPE_DICTIONARY and behavior.has("type") and behavior.type == "bezier_projectile":
					if "params" in behavior and typeof(behavior.params) == TYPE_DICTIONARY:
						# Override with specific params from the behavior entry
						if "arc_height" in behavior.params:
							arc_height = float(behavior.params.arc_height)
						if "arc_duration" in behavior.params:
							arc_duration = float(behavior.params.arc_duration)
						if "speed_factor" in behavior.params:
							speed_factor = float(behavior.params.speed_factor)
						if "auto_explode" in behavior.params:
							auto_explode_at_end = str(behavior.params.auto_explode).to_lower() == "true"
						if "ground_landing" in behavior.params:
							ground_landing = str(behavior.params.ground_landing).to_lower() == "true"
	
	# Reset multishot counter
	multishot_count = 0
	
	if DEBUG:
		print("Initialized bezier projectile behavior with height: ", arc_height)
		print("arc_duration: ", arc_duration)
		print("speed_factor: ", speed_factor)
		print("auto_explode: ", auto_explode_at_end)
		print("ground_landing: ", ground_landing)

# Rest of the code remains unchanged
func get_behavior_name() -> String:
	return "BezierProjectileBehavior"

func on_weapon_used():
	# Reset multishot counter when weapon is used
	multishot_count = 0
	
	if DEBUG:
		print("BezierProjectileBehavior: weapon used - reset multishot counter")

func on_projectile_created(projectile):
	# Skip if already using bezier
	if projectile.has_meta("using_bezier"):
		return
		
	# DEBUGGING: Log projectile creation
	if DEBUG:
		print("BezierProjectileBehavior: setting up projectile of type: ", projectile.get_class())
		print("BezierProjectileBehavior: projectile ID: ", projectile.get_instance_id())
	
	# Check if this is a multishot weapon (3 projectiles is common for cluster bombs)
	var total_count = 3  # Default assumption for cluster bombs
	
	# Try to get actual multishot count from weapon
	if weapon != null and weapon.has_node("BehaviorManager"):
		var behavior_manager = weapon.get_node("BehaviorManager")
		for behavior in behavior_manager.behaviors:
			if behavior.has_method("get_actual_projectile_count"):
				total_count = behavior.get_actual_projectile_count()
				if DEBUG:
					print("BezierProjectileBehavior: got multishot count from weapon: ", total_count)
	
	# Set index based on our counter - this makes each projectile unique
	var projectile_index = multishot_count
	projectile.set_meta("bezier_index", projectile_index)
	
	# Increment counter for next projectile
	multishot_count = (multishot_count + 1) % total_count
	
	if DEBUG:
		print("BezierProjectileBehavior: assigned index ", projectile_index, 
			  " to projectile, next will be ", multishot_count)
	
	# Apply visual representation
	apply_visual_style(projectile, projectile_index, total_count)
	
	# Setup bezier curve for this projectile
	setup_bezier_curve(projectile, projectile_index, total_count)
	
	# IMPORTANT: Disable collision between projectiles
	# Set a unique collision layer for each projectile in a multishot
	if total_count > 1:
		# Disable collisions between projectiles
		projectile.add_to_group("player_projectiles")
		
		# Set a timer to enable collision with enemies after a small delay
		# This prevents collisions at the start of the trajectory
		var timer = Timer.new()
		timer.wait_time = 0.2  # 200ms delay
		timer.one_shot = true
		projectile.add_child(timer)
		timer.timeout.connect(func(): 
			if is_instance_valid(projectile):
				# Enable collision with enemies
				var enemy_mask = 4 if projectile.wielder_ref and projectile.wielder_ref.name == "Player1" else 2
				projectile.collision_mask = 1 | enemy_mask  # 1 = terrain, enable enemy collision
		)
		timer.start()
		
		# Initially, only detect terrain collisions
		projectile.collision_mask = 1  # Only detect terrain (walls, floors, etc.)
		
		if DEBUG:
			print("BEZIER DEBUG: Temporarily disabled enemy collisions for projectile ", projectile_index)

# CRITICAL: Use physics_process, not regular process
func on_projectile_physics_process(projectile, delta):
	# Handle bezier movement
	if projectile.has_meta("using_bezier") and projectile.get_meta("using_bezier", false):
		if DEBUG and Engine.get_frames_drawn() % 30 == 0:
			print("BezierProjectileBehavior: projectile process for ID: ", projectile.get_instance_id())
		update_bezier_position(projectile, delta)
		return true
	return false

# Also implement regular process for redundancy
func on_projectile_process(projectile, delta):
	# Handle bezier movement - redundant with physics process
	if projectile.has_meta("using_bezier") and projectile.get_meta("using_bezier", false):
		if DEBUG and Engine.get_frames_drawn() % 30 == 0:
			print("BezierProjectileBehavior: projectile regular process for ID: ", projectile.get_instance_id())
		update_bezier_position(projectile, delta)
		return true
	return false

func on_projectile_destroyed(projectile):
	if DEBUG:
		print("BezierProjectileBehavior: projectile destroyed - ID: ", projectile.get_instance_id())

# Apply visual styling to projectiles
func apply_visual_style(projectile, index, total_count):
	# Calculate distribution factor (0 to 1) for a smooth gradient
	var distribution = 0.0
	if total_count > 1:
		distribution = float(index) / (total_count - 1)
	
	# Choose color based on distribution
	var projectile_color
	
	if total_count <= 3:
		# For 3 or fewer projectiles, use distinct colors
		var colors = [
			Color(1.0, 0.5, 0.0),  # Orange
			Color(0.0, 0.8, 0.0),  # Green
			Color(0.0, 0.4, 1.0)   # Blue
		]
		projectile_color = colors[index % colors.size()]
	else:
		# For more than 3 projectiles, use a rainbow effect
		var hue = distribution
		var saturation = 0.8
		var value = 1.0
		projectile_color = Color.from_hsv(hue, saturation, value)
	
	# Apply color
	projectile.modulate = projectile_color
	
	# Calculate size factor - first projectile largest, last smallest
	var max_size = 1.2
	var min_size = 0.8
	var size_factor = lerp(max_size, min_size, distribution)
	
	# Apply size
	projectile.scale = Vector2(size_factor, size_factor)
	
	# If no visual elements exist, create a simple one
	if projectile.get_child_count() == 0 or not has_visual_element(projectile):
		var rect = ColorRect.new()
		rect.size = Vector2(20, 20)
		rect.position = Vector2(-10, -10)  # Center the rectangle
		rect.color = projectile_color
		projectile.add_child(rect)
		
		if DEBUG:
			print("BEZIER DEBUG: Added visual element to projectile")
	
	# Set z-index based on distribution to ensure consistent visual layering
	projectile.z_index = 10 - int(distribution * 10)  # Higher indices display on top
	
	# DEBUGGING: Log color and size
	if DEBUG:
		print("BEZIER DEBUG: Distribution: ", distribution)
		print("BEZIER DEBUG: Applied color: ", projectile_color)
		print("BEZIER DEBUG: Applied size factor: ", size_factor)
		print("BEZIER DEBUG: Applied z-index: ", projectile.z_index)

# Helper to check if projectile has a visual element
func has_visual_element(projectile):
	for child in projectile.get_children():
		if child is ColorRect or child is Sprite2D:
			return true
	return false

# Setup the bezier curve for this projectile
func setup_bezier_curve(projectile, index, total_count):
	# DEBUGGING: Log projectile info
	if DEBUG:
		print("BEZIER DEBUG: Setting up curve for projectile at position: ", projectile.global_position)
		print("BEZIER DEBUG: Projectile ID: ", projectile.get_instance_id())
		print("BEZIER DEBUG: Projectile index: ", index, " of ", total_count)
	
	# Get player direction
	var dir_x = 1
	if "direction" in projectile:
		if typeof(projectile.direction) == TYPE_VECTOR2:
			dir_x = sign(projectile.direction.x)
		else:
			dir_x = sign(projectile.direction)
	elif "velocity" in projectile and projectile.velocity.x != 0:
		dir_x = sign(projectile.velocity.x)
	
	# Start position is current projectile position
	var original_pos = projectile.global_position
	
	# Force position offset based on index to ensure separation
	var position_offset = Vector2(0, 0)
	
	# Apply position offsets for better separation
	if total_count > 1:
		# Calculate distribution factor (0 to 1) 
		var distribution = float(index) / max(total_count - 1, 1)
		
		# Calculate spread offset based on direction
		var forward_range = 35.0 * (total_count / 3.0)  # Scales with projectile count
		var forward_offset = dir_x * forward_range * (distribution - 0.5)
		
		# Apply vertical offset based on distribution
		var vertical_range = 20.0 * (total_count / 3.0)  # Scales with projectile count
		var vertical_offset = -vertical_range * distribution
		
		# Create the offset with both components
		position_offset = Vector2(forward_offset, vertical_offset)
		
		# Apply the offset
		projectile.global_position += position_offset
		
		if DEBUG:
			print("BEZIER DEBUG: Distribution: ", distribution)
			print("BEZIER DEBUG: Applied position offset: ", position_offset)
			print("BEZIER DEBUG: New position: ", projectile.global_position)
	
	# Start position is now the modified position
	var start_pos = projectile.global_position
	
	# Define pattern archetypes (far/high, medium, close/low)
	var patterns = {
		"far": {
			"height": 1.8, "distance": 2.0, "duration": 1.2,  # WIDER ARC: Increased height and distance
			"control1_x": 0.3, "control1_y": 1.6,              # Adjusted for wider arc
			"control2_x": 45, "control2_y": 30
		},
		"medium": {
			"height": 1.4, "distance": 1.5, "duration": 1.4,  # WIDER ARC: Increased height and distance
			"control1_x": 0.4, "control1_y": 1.3,              # Adjusted for wider arc  
			"control2_x": 35, "control2_y": 20
		},
		"close": {
			"height": 1.0, "distance": 1.0, "duration": 1.6,  # WIDER ARC: Increased height
			"control1_x": 0.5, "control1_y": 1.0,              # Adjusted for wider arc
			"control2_x": 25, "control2_y": 15
		}
	}
	
	# Determine distribution for pattern interpolation (0.0 to 1.0)
	var pattern_index = 0.0
	if total_count > 1:
		pattern_index = float(index) / (total_count - 1)
	
	# Interpolate values between patterns
	var height_factor = 1.0
	var distance_factor = 1.0
	var duration_factor = 1.0
	var control1_x_factor = 0.35
	var control1_y_factor = 1.0
	var control2_x_offset = 30
	var control2_y_offset = 15
	
	# Pattern interpolation 
	if pattern_index <= 0.5:
		# Interpolate between far and medium (first half of projectiles)
		var t = pattern_index * 2.0  # 0.0 to 1.0
		height_factor = lerp(patterns["far"]["height"], patterns["medium"]["height"], t)
		distance_factor = lerp(patterns["far"]["distance"], patterns["medium"]["distance"], t)
		duration_factor = lerp(patterns["far"]["duration"], patterns["medium"]["duration"], t)
		control1_x_factor = lerp(patterns["far"]["control1_x"], patterns["medium"]["control1_x"], t)
		control1_y_factor = lerp(patterns["far"]["control1_y"], patterns["medium"]["control1_y"], t)
		control2_x_offset = lerp(patterns["far"]["control2_x"], patterns["medium"]["control2_x"], t)
		control2_y_offset = lerp(patterns["far"]["control2_y"], patterns["medium"]["control2_y"], t)
	else:
		# Interpolate between medium and close (second half of projectiles)
		var t = (pattern_index - 0.5) * 2.0  # 0.0 to 1.0
		height_factor = lerp(patterns["medium"]["height"], patterns["close"]["height"], t)
		distance_factor = lerp(patterns["medium"]["distance"], patterns["close"]["distance"], t)
		duration_factor = lerp(patterns["medium"]["duration"], patterns["close"]["duration"], t)
		control1_x_factor = lerp(patterns["medium"]["control1_x"], patterns["close"]["control1_x"], t)
		control1_y_factor = lerp(patterns["medium"]["control1_y"], patterns["close"]["control1_y"], t)
		control2_x_offset = lerp(patterns["medium"]["control2_x"], patterns["close"]["control2_x"], t)
		control2_y_offset = lerp(patterns["medium"]["control2_y"], patterns["close"]["control2_y"], t)
	
	# DEBUGGING: Log interpolated values
	if DEBUG:
		print("BEZIER DEBUG: Pattern index: ", pattern_index)
		print("BEZIER DEBUG: Height factor: ", height_factor)
		print("BEZIER DEBUG: Distance factor: ", distance_factor)
		print("BEZIER DEBUG: Duration factor: ", duration_factor)
	
	# Apply pattern factors to arc parameters
	var actual_arc_height = 100 * height_factor  # WIDER ARC: Increased from 90 to 100
	var actual_arc_distance = 180 * distance_factor  # WIDER ARC: Increased from 150 to 180
	var actual_arc_duration = arc_duration * duration_factor * 1.2  # SLOWER: Increased duration by 20%
	
	# Apply angle offset based on pattern distribution
	var angle_offset = 0
	if total_count > 1:
		# Calculate spread angle that scales with projectile count
		var max_spread = 30.0  # Max degrees of spread
		var spread_factor = min(1.0, 3.0 / total_count)  # Scale down for many projectiles
		angle_offset = max_spread * spread_factor * (pattern_index - 0.5)
		
		if DEBUG:
			print("BEZIER DEBUG: Applying angle offset: ", angle_offset)
		
		# Apply rotation to direction
		var angle_rad = deg_to_rad(angle_offset)
		var direction_vector = Vector2(dir_x, 0).rotated(angle_rad)
		dir_x = direction_vector.x
		
		# Now direction incorporates the spread angle
		if DEBUG:
			print("BEZIER DEBUG: New direction after angle: ", direction_vector)
	
	# Apply direction to arc distance
	var arc_distance = actual_arc_distance * dir_x
	
	# Calculate end position based on ground level
	# We want projectiles to land within a good gameplay range
	var ground_y = start_pos.y + 140  # WIDER ARC: Increased from 120 to 140 for wider landing range
	
	# End at ground level
	var end_pos = Vector2(start_pos.x + arc_distance, ground_y)
	
	# Calculate control points using interpolated factors
	var control1 = start_pos + Vector2(arc_distance * control1_x_factor, -actual_arc_height * control1_y_factor)
	var control2 = Vector2(end_pos.x - (control2_x_offset * dir_x), end_pos.y - control2_y_offset)
	
	if DEBUG:
		print("BEZIER DEBUG: Control points:")
		print("  - Control1: ", control1)
		print("  - Control2: ", control2)
	
	# Set bezier metadata
	projectile.set_meta("using_bezier", true)
	projectile.set_meta("bezier_start", start_pos)
	projectile.set_meta("bezier_control1", control1)
	projectile.set_meta("bezier_control2", control2)
	projectile.set_meta("bezier_end", end_pos)
	projectile.set_meta("bezier_progress", 0.0)
	projectile.set_meta("bezier_duration", actual_arc_duration)
	projectile.set_meta("bezier_speed_factor", speed_factor)
	projectile.set_meta("bezier_auto_explode", auto_explode_at_end)
	projectile.set_meta("prev_position", start_pos)
	
	# Calculate initial velocity that mimics original cluster bomb feel
	var initial_tangent = 3.0 * (control1 - start_pos)
	var speed = 300.0
	if "speed" in projectile:
		speed = min(projectile.speed, 400.0)
	
	projectile.velocity = initial_tangent.normalized() * speed
	
	# DEBUGGING: Log curve setup completion
	if DEBUG:
		print("BEZIER DEBUG: Curve setup complete for projectile ID ", projectile.get_instance_id())
		print("BEZIER DEBUG: Start: ", start_pos)
		print("BEZIER DEBUG: End: ", end_pos)
		print("BEZIER DEBUG: Initial velocity: ", projectile.velocity)

# Update position based on bezier curve - matching original cluster bomb's smooth movement
func update_bezier_position(projectile, delta):
	# Get bezier control points
	var p0 = projectile.get_meta("bezier_start", Vector2.ZERO)
	var p1 = projectile.get_meta("bezier_control1", Vector2.ZERO)
	var p2 = projectile.get_meta("bezier_control2", Vector2.ZERO)
	var p3 = projectile.get_meta("bezier_end", Vector2.ZERO)
	
	# Get current progress and update it
	var progress = projectile.get_meta("bezier_progress", 0.0)
	var duration = projectile.get_meta("bezier_duration", 1.0)
	var speed_factor = projectile.get_meta("bezier_speed_factor", 1.5)
	
	# SLOWER MOVEMENT: Reduce speed factor for more natural gravity feel
	speed_factor = speed_factor * 0.7  # Reduce speed by 30%
	
	# Update progress with acceleration similar to gravity for more natural arcs
	var prog_increment
	
	# Increase speed more as we get closer to the ground - simulates gravity
	if progress < 0.5:
		# First half of arc - slower, going up
		prog_increment = (delta * speed_factor * 0.7) / duration  # Reduced from 0.8
	else:
		# Second half of arc - faster, falling down
		prog_increment = (delta * speed_factor * 1.3) / duration  # Increased from 1.2
	
	progress += prog_increment
	
	# Store old position for collision detection
	var old_pos = projectile.global_position
	
	# Cap progress at 1.0
	progress = min(progress, 1.0)
	
	# Calculate current position using bezier curve
	var current_pos = cubic_bezier(p0, p1, p2, p3, progress)
	
	# Calculate previous position for velocity calculation
	var prev_t = max(0.0, progress - 0.01)
	var prev_pos = cubic_bezier(p0, p1, p2, p3, prev_t)
	
	# Calculate velocity from position difference
	var calculated_velocity = (current_pos - prev_pos) / (0.01 * duration / speed_factor)
	
	# Check for NaN values in velocity (can happen with very small deltas)
	if is_nan(calculated_velocity.x) or is_nan(calculated_velocity.y):
		calculated_velocity = Vector2(0, 10)  # Fallback to small downward velocity
	
	# Cap velocity magnitude to prevent visual issues
	var max_velocity = 400.0  # Reduced from 500.0
	if calculated_velocity.length() > max_velocity:
		calculated_velocity = calculated_velocity.normalized() * max_velocity
	
	# Set the velocity for collision detection
	projectile.velocity = calculated_velocity
	
	# Store updated progress
	projectile.set_meta("bezier_progress", progress)
	
	# Set the position directly
	projectile.global_position = current_pos
	projectile.set_meta("prev_position", old_pos)
	
	# Add subtle rotation to mimic original cluster bomb visual feel
	var rotation_factor = 1.5  # Reduced from 2.0 for more natural feel
	projectile.rotation += delta * rotation_factor * sign(calculated_velocity.x)
	
	# Check for collisions manually during Bezier movement
	check_collision_during_bezier(projectile)
	
	# Check if we reached the end of the curve
	if progress >= 1.0:
		if projectile.get_meta("bezier_auto_explode", true):
			# Auto-explode if configured to do so
			if projectile.has_method("create_explosion"):
				if DEBUG:
					print("BEZIER DEBUG: Creating explosion at end of curve")
				projectile.create_explosion()
			projectile.destroy()
		else:
			# Just mark as no longer using bezier
			projectile.set_meta("using_bezier", false)
	
	return true

# Check for collisions during Bezier curve movement
func check_collision_during_bezier(projectile):
	# Use move_and_collide to detect collisions
	var collision_result = projectile.move_and_collide(Vector2.ZERO)
	
	if collision_result:
		# Process the collision
		var collider = collision_result.get_collider()
		
		# Skip collisions with other projectiles
		if collider.is_in_group("player_projectiles"):
			if DEBUG:
				print("BEZIER DEBUG: Skipping collision with another projectile")
			return
		
		if DEBUG:
			print("BEZIER DEBUG: Collision detected with: ", collider.name)
		
		# SPECIAL CASE: Check if this is a singularity bomb
		if projectile.weapon_id == "singularity_bomb" or projectile.has_behavior("SingularityBehavior"):
			# Let the singularity behavior handle the collision instead
			if DEBUG:
				print("BEZIER DEBUG: Deferring to singularity behavior")
			
			# Notify behaviors about collision but don't handle it directly
			if projectile.has_method("notify_behaviors_on_collision"):
				projectile.notify_behaviors_on_collision(collision_result)
				
			# Don't destroy the projectile - let singularity handle it
			return
			
		# Normal collision handling
		if collider.has_method("take_damage"):
			# Hit an enemy - apply damage directly
			var hit_dir = projectile.velocity.normalized()
			
			# Get damage from projectile
			var damage = projectile.damage
			var knockback = projectile.knockback
			
			# Apply damage to the target
			collider.take_damage(damage, hit_dir, knockback)
		
		# If it's an explosive projectile, create explosion
		if projectile.has_method("create_explosion"):
			if DEBUG:
				print("BEZIER DEBUG: Creating explosion due to collision")
			projectile.create_explosion()
			
		# Destroy the projectile
		projectile.destroy()
		
# Calculate cubic bezier interpolation
func cubic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	# Standard cubic bezier formula:
	# B(t) = (1-t)³P₀ + 3(1-t)²tP₁ + 3(1-t)t²P₂ + t³P₃
	
	var u = 1.0 - t
	var tt = t * t
	var uu = u * u
	var uuu = uu * u
	var ttt = tt * t
	
	var result = uuu * p0
	result += 3.0 * uu * t * p1
	result += 3.0 * u * tt * p2
	result += ttt * p3
	
	return result
