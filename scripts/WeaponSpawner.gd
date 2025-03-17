extends Node2D

# Spawner settings
@export var weapon_pickup_scene: PackedScene  # Reference to weapon_pickup.tscn
@export var spawn_interval_min: float = 5.0  # Minimum seconds between spawns
@export var spawn_interval_max: float = 10.0  # Maximum seconds between spawns
@export var max_weapons: int = 3  # Maximum weapons on screen at once
@export var spawn_points: Array[NodePath] = []  # Array of spawn point nodes
@export var max_weapon_tier: int = 1  # Maximum tier of weapons to spawn (0=common, 1=uncommon, etc.)

# Runtime variables
var timer = null
var active_pickups = []

func _ready():
	# Create spawn timer
	timer = Timer.new()
	timer.one_shot = true
	timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(timer)
	
	# Start the spawning cycle
	schedule_next_spawn()
	print("WeaponSpawner _ready() called")
	
func schedule_next_spawn():
	# Random time until next spawn
	var wait_time = randf_range(spawn_interval_min, spawn_interval_max)
	timer.wait_time = wait_time
	timer.start()
	print("Next weapon will spawn in " + str(wait_time) + " seconds")

func _on_spawn_timer_timeout():
	print("Timer timeout - attempting to spawn")
	# Only spawn if we're under the maximum
	if active_pickups.size() < max_weapons:
		spawn_weapon()
	else:
		print("Maximum weapons reached, skipping spawn")
	
	# Schedule the next spawn
	schedule_next_spawn()

func spawn_weapon():
	# If no spawn points, can't spawn
	if spawn_points.size() == 0:
		print("ERROR: No spawn points defined!")
		return
	
	# Select random spawn point
	var spawn_index = randi() % spawn_points.size()
	var spawn_point = get_node(spawn_points[spawn_index])
	
	# Create the weapon pickup
	var pickup = weapon_pickup_scene.instantiate()
	
	# Update to use the new pickup mode enum - FULLY_RANDOM = 3 in our new system
	# Note: the old system used 2 for RANDOM, but our new system uses a different enum
	if pickup.has_method("set_pickup_mode"):
		pickup.set_pickup_mode(3)  # FULLY_RANDOM in the new system
	elif pickup.has_method("update_pickup_mode"):
		pickup.update_pickup_mode(3)  # FULLY_RANDOM in the new system
	elif "pickup_mode" in pickup:
		pickup.pickup_mode = 3  # FULLY_RANDOM in the new system
	else:
		# Fallback for compatibility - try setting max_tier
		if "max_tier" in pickup:
			pickup.max_tier = max_weapon_tier
		print("Warning: Could not set pickup mode on weapon pickup")
	
	# Position at the spawn point
	pickup.position = spawn_point.global_position
	
	# Keep track of active pickups
	active_pickups.append(pickup)
	
	# Add to scene - using get_parent() to add to the arena instead of the spawner
	get_parent().add_child(pickup)
	print("Spawned new weapon pickup at " + str(pickup.position))
	
	# Set up removal tracking
	pickup.tree_exiting.connect(_on_pickup_removed.bind(pickup))

func _on_pickup_removed(pickup):
	# Remove from our tracking array when a pickup is removed
	active_pickups.erase(pickup)
	print("Weapon pickup removed, active count: " + str(active_pickups.size()))
