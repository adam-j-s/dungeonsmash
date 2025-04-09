# Collision Utils
extends Object

# Constants for collision layers
const WORLD_LAYER = 1
const PLAYER1_LAYER = 2
const PLAYER2_LAYER = 4

# Set up collision masks for projectiles, explosions, or area attacks
static func setup_collision_mask(object, wielder, include_world=true):
	# Set collision layer to 0 (doesn't generate collisions)
	object.collision_layer = 0
	
	# Determine which player to target based on wielder
	var target_mask = 0
	if wielder and wielder.name == "Player1":
		target_mask = PLAYER2_LAYER
		print("Setup to hit Player2 (mask: ", PLAYER2_LAYER, ")")
	elif wielder and wielder.name == "Player2":
		target_mask = PLAYER1_LAYER
		print("Setup to hit Player1 (mask: ", PLAYER1_LAYER, ")")
	else:
		# Default to both players if wielder is unknown
		target_mask = PLAYER1_LAYER | PLAYER2_LAYER
		print("WARNING: Unknown wielder, targeting both players")
	
	# Include world objects in collision if needed
	var world_mask = WORLD_LAYER if include_world else 0
	
	# Set the final collision mask
	object.collision_mask = target_mask | world_mask
	print("Final collision mask set to: ", object.collision_mask)
	
	return object.collision_mask
