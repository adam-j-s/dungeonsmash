# battle_arena.gd
extends Node2D

# Timer settings
@export var match_duration = 60  # Seconds for the match
var time_remaining = 60  # Initialize with default value
var timer_label = null
var match_timer = null  # Timer variable

# Arena system references
@onready var tilemap: TileMap = $Terrain  # Reference to your TileMap

# Ready Function
func _ready():
	# Initialize timer value
	time_remaining = match_duration

	# --- PLAYER NODE SETUP ---
	var player1 = $Player1 # Assume Player1 always exists
	var player2 = get_node_or_null("Player2") # Find Player 2 if it exists

	# Configure Player 1 Character Class
	if player1 and GameManager.player1_character:
		player1.character_class_id = GameManager.player1_character
		print("Player 1 using character: " + GameManager.player1_character)
	elif not player1:
		print("CRITICAL ERROR: Player1 node not found in battle_arena scene!")

	# Setup Player 2 Node or Configure Class
	if GameManager.testing_vs_ai:
		if player2 != null:
			print("Removing existing Player2 node for AI mode.")
			player2.queue_free()
			player2 = null
	elif player2 != null: # PvP mode
		# Configure Player 2 Class
		if GameManager.player2_character:
			player2.character_class_id = GameManager.player2_character
			print("Player 2 using character: " + GameManager.player2_character)
		else:
			print("WARNING: No character selected for Player 2 in GameManager.")
	elif not GameManager.testing_vs_ai: # PvP mode but node missing
		print("WARNING: Player2 node MISSING from battle_arena scene for PvP!")

	# Load arena data (Tilemap, Background, Spawns)
	load_arena_data()

	# --- Spawn AI if needed ---
	if GameManager.testing_vs_ai:
		# Get the intended spawn position for AI
		var ai_spawn_pos = Vector2(300, 300) # Default fallback
		if ArenaDatabase != null and ArenaDatabase.current_arena_data != null:
			var spawn_positions = ArenaDatabase.current_arena_data.player_spawn_positions
			if spawn_positions.size() >= 2:
				ai_spawn_pos = spawn_positions[1]
		setup_ai_opponent(ai_spawn_pos)

	# Create timer UI
	create_timer_ui()

	# Setup cooldown UI
	setup_cooldown_ui()

	# Start the countdown timer
	match_timer = Timer.new()
	match_timer.wait_time = 1.0
	match_timer.autostart = true
	match_timer.timeout.connect(_on_timer_tick)
	add_child(match_timer)

	# Connect player defeat signals
	if player1:
		if player1.has_signal("player_defeated"):
			player1.player_defeated.connect(_on_player_defeated.bind(1))
		else:
			print("WARNING: Player1 node is missing 'player_defeated' signal.")

	# Connect player2 defeat signal if in PvP mode
	if player2 and not GameManager.testing_vs_ai:
		if player2.has_signal("player_defeated"):
			player2.player_defeated.connect(_on_player_defeated.bind(2))
		else:
			print("WARNING: Player2 node is missing 'player_defeated' signal.")

	# Connect AI defeat signal
	var ai_opponent = get_node_or_null("AI_Opponent")
	if is_instance_valid(ai_opponent):
		if ai_opponent.has_signal("defeated"):
			ai_opponent.defeated.connect(_on_player_defeated.bind(2))
		else:
			print("WARNING: AI_Opponent instance does not have 'defeated' signal.")

