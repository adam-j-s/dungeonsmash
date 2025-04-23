@tool
extends EditorScript

func _run():
	# Create directory if it doesn't exist
	var dir = DirAccess.open("res://")
	var config_dir_path = "resources/components/configs"
	if not dir.dir_exists(config_dir_path):
		var err_mk = dir.make_dir_recursive(config_dir_path)
		if err_mk != OK:
			printerr("Failed to create directory: %s, error code: %d" % [config_dir_path, err_mk])
			return # Stop if directory creation fails
	
	# Create the config
	var config = SurfaceMovementConfig.new()
	
	# Set default values
	config.surface_speed = 70.0
	config.corner_behavior = 0 # Follow Wall
	config.jump_force = Vector2(150, -150)
	config.change_direction_chance = 0.02
	config.raycast_distance = 32.0
	config.stuck_threshold = 1.0
	
	# Save the resource
	var file_path = "res://%s/default_surface_movement_config.tres" % config_dir_path
	var err = ResourceSaver.save(config, file_path)
	if err == OK:
		print("Successfully saved %s" % file_path)
	else:
		printerr("Failed to save %s, error code: %d" % [file_path, err])
