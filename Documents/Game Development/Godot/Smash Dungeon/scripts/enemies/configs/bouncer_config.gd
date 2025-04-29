# res://scripts/enemies/configs/bouncer_config.gd
extends EnemyConfig # <-- IMPORTANT: Inherit from EnemyConfig
class_name BouncerConfig

# Define ONLY the properties unique to the Bouncer here
@export_group("Bouncer Behavior")
@export var bump_damage: int = 5
@export var collision_damage_cooldown: float = 0.5
@export var direction_change_cooldown: float = 0.5
@export var stuck_threshold: float = 1.0
