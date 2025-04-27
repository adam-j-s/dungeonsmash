# Telegraph State Configs
extends Resource
class_name TelegraphStateConfig

@export var telegraph_duration: float = 0.6
# Use an enum for restricted string options, displays as dropdown in inspector
@export_enum("none", "default", "custom") var telegraph_movement_type: String = "none"
