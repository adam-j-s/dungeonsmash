# improved_rapid_cooldown_behavior.gd - Modifies weapon cooldown times
class_name ImprovedRapidCooldownBehavior
extends BehaviorBase

# Cooldown reduction factor
var cooldown_factor = 0.7  # 30% reduction by default
var active_cooldown_buff = false
var buff_duration = 0.0
var buff_timer = null

func _init_behavior():
	# Initialize with parameter if provided
	cooldown_factor = float(get_param("cooldown_factor", 0.7))
	buff_duration = float(get_param("buff_duration", 0.0))
	
	if DEBUG:
		print("Initialized rapid cooldown behavior with factor: ", cooldown_factor)

func get_behavior_name() -> String:
	return "RapidCooldownBehavior"

# This function is specifically for modifying cooldowns
func modify_cooldown(current_cooldown: float) -> float:
	# Apply stronger buff if active
	if active_cooldown_buff:
		return current_cooldown * (cooldown_factor * 0.8)  # Additional 20% reduction when buff active
	return current_cooldown * cooldown_factor

# Called when the weapon is used
func on_weapon_used():
	if DEBUG:
		print("Rapid cooldown effect applied")
	
	# If we have a temporary buff duration, activate it
	if buff_duration > 0:
		activate_cooldown_buff()

# Called on hit - can trigger cooldown buff
func on_hit(target):
	# Chance to activate cooldown buff on successful hit
	if randf() < 0.2:  # 20% chance
		activate_cooldown_buff()
		
		if DEBUG:
			print("Hit triggered rapid cooldown buff!")

# Activate a temporary stronger cooldown reduction
func activate_cooldown_buff():
	active_cooldown_buff = true
	
	# Create visual effect on weapon if possible
	if weapon:
		# Apply visual effect to weapon
		for child in weapon.get_children():
			if child is Sprite2D or child is ColorRect:
				child.modulate = Color(0.5, 0.8, 1.0)  # Cool blue effect
	
	# Clean up any existing timer
	if buff_timer and is_instance_valid(buff_timer):
		buff_timer.queue_free()
		buff_timer = null
	
	# Reset buff after duration
	if buff_duration > 0:
		buff_timer = Timer.new()
		buff_timer.wait_time = buff_duration
		buff_timer.one_shot = true
		
		if weapon:
			weapon.add_child(buff_timer)
			buff_timer.timeout.connect(func():
				deactivate_cooldown_buff()
				buff_timer = null
			)
			buff_timer.start()
	
	if DEBUG:
		print("Activated rapid cooldown buff! Factor: ", cooldown_factor * 0.8)

# Turn off the cooldown buff
func deactivate_cooldown_buff():
	active_cooldown_buff = false
	
	# Reset visual effect
	if weapon:
		# Remove visual effect from weapon
		for child in weapon.get_children():
			if child is Sprite2D or child is ColorRect:
				child.modulate = Color(1.0, 1.0, 1.0)  # Reset to normal
	
	if DEBUG:
		print("Deactivated rapid cooldown buff")
