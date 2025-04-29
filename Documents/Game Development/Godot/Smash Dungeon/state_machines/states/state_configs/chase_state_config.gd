# state_configs/chase_state_config.gd
extends Resource
class_name ChaseStateConfig

# Define the different ways the enemy can jump in chase state
enum JumpType {
	VERTICAL, # Only apply vertical force, horizontal movement from regular chase logic
	AIMED,    # Apply force directly towards the target's position (creating an arc)
	# RANDOM_DIRECTED # Example: Apply force vertically + random horizontal component
}

@export_group("Detection & Range")
@export var sight_range: float = 600.0
@export var preferred_attack_distance: float = 150.0
@export var preferred_distance_tolerance: float = 50.0

@export_group("Movement")
@export var chase_speed_multiplier: float = 1.2
@export var direct_chase: bool = false

@export_group("Jumping") # Group jump parameters together
@export var chase_jump_chance: float = 0.0
@export var chase_jump_force: float = 300.0
@export var chase_jump_type: JumpType = JumpType.VERTICAL

@export_group("Behavior")
@export var aggression_level: float = 0.5 # Range usually 0.0 to 1.0, but logic handles higher values
