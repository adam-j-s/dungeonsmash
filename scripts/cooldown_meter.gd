# cooldown_meter.gd - Updated version
extends CanvasLayer

# Reference to the weapon being tracked
var weapon = null

# Positioning offset
var position_offset_value = Vector2(-25, -30)  # Default position above player

# Bar properties
var bar_width = 50
var bar_height = 5

func _ready():
	# Get references to UI elements
	var progress_bar = $Control/ProgressBar
	var background = $Control/Background
	
	# Set up sizes directly
	if background:
		background.size = Vector2(bar_width, bar_height)
		background.color = Color(0.2, 0.2, 0.2, 0.5)
	
	if progress_bar:
		progress_bar.size = Vector2(bar_width, bar_height)
		progress_bar.modulate = Color(1, 0.7, 0, 0.8)
		progress_bar.min_value = 0
		progress_bar.max_value = 100
		progress_bar.value = 0
	
	# Initially hide the meter
	visible = false

# Call this to connect the meter to a weapon
func setup(target_weapon):
	weapon = target_weapon
	visible = false

func _process(delta):
	if weapon == null or not is_instance_valid(weapon):
		visible = false
		return
		
	if weapon.cooldown_timer == null:
		visible = false
		return
	
	# Update position if wielder exists
	if weapon.wielder and is_instance_valid(weapon.wielder):
		$Control.global_position = weapon.wielder.global_position + position_offset_value
	
	# Check if weapon is in cooldown
	if weapon.cooldown_timer.time_left > 0:
		# Calculate and display the cooldown progress (0-100%)
		var progress_bar = $Control/ProgressBar
		if progress_bar:
			var percent = 1.0 - (weapon.cooldown_timer.time_left / weapon.cooldown_timer.wait_time)
			progress_bar.value = percent * 100
		visible = true
	else:
		# Hide when ready to attack
		visible = false

# Set the position offset
func set_position_offset(new_offset):
	position_offset_value = new_offset