# Modified setup_ai_opponent to accept any enemy type
func setup_ai_opponent(spawn_pos: Vector2):
	# Get the enemy type from GameManager if available, or use default
	var enemy_type = "clinger"  # Default to clinger for testing
	if "enemy_type" in GameManager:
		enemy_type = GameManager.enemy_type
	
	# Spawn the enemy
	var enemy = EnemyManager.spawn_enemy(enemy_type, spawn_pos, self)
	
	if not is_instance_valid(enemy):
		print("CRITICAL ERROR: Failed to spawn AI opponent instance!")
		return
	
	# Try to find a matching config if one exists, based on enemy type
	var config_path = "res://resources/enemies/configs/" + enemy_type + "_config.tres"
	if ResourceLoader.exists(config_path):
		var config_res = load(config_path)
		if config_res and config_res.has_method("apply_to_enemy"):
			config_res.apply_to_enemy(enemy)
	
	# Rename and setup enemy
	enemy.name = "AI_Opponent"
	
	# Set player as the target
	var player1 = get_node_or_null("Player1")
	if player1:
		enemy.set_target(player1)

# Function to load arena data from ArenaDatabase
func load_arena_data():
	if ArenaDatabase != null and ArenaDatabase.current_arena_data != null:
		print("Loading arena: " + ArenaDatabase.current_arena_data.name)

		# Apply the arena data to the tilemap
		if tilemap != null:
			ArenaDatabase.current_arena_data.apply_to_tilemap(tilemap)
		else:
			print("WARNING: TileMap node ($Terrain) not found!")

		# Apply player spawn positions if available
		var spawn_positions = ArenaDatabase.current_arena_data.player_spawn_positions
		if spawn_positions.size() >= 2:
			# Position player 1
			var player1_node = get_node_or_null("Player1")
			if player1_node != null:
				player1_node.global_position = spawn_positions[0]
			else:
				print("WARNING: Player1 node not found when trying to set position.")

			# Position Player 2 (but NOT AI)
			if not GameManager.testing_vs_ai:
				var player2_node = get_node_or_null("Player2")
				if player2_node:
					player2_node.global_position = spawn_positions[1]
		else:
			print("WARNING: Not enough spawn positions defined in ArenaData.")

		# Set background if applicable
		var background_node = get_node_or_null("Background")
		if background_node != null and !ArenaDatabase.current_arena_data.background_path.is_empty():
			var background_texture = load(ArenaDatabase.current_arena_data.background_path)
			if background_texture:
				if background_node.has_method("set_texture"):
					background_node.set_texture(background_texture)
				elif "texture" in background_node:
					background_node.texture = background_texture
			else:
				print("WARNING: Failed to load background texture.")
		elif background_node == null:
			print("WARNING: Background node not found in battle_arena scene.")
	else:
		print("No arena data available - using default layout defined in battle_arena.tscn")

func _process(delta):
	# Update cooldown UI
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
	timer_label.size = Vector2(100, 30)
	timer_label.add_theme_font_size_override("font_size", 24)
	ui_layer.add_child(timer_label)

	# Initial update
	update_timer_display()

# Setup cooldown UI for both players
func setup_cooldown_ui():
	# Setup Player 1 cooldown bar
	var player1_node = get_node_or_null("Player1")
	if player1_node:
		var p1_bar_node = player1_node.get_node_or_null("CooldownBar")
		if not is_instance_valid(p1_bar_node):
			p1_bar_node = ProgressBar.new()
			p1_bar_node.name = "CooldownBar"
			p1_bar_node.min_value = 0
			p1_bar_node.max_value = 1
			p1_bar_node.value = 0
			p1_bar_node.size = Vector2(100, 8)
			p1_bar_node.position = Vector2(-50, -20)  # Above the player
			p1_bar_node.modulate = Color(1, 0.7, 0, 0.8)  # Golden yellow
			player1_node.add_child(p1_bar_node)

	# Setup Player 2 cooldown bar (only in PvP mode)
	if not GameManager.testing_vs_ai:
		var player2_node = get_node_or_null("Player2")
		if player2_node:
			var p2_bar_node = player2_node.get_node_or_null("CooldownBar")
			if not is_instance_valid(p2_bar_node):
				p2_bar_node = ProgressBar.new()
				p2_bar_node.name = "CooldownBar"
				p2_bar_node.min_value = 0
				p2_bar_node.max_value = 1
				p2_bar_node.value = 0
				p2_bar_node.size = Vector2(100, 8)
				p2_bar_node.position = Vector2(-50, -20)  # Above the player
				p2_bar_node.modulate = Color(1, 0.7, 0, 0.8)  # Golden yellow
				player2_node.add_child(p2_bar_node)

