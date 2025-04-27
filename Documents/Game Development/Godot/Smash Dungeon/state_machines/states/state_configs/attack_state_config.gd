# state_configs/attack_state_config.gd
extends Resource
class_name AttackStateConfig

@export var attack_commitment: float = 0.3 # Time after attack execution
@export var attack_retreat_distance: float = 0.0 # Distance to trigger retreat via RepositioningState
