# Collision Utils
extends Object

# Constants for collision layers
const WORLD_LAYER = 1
const PLAYER1_LAYER = 2
const PLAYER2_LAYER = 4
const ENEMY_LAYER = 8  # New layer for enemies

# Set up collision masks for projectiles, explosions, or area attacks
static func setup_collision_mask(object, wielder, include_world=true):
	# Set collision layer to 0 (doesn't generate collisions)
	object.collision_layer = 0
	
	# Calculate target mask based on wielder type
	var target_mask = 0
	
	# Check if wielder is a player or an enemy
	var is_enemy = wielder and (wielder.get_class() == "WispEnemy" or wielder is WispEnemy)
	
	if is_enemy:
		# Enemies target both players
		target_mask = PLAYER1_LAYER | PLAYER2_LAYER
	elif wielder and wielder.name == "Player1":
		# Player1 targets Player2 and enemies
		target_mask = PLAYER2_LAYER | ENEMY_LAYER
	else:
		# Player2 (or any other player) targets Player1 and enemies
		target_mask = PLAYER1_LAYER | ENEMY_LAYER
	
	# Set initial mask to include world (if requested) and targets
	var world_mask = WORLD_LAYER if include_world else 0
	object.collision_mask = target_mask | world_mask
	
	# Check if self-damage is allowed
	var allow_self_damage = false
	
	# Check for weapon reference
	var weapon_ref = null
	if object.has_meta("weapon"):
		weapon_ref = object.get_meta("weapon")
	
	# Check JSON structure first if weapon is available
	if weapon_ref and "weapon_data" in weapon_ref:
		if "flags" in weapon_ref.weapon_data:
			allow_self_damage = weapon_ref.weapon_data.flags.get("allow_self_damage", false)
		else:
			# Fallback to metadata on weapon
			allow_self_damage = weapon_ref.get_meta("allow_self_damage", false)
	elif object.has_meta("allow_self_damage"):
		# Fallback to direct metadata on object
		allow_self_damage = object.get_meta("allow_self_damage")
	
	# If self-damage is allowed, set up a delayed self-collision
	if allow_self_damage:
		# Determine self layer based on wielder type
		var self_layer = 0
		if is_enemy:
			self_layer = ENEMY_LAYER
		elif wielder and wielder.name == "Player1":
			self_layer = PLAYER1_LAYER
		else:
			self_layer = PLAYER2_LAYER
		
		# Create timer to enable self-collision after delay
		var timer = Timer.new()
		timer.wait_time = 0.5  # Half-second delay before self-damage is possible
		timer.one_shot = true
		object.add_child(timer)
		
		# Connect timer to enable self-collision
		timer.timeout.connect(func():
			if is_instance_valid(object):
				object.collision_mask |= self_layer
				print("Self-damage collision enabled for " + object.name)
		)
		
		timer.start()
		print("Self-damage will be enabled after delay")
	
	return object.collision_mask
