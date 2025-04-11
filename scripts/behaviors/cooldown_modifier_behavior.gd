# Modifies weapon cooldown times
class_name CooldownModifierBehavior
extends BehaviorBase

# Cooldown reduction factor
var cooldown_factor = 1.0  # Default factor (no modification)
var active_cooldown_buff = false
var buff_duration = 0.0
var buff_timer = null

func _init_behavior():
	# Initialize with parameter - improved JSON structure handling
	var factor_param = get_param("cooldown_factor", "0.7")
	var duration_param = get_param("buff_duration", "0.0")
	
	# Parse cooldown_factor with type handling
	if typeof(factor_param) == TYPE_DICTIONARY and factor_param.has("value"):
		cooldown_factor = float(factor_param.value)
	elif typeof(factor_param) == TYPE_FLOAT:
		cooldown_factor = factor_param
	elif typeof(factor_param) == TYPE_STRING:
		if "=" in factor_param:
			var parts = factor_param.split("=")
			if parts.size() > 1:
				cooldown_factor = float(parts[1].strip_edges())
		else:
			cooldown_factor = float(factor_param)
	else:
		# Default fallback
		cooldown_factor = 0.7
	
	# Parse buff_duration with type handling
	if typeof(duration_param) == TYPE_DICTIONARY and duration_param.has("value"):
		buff_duration = float(duration_param.value)
	elif typeof(duration_param) == TYPE_FLOAT:
		buff_duration = duration_param
	elif typeof(duration_param) == TYPE_STRING:
		if "=" in duration_param:
			var parts = duration_param.split("=")
			if parts.size() > 1:
				buff_duration = float(parts[1].strip_edges())
		else:
			buff_duration = float(duration_param)
	else:
		# Default fallback
		buff_duration = 0.0
	
	# Check for parameters in JSON behaviors array
	if weapon and "weapon_data" in weapon:
		if "behaviors" in weapon.weapon_data and typeof(weapon.weapon_data.behaviors) == TYPE_ARRAY:
			for behavior in weapon.weapon_data.behaviors:
				if typeof(behavior) == TYPE_DICTIONARY and behavior.has("type") and behavior.type == "rapid":
					if "params" in behavior and typeof(behavior.params) == TYPE_DICTIONARY:
						# Override with specific params from the behavior entry
						if "cooldown_factor" in behavior.params:
							cooldown_factor = float(behavior.params.cooldown_factor)
						if "buff_duration" in behavior.params:
							buff_duration = float(behavior.params.buff_duration)
	
	if DEBUG:
		print("Initialized rapid cooldown behavior with factor: ", cooldown_factor)
		print("Buff duration: ", buff_duration)

func get_behavior_name() -> String:
	return "CooldownModifierBehavior"

# This function is specifically for modifying cooldowns
func modify_cooldown(current_cooldown: float) -> float:
	# Use the stored cooldown factor instead of getting from params again
	var factor = cooldown_factor
	
	# Store the base factor for debugging
	var base_factor = factor
	
	# Apply stronger buff if active buff is present
	if active_cooldown_buff:
		# Apply an additional 20% reduction when buff is active
		factor *= 0.8  # This makes it 20% faster
	
	# Calculate the modified cooldown
	var modified_cooldown = current_cooldown * factor
	
	# Debug output
	if DEBUG:
		print("CooldownModifier: Base cooldown=", current_cooldown, 
			", Factor=", base_factor, 
			", With buff=", factor,
			", Result=", modified_cooldown)
	
	# Return the modified value - no minimum applied here
	# (minimum safety value is handled by weapon_base.gd)
	return modified_cooldown

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
	if weapon and is_instance_valid(weapon):
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
		
		if weapon and is_instance_valid(weapon):
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
	if weapon and is_instance_valid(weapon):
		# Remove visual effect from weapon
		for child in weapon.get_children():
			if child is Sprite2D or child is ColorRect:
				child.modulate = Color(1.0, 1.0, 1.0)  # Reset to normal
	
	if DEBUG:
		print("Deactivated rapid cooldown buff")
