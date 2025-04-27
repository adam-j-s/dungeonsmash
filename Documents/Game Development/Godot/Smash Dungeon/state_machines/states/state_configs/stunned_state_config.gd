# state_configs/stunned_state_config.gd
extends Resource
class_name StunnedStateConfig

@export var stun_duration: float = 1.0 # Default duration if not overridden by message
