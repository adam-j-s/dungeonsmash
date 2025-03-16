extends Node2D

# Timer settings
@export var match_duration = 20  # Seconds for the match
var time_remaining = 0
var timer_label = null
var match_timer = null  # Added variable for the timer

func _ready():
	# Initialize timer
	time_remaining = match_duration
	
	# Create timer UI
	create_timer_ui()
	
	# Start the countdown
	match_timer = Timer.new()  # Store reference to the timer
	match_timer.wait_time = 1.0
	match_timer.autostart = true
	match_timer.timeout.connect(_on_timer_tick)
	add_child(match_timer)
	
	# Connect player defeat signals without using bind, which causes issues
	$Player1.player_defeated.connect(_on_player_defeated)
	$Player2.player_defeated.connect(_on_player_defeated)
	
	# Print all direct children for debugging
	print("Direct children of this node:")
	for child in get_children():
		print("- ", child.name, " (", child.get_class(), ")")
		
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
	if player1_found and player2_found:
		if player1_health_percent > player2_health_percent:
			winner = "Player 1 Wins!"
		elif player2_health_percent > player1_health_percent:
			winner = "Player 2 Wins!"
		else:
			winner = "Draw!"
	else:
		# Default winner if players not found
		winner = "Game Over!"
	
	print("Winner determined: " + winner)
	
	# Display result on timer label
	if timer_label != null:
		timer_label.text = "Time Up! " + winner
	
	# Show game over screen
	show_game_over(winner)
	print("Game over handling completed")

func _on_player_defeated(player_number):
	var winner_text = "Player " + str(3 - player_number) + " Wins!"
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
