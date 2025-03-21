# rapid_cooldown_behavior.gd - Modifies weapon cooldown times
class_name RapidCooldownBehavior
extends Behavior

# Cooldown reduction factor
var cooldown_factor = 0.7  # 30% reduction by default

func _init_behavior():
	# Initialize with parameter if provided
	cooldown_factor = float(get_param("cooldown_factor", 0.7))
	
	if DEBUG:
		print("Initialized rapid cooldown behavior with factor: ", cooldown_factor)

func get_behavior_name() -> String:
	return "RapidCooldownBehavior"

# This function is specifically for modifying cooldowns
func modify_cooldown(current_cooldown: float) -> float:
	return current_cooldown * cooldown_factor
