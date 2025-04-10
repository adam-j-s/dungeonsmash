extends Node2D

# Timer settings
@export var match_duration = 60  # Seconds for the match
var time_remaining = 0
var timer_label = null
var match_timer = null  # Added variable for the timer

func _ready():
	# Apply character selections from GameManager
	var player1 = $Player1
	var player2 = $Player2
	
	if player1 and GameManager.player1_character:
		player1.character_class_id = GameManager.player1_character
		print("Player 1 using character: " + GameManager.player1_character)
	
	if player2 and GameManager.player2_character:
		player2.character_class_id = GameManager.player2_character
		print("Player 2 using character: " + GameManager.player2_character)
	
	# Initialize timer
	time_remaining = match_duration
	
	# Create timer UI
	create_timer_ui()
	
	#setup cooldown UI
	setup_cooldown_ui()
	
	# Start the countdown
	match_timer = Timer.new()  # Store reference to the timer
	match_timer.wait_time = 1.0
	match_timer.autostart = true
	match_timer.timeout.connect(_on_timer_tick)
	add_child(match_timer)
	
	# Connect player defeat signals
	$Player1.player_defeated.connect(_on_player_defeated)
	$Player2.player_defeated.connect(_on_player_defeated)
	
	# Print all direct children for debugging
	print("Direct children of this node:")
	for child in get_children():
		print("- ", child.name, " (", child.get_class(), ")")
		
		
func _process(delta):
	#update coold ui
	update_cooldown_ui()
	
func create_timer_ui():
	# Create CanvasLayer for UI
	var ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	
	# Create timer label
	timer_label = Label.new()
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timer_label.position = Vector2(512, 30)  # Center top of screen
	timer_label.size = Vector2(100, 30)  # Corrected height
	timer_label.add_theme_font_size_override("font_size", 24)
	ui_layer.add_child(timer_label)
	
	# Initial update
	update_timer_display()

func setup_cooldown_ui():
	# Create Player 1 cooldown bar
	var p1_cooldown = ProgressBar.new()
	p1_cooldown.name = "CooldownBar"
	p1_cooldown.min_value = 0
	p1_cooldown.max_value = 1
	p1_cooldown.value = 0
	p1_cooldown.size = Vector2(100, 8)
	p1_cooldown.position = Vector2(-50, -20)  # Above the player
	p1_cooldown.modulate = Color(1, 0.7, 0, 0.8)  # Golden yellow
	$Player1.add_child(p1_cooldown)
	
	# Create Player 2 cooldown bar
	var p2_cooldown = ProgressBar.new()
	p2_cooldown.name = "CooldownBar"
	p2_cooldown.min_value = 0
	p2_cooldown.max_value = 1
	p2_cooldown.value = 0
	p2_cooldown.size = Vector2(100, 8)
	p2_cooldown.position = Vector2(-50, -20)  # Above the player
	p2_cooldown.modulate = Color(1, 0.7, 0, 0.8)  # Golden yellow
	$Player2.add_child(p2_cooldown)

func update_cooldown_ui():
	# Update Player 1 cooldown bar
	if $Player1.has_node("Weapon") and $Player1.has_node("CooldownBar"):
		var weapon = $Player1.get_node("Weapon")
		if weapon.cooldown_timer:
			if !weapon.can_attack:
				# Calculate progress (0 to 1)
				var percent = 1.0 - (weapon.cooldown_timer.time_left / weapon.cooldown_timer.wait_time)
				$Player1.get_node("CooldownBar").value = percent
				$Player1.get_node("CooldownBar").visible = true
			else:
				# Hide when ready to attack
				$Player1.get_node("CooldownBar").visible = false
	
	# Update Player 2 cooldown bar (same logic)
	if $Player2.has_node("Weapon") and $Player2.has_node("CooldownBar"):
		var weapon = $Player2.get_node("Weapon")
		if weapon.cooldown_timer:
			if !weapon.can_attack:
				var percent = 1.0 - (weapon.cooldown_timer.time_left / weapon.cooldown_timer.wait_time)
				$Player2.get_node("CooldownBar").value = percent
				$Player2.get_node("CooldownBar").visible = true
			else:
				$Player2.get_node("CooldownBar").visible = false

func _on_timer_tick():
	if time_remaining > 0:
		time_remaining -= 1
		update_timer_display()
	else:
		time_up()

func update_timer_display():
	var minutes = time_remaining / 60
	var seconds = time_remaining % 60
	timer_label.text = "%d:%02d" % [minutes, seconds]

