@tool
extends EditorScript

# Tool script to add EnemyWeaponSystem to existing enemy scenes

func _run():
	print("Starting weapon system integration...")
	
	# Set up paths to search
	var enemy_paths = [
		"res://scenes/enemies/",
		"res://scripts/enemies/"
	]
	
	# Statistics
	var scenes_found = 0
	var scenes_modified = 0
	
	# Process each directory
	for dir_path in enemy_paths:
		print("Searching directory: " + dir_path)
		var result = process_directory(dir_path)
		scenes_found += result[0]
		scenes_modified += result[1]
	
	print("Completed weapon system integration")
	print("Scenes found: " + str(scenes_found))
	print("Scenes modified: " + str(scenes_modified))

# Process a directory recursively, returns [scenes_found, scenes_modified]
func process_directory(path: String) -> Array:
	var local_scenes_found = 0
	var local_scenes_modified = 0
	
	var dir = DirAccess.open(path)
	if not dir:
		print("Could not open directory: " + path)
		return [local_scenes_found, local_scenes_modified]
		
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if dir.current_is_dir() and not file_name.begins_with("."):
			# Recursively process subdirectories
			var result = process_directory(path + file_name + "/")
			local_scenes_found += result[0]
			local_scenes_modified += result[1]
		elif file_name.ends_with(".tscn"):
			# Process scene file
			local_scenes_found += 1
			var scene_path = path + file_name
			print("Processing scene: " + scene_path)
			
			if process_scene(scene_path):
				local_scenes_modified += 1
				
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	return [local_scenes_found, local_scenes_modified]

# Process a single scene file
func process_scene(scene_path: String) -> bool:
	# Load the scene
	var packed_scene = load(scene_path)
	if not packed_scene:
		print("  - Could not load scene: " + scene_path)
		return false
		
	# Instantiate to check
	var scene_root = packed_scene.instantiate()
	if not scene_root is BaseEnemy:
		print("  - Not a BaseEnemy: " + scene_path)
		scene_root.queue_free()
		return false
		
	# Check if it already has a weapon system
	if scene_root.has_node("WeaponSystem"):
		print("  - Already has WeaponSystem: " + scene_path)
		scene_root.queue_free()
		return false
		
	# Add weapon system
	print("  - Adding WeaponSystem to: " + scene_path)
	var weapon_system = EnemyWeaponSystem.new()
	weapon_system.name = "WeaponSystem"
	scene_root.add_child(weapon_system)
	
	# Ensure the owner is set correctly
	weapon_system.owner = scene_root
	
	# Save the modified scene
	var modified_scene = PackedScene.new()
	var result = modified_scene.pack(scene_root)
	
	if result != OK:
		print("  - ERROR: Failed to pack scene: " + str(result))
		scene_root.queue_free()
		return false
		
	# Save back to the file
	result = ResourceSaver.save(modified_scene, scene_path)
	
	if result != OK:
		print("  - ERROR: Failed to save scene: " + str(result))
		scene_root.queue_free()
		return false
		
	print("  - Successfully modified scene: " + scene_path)
	scene_root.queue_free()
	return true