# Update cooldown UI for players
func update_cooldown_ui():
	# Update Player 1 cooldown bar
	var player1_node = get_node_or_null("Player1")
	if player1_node:
		var p1_weapon_node = player1_node.get_node_or_null("Weapon")
		var p1_bar_node = player1_node.get_node_or_null("CooldownBar")
		if p1_weapon_node and p1_bar_node and p1_weapon_node.has_method("get_cooldown_progress"):
				var progress = p1_weapon_node.get_cooldown_progress()
				p1_bar_node.value = progress
				p1_bar_node.visible = progress < 1.0
		elif p1_bar_node:
			p1_bar_node.visible = false

	# Update Player 2 cooldown bar (only in PvP mode)
	if not GameManager.testing_vs_ai:
		var player2_node = get_node_or_null("Player2")
		if player2_node:
			var p2_weapon_node = player2_node.get_node_or_null("Weapon")
			var p2_bar_node = player2_node.get_node_or_null("CooldownBar")
			if p2_weapon_node and p2_bar_node and p2_weapon_node.has_method("get_cooldown_progress"):
					var progress = p2_weapon_node.get_cooldown_progress()
					p2_bar_node.value = progress
					p2_bar_node.visible = progress < 1.0
			elif p2_bar_node:
				p2_bar_node.visible = false

func _on_timer_tick():
	if time_remaining > 0:
		time_remaining -= 1
		update_timer_display()
	else:
		time_up()

func update_timer_display():
	# Safety check
	if timer_label == null: return
	if time_remaining == null:
		time_remaining = match_duration

	var minutes = time_remaining / 60
	var seconds = time_remaining % 60
	timer_label.text = "%d:%02d" % [minutes, seconds]

func time_up():
	# Stop the Timer
	if match_timer != null:
		match_timer.stop()

	# Determine winner based on remaining health
	var player1_health_percent = 0.0
	var player2_health_percent = 0.0
	var player1_found = false
	var player2_found = false

	var player1_node = get_node_or_null("Player1")
	if player1_node:
		player1_found = true
		if "health" in player1_node and "MAX_HEALTH" in player1_node and player1_node.MAX_HEALTH > 0:
			player1_health_percent = float(player1_node.health) / player1_node.MAX_HEALTH

	var player2_or_ai = null
	if GameManager.testing_vs_ai:
		player2_or_ai = get_node_or_null("AI_Opponent")
	else:
		player2_or_ai = get_node_or_null("Player2")

	if player2_or_ai:
		player2_found = true
		# Try 'health' and 'max_health' first (like WispEnemy)
		if "health" in player2_or_ai and "max_health" in player2_or_ai and player2_or_ai.max_health > 0:
			player2_health_percent = float(player2_or_ai.health) / player2_or_ai.max_health
		# Fallback to player properties
		elif "health" in player2_or_ai and "MAX_HEALTH" in player2_or_ai and player2_or_ai.MAX_HEALTH > 0:
			player2_health_percent = float(player2_or_ai.health) / player2_or_ai.MAX_HEALTH

	# Determine winner
	var winner = ""
	var winner_num = 0
	if player1_found and player2_found:
		if player1_health_percent > player2_health_percent:
			winner = "Player 1 Wins!"
			winner_num = 1
		elif player2_health_percent > player1_health_percent:
			if GameManager.testing_vs_ai:
				winner = "AI Wins!"
			else:
				winner = "Player 2 Wins!"
			winner_num = 2
		else:
			winner = "Draw!"
			winner_num = 0
	elif player1_found: # Only P1 exists
		winner = "Player 1 Wins!"
		winner_num = 1
	elif player2_found: # Only P2/AI exists
		if GameManager.testing_vs_ai:
			winner = "AI Wins!"
		else:
			winner = "Player 2 Wins!"
		winner_num = 2
	else: # Neither found?
		winner = "Game Over!"
		winner_num = 0

	# Update the GameManager with the result
	GameManager.winner = winner_num

	# Display result on timer label
	if timer_label != null:
		timer_label.text = "Time Up! " + winner

	# Show game over screen
	show_game_over(winner)

