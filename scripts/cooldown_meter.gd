# cooldown_meter.gd - For your existing CanvasLayer-based scene
extends CanvasLayer

# Progress tracking
var progress = 1.0  # Start as ready (0.0 = on cooldown, 1.0 = ready)

# Reference to the progress bar
var progress_bar
var background

# Circle settings
var radius = 15
var color = Color(0.2, 0.7, 1.0, 0.8)
var ready_color = Color(0.2, 1.0, 0.2, 0.8)
var background_color = Color(0.2, 0.2, 0.2, 0.5)
var counter_clockwise = true

func _ready():
	# Get the control node
	var control = $Control
	
	# Remove the existing progress bar
	if control.has_node("ProgressBar"):
		progress_bar = control.get_node("ProgressBar")
		progress_bar.queue_free()
	
	if control.has_node("Background"):
		background = control.get_node("Background")
		background.queue_free()
	
	# Create a custom draw control to handle the circle
	var circle_control = Control.new()
	circle_control.name = "CircleControl"
	circle_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	circle_control.custom_minimum_size = Vector2(radius * 2, radius * 2)
	control.add_child(circle_control)
	
	# Add the drawing code
	circle_control.draw.connect(_on_circle_draw.bind(circle_control))
	
	# Position the control - adjust as needed
	control.position = Vector2(40, 40)  # Position below health bar
	control.custom_minimum_size = Vector2(radius * 2, radius * 2)
	
# cooldown_meter.gd - Add the setup method
func setup(weapon):
	# Store a reference to the weapon for tracking
	# No need to actually store it since we'll update via set_progress
	
	# Just initialize the progress to full if weapon is ready to fire
	if weapon.can_attack:
		progress = 1.0
	else:
		# If on cooldown, calculate current progress
		if weapon.cooldown_timer and !weapon.cooldown_timer.is_stopped():
			progress = 1.0 - (weapon.cooldown_timer.time_left / weapon.cooldown_timer.wait_time)
		else:
			progress = 1.0
			
	# Force redraw to show initial state
	if has_node("Control/CircleControl"):
		$Control/CircleControl.queue_redraw()

func _on_circle_draw(control):
	# First fill the entire control with a transparent color to remove any artifacts
	control.draw_rect(Rect2(0, 0, control.size.x, control.size.y), Color(0,0,0,0))
	# Make the radius larger for a wider circle
	radius = 20  # Increased from 15 to 20
	
	# Draw background circle (empty state)
	var center = Vector2(radius, radius)
	
	# Draw background/empty circle
	control.draw_circle(center, radius, background_color)
	
	if progress >= 1.0:
		# When ready, show a solid green circle that fits precisely inside the border
		control.draw_circle(center, radius - 2, ready_color)
	else:
		# For partial progress, first ensure we have a clean background
		control.draw_circle(center, radius - 2, background_color)
		
		# Draw gradient arc based on progress
		# We'll divide the arc into small segments and color each one
		var segments = 24  # Number of segments for smooth gradient
		var segment_angle = TAU / segments
		
		# Start from top (-PI/2)
		var start_angle = -PI/2
		
		# Calculate how many segments to draw based on progress
		var segments_to_draw = int(progress * segments)
		
		# Draw a pie/sector shape instead of arcs
		for i in range(segments_to_draw):
			# Calculate the segment's progress percentage (0.0 to 1.0)
			var segment_progress = float(i) / segments
			
			# Calculate the color based on progress
			var color = get_color_for_progress(segment_progress)
			
			# Calculate segment angles
			var seg_start = start_angle - (i * segment_angle)
			var seg_end = start_angle - ((i + 1) * segment_angle)
			
			# Points for the triangle/sector
			var points = PackedVector2Array([
				center,  # Center point
				center + Vector2(cos(seg_start), sin(seg_start)) * (radius - 3),  # Start point on edge
				center + Vector2(cos(seg_end), sin(seg_end)) * (radius - 3)  # End point on edge
			])
			
			# Draw filled triangle/sector
			control.draw_polygon(points, [color])
	
	# Always draw the white border last, so it's on top
	control.draw_arc(center, radius, 0, TAU, 32, Color(1, 1, 1, 0.7), 2)  # White border
			
func get_color_for_progress(progress):
	# Define our gradient colors
	var colors = [
		Color(1.0, 0.2, 0.2),  # Red (0-25%)
		Color(1.0, 0.6, 0.1),  # Orange (26-50%)
		Color(1.0, 0.9, 0.1),  # Yellow (51-75%)
		Color(0.1, 0.8, 1.0)   # Green (76-100%)
	]
	
	# Determine which color range we're in
	var idx = int(progress * 4)
	idx = min(idx, 3)  # Clamp to valid range
	
	# For smoother transition, lerp between colors
	var next_idx = min(idx + 1, 3)
	var local_progress = (progress * 4) - idx
	
	# Return interpolated color
	return colors[idx].lerp(colors[next_idx], local_progress)
