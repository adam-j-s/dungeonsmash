# surface_movement_config.gd
class_name SurfaceMovementConfig
extends Resource

@export var surface_speed: float = 70.0
@export_enum("Follow Wall:0", "Reverse:1", "Jump:2") var corner_behavior: int = 0
@export var jump_force: Vector2 = Vector2(150, -150)
@export var change_direction_chance: float = 0.02
@export var raycast_distance: float = 32.0
@export var stuck_threshold: float = 1.0