func _on_player_defeated(defeated_player_number):
	# Stop timer
	if match_timer: match_timer.stop()

	var winner_text = ""
	var winner_num = 0

	# If Player 1 was defeated
	if defeated_player_number == 1:
		if GameManager.testing_vs_ai:
			winner_text = "AI Wins!"
		else:
			winner_text = "Player 2 Wins!"
		winner_num = 2
	# If Player 2 (or AI) was defeated
	elif defeated_player_number == 2:
		winner_text = "Player 1 Wins!"
		winner_num = 1
	else:
		winner_text = "Game Over"
		winner_num = 0

	# Update GameManager
	GameManager.winner = winner_num

	show_game_over(winner_text)

func show_game_over(winner_text):
	# Avoid creating multiple game over screens
	if get_node_or_null("GameOverLayer"):
		return

	# Create a CanvasLayer to hold the game over screen
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "GameOverLayer"
	add_child(canvas_layer)

	# Load game over scene
	var game_over_scene_instance = null
	var scene_path = "res://scenes/game_over_screen.tscn"

	if ResourceLoader.exists(scene_path):
		var loaded_scene = load(scene_path)
		if loaded_scene:
			game_over_scene_instance = loaded_scene.instantiate()
	
	if game_over_scene_instance == null:
		var label = Label.new()
		label.text = "Game Over! " + winner_text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var screen_size = get_viewport_rect().size
		label.position = Vector2((screen_size.x - 300) / 2, (screen_size.y - 100) / 2)
		label.size = Vector2(300, 100)
		label.add_theme_font_size_override("font_size", 32)
		canvas_layer.add_child(label)
		return

	canvas_layer.add_child(game_over_scene_instance)

	if game_over_scene_instance.has_method("set_winner"):
		game_over_scene_instance.set_winner(winner_text)

func _input(event):
	# Only enable in debug builds
	if OS.is_debug_build():
		# Check for weapon spawn hotkeys
		if event is InputEventKey and event.pressed:
			var weapon_id = ""

			# Number keys 1-9 for different weapons
			match event.keycode:
				KEY_1: weapon_id = "wave_wand"
				KEY_2: weapon_id = "dagger"
				KEY_3: weapon_id = "singularity_bomb"
				KEY_4: weapon_id = "mini_cluster"
				KEY_5: weapon_id = "homing_cluster"
				KEY_6: weapon_id = "wave_wand"
				KEY_7: weapon_id = "homing_orb"
				KEY_8: weapon_id = "bouncing_blade"
				KEY_9: weapon_id = "explosive_bomb"

			# If a valid key was pressed, spawn that weapon
			if weapon_id != "":
				spawn_test_weapon(weapon_id)

func spawn_test_weapon(weapon_id):
	# Ensure the weapon pickup scene exists
	var pickup_path = "res://scenes/weapon_pickup.tscn"
	if not ResourceLoader.exists(pickup_path):
		return

	var pickup_scene = load(pickup_path)
	if not pickup_scene:
		return

	# Create weapon pickup instance
	var weapon_pickup = pickup_scene.instantiate()

	# Set the specific weapon ID
	if weapon_pickup.has_method("set_weapon_id"):
		weapon_pickup.set_weapon_id(weapon_id)
	else:
		weapon_pickup.queue_free()
		return

	# Position in center of screen
	weapon_pickup.global_position = get_viewport_rect().size / 2.0

	# Add to scene
	add_child(weapon_pickup)