func time_up():
	print("time_up function called")
	
	# Stop the Timer
	match_timer.stop()
	print("Timer stopped")
	
	# Determine winner based on remaining health
	print("Attempting to access player health")
	var player1_health_percent = 0.0
	var player2_health_percent = 0.0
	var player1_found = false
	var player2_found = false
	
	# Print all direct children again to verify
	print("Children at time_up:")
	for child in get_children():
		print("- ", child.name, " (", child.get_class(), ")")
		# Check if this is a player node
		if child.name == "Player1":
			player1_found = true
			print("Player1 node exists and is type: ", child.get_class())
			# Try to access health property
			if child.get("health") != null:
				player1_health_percent = float(child.health) / child.MAX_HEALTH
				print("Player 1 health percent: ", player1_health_percent)
			else:
				print("Player1 node exists but health property is null")
		elif child.name == "Player2":
			player2_found = true
			print("Player2 node exists and is type: ", child.get_class())
			# Try to access health property
			if child.get("health") != null:
				player2_health_percent = float(child.health) / child.MAX_HEALTH
				print("Player 2 health percent: ", player2_health_percent)
			else:
				print("Player2 node exists but health property is null")
	
	if !player1_found:
		print("Player1 node not found among children")
	if !player2_found:
		print("Player2 node not found among children")
	
	# If we have valid health percentages, determine winner
	var winner = ""
	var winner_num = 0
	if player1_found and player2_found:
		if player1_health_percent > player2_health_percent:
			winner = "Player 1 Wins!"
			winner_num = 1
		elif player2_health_percent > player1_health_percent:
			winner = "Player 2 Wins!"
			winner_num = 2
		else:
			winner = "Draw!"
			winner_num = 0
	else:
		# Default winner if players not found
		winner = "Game Over!"
	
	print("Winner determined: " + winner)
	
	# Update the GameManager with the result
	GameManager.winner = winner_num
	
	# Display result on timer label
	if timer_label != null:
		timer_label.text = "Time Up! " + winner
	
	# Show game over screen
	show_game_over(winner)
	print("Game over handling completed")

func _on_player_defeated(player_number):
	var winner_text = "Player " + str(3 - player_number) + " Wins!"
	var winner_num = 3 - player_number
	
	# Update GameManager
	GameManager.winner = winner_num
	
	show_game_over(winner_text)

func show_game_over(winner_text):
	print("show_game_over called with: " + winner_text)
	
	# Create a CanvasLayer to hold the game over screen
	var canvas_layer = CanvasLayer.new()
	add_child(canvas_layer)
	print("Canvas layer created")
	
	# Attempt to load game over scene
	print("Attempting to load game over screen")
	var game_over_scene = null
	
	# Check if file exists at primary path
	if ResourceLoader.exists("res://scenes/game_over_screen.tscn"):
		print("Game over scene file exists")
		game_over_scene = load("res://scenes/game_over_screen.tscn").instantiate()
		print("Game over scene loaded successfully")
	else:
		print("Game over scene file does not exist at path: res://scenes/game_over_screen.tscn")
		# Try alternative path in case the file is in a different location
		if ResourceLoader.exists("res://game_over_screen.tscn"):
			print("Found at alternative path: res://game_over_screen.tscn")
			game_over_scene = load("res://game_over_screen.tscn").instantiate()
	
	if game_over_scene == null:
		print("Failed to load game over scene - creating simple label instead")
		var label = Label.new()
		label.text = "Game Over! " + winner_text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.position = Vector2(512, 300)
		label.size = Vector2(300, 100)
		label.add_theme_font_size_override("font_size", 24)
		canvas_layer.add_child(label)
		return
	
	# Continue if scene loaded successfully
	print("Adding game over scene to canvas layer")
	canvas_layer.add_child(game_over_scene)
	
	# Now call the set_winner method if it exists
	if game_over_scene.has_method("set_winner"):
		print("Calling set_winner method")
		game_over_scene.set_winner(winner_text)
	else:
		print("WARNING: game_over_scene does not have set_winner method")

# Add this to battle_arena.gd or your main scene script

func _input(event):
	# Only enable in debug builds
	if OS.is_debug_build():
		# Check for weapon spawn hotkeys
		if event is InputEventKey and event.pressed:
			var weapon_id = ""
			
			# Number keys 1-9 for different weapons
			match event.keycode:
				KEY_1:
					weapon_id = "homing_cluster"
				KEY_2: 
					weapon_id = "laser_drill"
				KEY_3:
					weapon_id = "singularity_bomb"
				KEY_4:
					weapon_id = "mini_cluster"
				KEY_5:
					weapon_id = "homing_cluster"
				KEY_6:
					weapon_id = "wave_wand"
				KEY_7:
					weapon_id = "homing_orb"
				KEY_8:
					weapon_id = "bouncing_blade"
				KEY_9:
					weapon_id = "explosive_bomb"
			
			# If a valid key was pressed, spawn that weapon
			if weapon_id != "":
				spawn_test_weapon(weapon_id)

# Add this function to spawn a specific weapon
func spawn_test_weapon(weapon_id):
	# Create weapon pickup
	var weapon_pickup = load("res://scenes/weapon_pickup.tscn").instantiate()
	
	# Set the specific weapon ID
	weapon_pickup.set_weapon_id(weapon_id)
	
	# Position in center of screen or other visible location
	weapon_pickup.position = Vector2(get_viewport_rect().size.x / 2, get_viewport_rect().size.y / 2)
	
	# Add to scene
	add_child(weapon_pickup)
	
	print("TEST: Spawned " + weapon_id + " for testing")
