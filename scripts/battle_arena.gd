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
	
	$Player1.player_defeated.connect(_on_player_defeated.bind(1))
	$Player2.player_defeated.connect(_on_player_defeated.bind(2))

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

func _on_timer_tick():  # Fixed function name
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
	# Stop the Timer
	match_timer.stop()
	
	# Determine winner based on remaining health
	var player1_health_percent = float($Player1.health) / $Player1.MAX_HEALTH  # Corrected node name
	var player2_health_percent = float($Player2.health) / $Player2.MAX_HEALTH  # Corrected node name
	
	var winner = ""
	if player1_health_percent > player2_health_percent:
		winner = "Player 1 Wins!"
	elif player2_health_percent > player1_health_percent:
		winner = "Player 2 Wins!"  # Fixed missing exclamation point
	else:
		winner = "Draw!"
	
	# Display result
	timer_label.text = "Time Up! " + winner
	
	# Show game over screen
	show_game_over(winner)  # Corrected variable name
	
func _on_player_defeated(player_number, _extra_param=null):
	var winner_text = "Player " + str(3 - player_number) + " Wins!"
	show_game_over(winner_text)

func show_game_over(winner_text):
	# Create a CanvasLayer to hold the game over screen
	var canvas_layer = CanvasLayer.new()
	add_child(canvas_layer)
	
	# Load the game over scene
	var game_over_scene = load("res://scenes/game_over_screen.tscn").instantiate()
	
	# Add it to the CanvasLayer
	canvas_layer.add_child(game_over_scene)
	
	# Now call the set_winner method if it exists
	if game_over_scene.has_method("set_winner"):
		game_over_scene.set_winner(winner_text)
	
	# Optional: remove the current scene
	# get_tree().current_scene.queue_free()
