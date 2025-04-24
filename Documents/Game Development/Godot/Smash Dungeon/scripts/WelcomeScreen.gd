extends Control

# Path to character select scene
@export var character_select_path = "res://scenes/character_select.tscn"

func _ready():
	# Connect the button's pressed signal
	$StartButton.pressed.connect(_on_start_button_pressed)

	# Background animation
	var tween = create_tween().set_loops()
	tween.tween_property($Background, "modulate", Color(0.9, 0.9, 1.0), 2.0)
	tween.tween_property($Background, "modulate", Color(1.0, 0.9, 0.9), 2.0)

	# --- CHANGE: Use a short Timer instead of call_deferred ---
	var timer = Timer.new()
	timer.wait_time = 0.01 # Very short delay, just to push past the immediate frame end
	timer.one_shot = true
	# Connect timeout using Callable for clarity
	timer.timeout.connect(Callable(self, "_check_arena_database_status"))
	add_child(timer) # Timer needs to be in the tree to run
	timer.start()
	# ---------------------------------------------------------

func _check_arena_database_status():
	print("Timer check running...") # Updated print
	
	# --- Direct Access Attempt ---
	if ArenaDatabase != null: # Use the Autoload name directly
		print("Direct access SUCCEEDED (Direct Access)")
		print("Available arenas (via Direct Access): ", ArenaDatabase.get_all_arena_ids())
	else:
		print("Direct access FAILED (ArenaDatabase is null).")

	# Check Method 1: Using has_singleton
	var found_by_singleton_check = Engine.has_singleton("ArenaDatabase") # Use the new name
	print("Engine.has_singleton('ArenaDatabase') check result: ", found_by_singleton_check)

	# Check Method 2: Accessing via /root/ path
	var found_by_path_check = has_node("/root/ArenaDatabase") # Use the new name
	var node_by_path = get_node_or_null("/root/ArenaDatabase") # Use the new name
	print("has_node('/root/ArenaDatabase') check result: ", found_by_path_check)
	print("get_node('/root/ArenaDatabase') result: ", node_by_path)

	if found_by_singleton_check:
		print("Singleton check PASSED. Accessing ArenaDatabase...")
		if ArenaDatabase != null: # Use the new name
			print("Available arenas (via Singleton): ", ArenaDatabase.get_all_arena_ids()) # Use the new name
		else:
			print("WARNING: ArenaDatabase reference is null even though has_singleton was true!")
	else:
		print("Singleton check FAILED.")

	if found_by_path_check and node_by_path != null:
		print("Path check PASSED. Trying to access via get_node...")
		if node_by_path.has_method("get_all_arena_ids"):
			print("Available arenas (via get_node): ", node_by_path.get_all_arena_ids())
		else:
			print("Node found by path doesn't have get_all_arena_ids method?")
	else:
		print("Path check FAILED.")

	if not found_by_singleton_check:
		print("WARNING: ArenaDatabase still not found as singleton (checked by Timer)") # Updated print


func _process(_delta):
	# Start game when any button is pressed
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("p2_accept"):
		_on_start_button_pressed()

func _on_start_button_pressed():
	# Change to the character select scene
	# It should be safe to access ArenaDatabase here as it's user-triggered
	print("Start button pressed, changing scene...")
	if ArenaDatabase != null:
		print("   ArenaDatabase found before scene change.")
	else:
		print("   WARNING: ArenaDatabase still not found before scene change!")
	get_tree().change_scene_to_file("res://scenes/character_select.tscn")
