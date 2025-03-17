extends Control

# Path to the battle arena scene
@export var battle_arena_path = "res://scenes/battle_arena.tscn"

# UI References
var player1_panel
var player2_panel
var player1_portrait
var player2_portrait
var player1_info
var player2_info
var player1_name_label
var player2_name_label
var battle_button
var player1_left_button
var player1_right_button
var player1_confirm_button
var player2_left_button
var player2_right_button
var player2_confirm_button

# Character selection tracking
var player1_selection = 0
var player2_selection = 1  # Default to different selection
var character_list = []

# Ready state tracking
var player1_ready = false
var player2_ready = false

# Character data
var character_portraits = {}

func _ready():
	# Create the UI layout
	setup_ui()
	
	# Load character data
	load_characters()
	
	# Initialize character displays
	update_character_display(1)
	update_character_display(2)

func setup_ui():
	# Main container
	var main_container = VBoxContainer.new()
	main_container.name = "MainContainer"
	main_container.anchor_right = 1.0
	main_container.anchor_bottom = 1.0
	main_container.size_flags_horizontal = Control.SIZE_FILL | Control.SIZE_EXPAND
	main_container.size_flags_vertical = Control.SIZE_FILL | Control.SIZE_EXPAND
	add_child(main_container)
	
	# Title
	var title = Label.new()
	title.text = "CHARACTER SELECT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.custom_minimum_size = Vector2(0, 100)  # Use Vector2 for minimum size
	main_container.add_child(title)
	
	# Player container (horizontal)
	var player_container = HBoxContainer.new()
	player_container.name = "PlayerContainer"
	player_container.size_flags_horizontal = Control.SIZE_FILL | Control.SIZE_EXPAND
	player_container.size_flags_vertical = Control.SIZE_FILL | Control.SIZE_EXPAND
	main_container.add_child(player_container)
	
	# Player 1 panel
	player1_panel = Panel.new()
	player1_panel.name = "Player1Panel"
	player1_panel.size_flags_horizontal = Control.SIZE_FILL | Control.SIZE_EXPAND
	player1_panel.size_flags_vertical = Control.SIZE_FILL | Control.SIZE_EXPAND
	player_container.add_child(player1_panel)
	
	# Player 2 panel
	player2_panel = Panel.new()
	player2_panel.name = "Player2Panel"
	player2_panel.size_flags_horizontal = Control.SIZE_FILL | Control.SIZE_EXPAND
	player2_panel.size_flags_vertical = Control.SIZE_FILL | Control.SIZE_EXPAND
	player_container.add_child(player2_panel)
	
	# Setup player panels
	setup_player_panel(player1_panel, 1)
	setup_player_panel(player2_panel, 2)
	
	# Battle button
	battle_button = Button.new()
	battle_button.name = "BattleButton"
	battle_button.text = "START BATTLE"
	battle_button.disabled = true  # Disabled until both players are ready
	battle_button.custom_minimum_size = Vector2(0, 60)  # Use Vector2 for minimum size
	battle_button.pressed.connect(_on_battle_button_pressed)
	main_container.add_child(battle_button)
	
	# Instructions
	var instructions = Label.new()
	instructions.text = "Player 1: Use A/D or ←/→ to select, Space to confirm\nPlayer 2: Use J/L or gamepad ←/→ to select, Enter to confirm"
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.custom_minimum_size = Vector2(0, 50)  # Use Vector2 for minimum size
	main_container.add_child(instructions)

func setup_player_panel(panel, player_num):
	# Create layout container
	var layout = VBoxContainer.new()
	layout.anchor_right = 1.0
	layout.anchor_bottom = 1.0
	layout.size_flags_horizontal = Control.SIZE_FILL | Control.SIZE_EXPAND
	layout.size_flags_vertical = Control.SIZE_FILL | Control.SIZE_EXPAND
	panel.add_child(layout)
	
	# Player label
	var player_label = Label.new()
	player_label.text = "PLAYER " + str(player_num)
	player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_label.add_theme_font_size_override("font_size", 32)
	layout.add_child(player_label)
	
	# Character name
	var name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 24)
	layout.add_child(name_label)
	
	# Store reference to name label
	if player_num == 1:
		player1_name_label = name_label
	else:
		player2_name_label = name_label
	
	# Portrait container
	var portrait_container = CenterContainer.new()
	portrait_container.name = "PortraitContainer"
	portrait_container.size_flags_vertical = Control.SIZE_FILL | Control.SIZE_EXPAND
	layout.add_child(portrait_container)
	
	# Character portrait
	var portrait = TextureRect.new()
	portrait.name = "Portrait"
	portrait.custom_minimum_size = Vector2(200, 200)
	# Use direct enum value instead of the constant
	portrait.expand_mode = 2  # 2 = Keep aspect centered in Godot 4
	portrait_container.add_child(portrait)
	
	# Store reference to portrait
	if player_num == 1:
		player1_portrait = portrait
	else:
		player2_portrait = portrait
	
	# Character info panel
	var info_panel = VBoxContainer.new()
	info_panel.name = "InfoPanel"
	info_panel.custom_minimum_size = Vector2(0, 150)
	layout.add_child(info_panel)
	
	# Store reference to info panel
	if player_num == 1:
		player1_info = info_panel
	else:
		player2_info = info_panel
	
	# Navigation buttons
	var nav_buttons = HBoxContainer.new()
	nav_buttons.name = "NavButtons"
	nav_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_child(nav_buttons)
	
	# Left button
	var left_button = Button.new()
	left_button.name = "LeftButton"
	left_button.text = "◄"
	left_button.custom_minimum_size = Vector2(50, 40)
	nav_buttons.add_child(left_button)
	
	# Right button
	var right_button = Button.new()
	right_button.name = "RightButton"
	right_button.text = "►"
	right_button.custom_minimum_size = Vector2(50, 40)
	nav_buttons.add_child(right_button)
	
	# Store button references
	if player_num == 1:
		player1_left_button = left_button
		player1_right_button = right_button
	else:
		player2_left_button = left_button
		player2_right_button = right_button
	
	# Confirm button
	var confirm_button = Button.new()
	confirm_button.name = "ConfirmButton"
	confirm_button.text = "CONFIRM"
	confirm_button.custom_minimum_size = Vector2(100, 40)
	layout.add_child(confirm_button)
	
	# Store confirm button reference
	if player_num == 1:
		player1_confirm_button = confirm_button
	else:
		player2_confirm_button = confirm_button
	
	# Connect signals - Define these functions before connecting
	left_button.pressed.connect(func(): _on_left_button_pressed(player_num))
	right_button.pressed.connect(func(): _on_right_button_pressed(player_num))
	confirm_button.pressed.connect(func(): _on_confirm_button_pressed(player_num))

func load_characters():
	# Get characters from the registry
	character_list = CharacterClasses.classes.keys()
	
	# For testing or placeholder visuals, create colored rectangles
	for character_id in character_list:
		var placeholder = ColorRect.new()
		placeholder.custom_minimum_size = Vector2(200, 200)
		
		# Assign different colors based on character
		match character_id:
			"knight":
				placeholder.color = Color(0.7, 0.3, 0.3)  # Red for Knight
			"wizard":
				placeholder.color = Color(0.3, 0.3, 0.7)  # Blue for Wizard
			_:
				placeholder.color = Color(0.5, 0.5, 0.5)  # Gray default
		
		character_portraits[character_id] = placeholder

func update_character_display(player_num):
	# Get the correct references based on player number
	var name_label = player1_name_label if player_num == 1 else player2_name_label
	var selection = player1_selection if player_num == 1 else player2_selection
	var info_panel = player1_info if player_num == 1 else player2_info
	var portrait_holder = player1_portrait if player_num == 1 else player2_portrait
	
	# Validate character list isn't empty
	if character_list.size() == 0:
		print("Error: No characters loaded")
		return
	
	# Make sure selection is valid
	if selection >= character_list.size():
		selection = 0
	
	# Get character ID and data
	var character_id = character_list[selection]
	var character_data = CharacterClasses.get_character_class(character_id)
	
	# Update name label
	if name_label:
		name_label.text = character_data.name.capitalize()
	else:
		print("Warning: Name label not found for player " + str(player_num))
	
	# Update portrait
	if portrait_holder:
		# Remove existing portrait content
		for child in portrait_holder.get_children():
			child.queue_free()
		
		if character_portraits.has(character_id):
			var portrait_visual = character_portraits[character_id].duplicate()
			portrait_holder.add_child(portrait_visual)
	else:
		print("Warning: Portrait holder not found for player " + str(player_num))
	
	# Update info panel
	if info_panel:
		# Clear existing stats
		for child in info_panel.get_children():
			child.queue_free()
		
		# Add stats
		add_stat_row(info_panel, "Strength", character_data.strength)
		add_stat_row(info_panel, "Intelligence", character_data.intelligence)
		add_stat_row(info_panel, "Agility", character_data.agility)
		add_stat_row(info_panel, "Vitality", character_data.vitality)
		
		# Add weapon info with affinity visualization
		var weapon_container = VBoxContainer.new()
		info_panel.add_child(weapon_container)

		# Weapon label
		var weapon_label = Label.new()
		weapon_label.text = "Default Weapon: " + character_data.default_weapon.capitalize()
		weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		weapon_container.add_child(weapon_label)

		# Add weapon affinity indicators for primary weapons
		var affinity_container = HBoxContainer.new()
		affinity_container.alignment = BoxContainer.ALIGNMENT_CENTER
		weapon_container.add_child(affinity_container)

		# Sword affinity
		add_weapon_affinity(affinity_container, "Sword", character_data.sword_affinity)

		# Staff affinity
		add_weapon_affinity(affinity_container, "Staff", character_data.staff_affinity)

		# Add a hint about best weapon
		var hint_label = Label.new()
		var best_weapon = "sword" if character_data.sword_affinity > character_data.staff_affinity else "staff"
		hint_label.text = "Best with: " + best_weapon.capitalize()
		hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint_label.modulate = Color(1.0, 0.8, 0.2) # Gold color for emphasis
		weapon_container.add_child(hint_label)
	else:
		print("Warning: Info panel not found for player " + str(player_num))

func add_stat_row(container, stat_name, value):
	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_FILL | Control.SIZE_EXPAND
	container.add_child(row)
	
	var label = Label.new()
	label.text = stat_name + ":"
	label.custom_minimum_size = Vector2(100, 0)
	row.add_child(label)
	
	var bar_bg = ColorRect.new()
	bar_bg.color = Color(0.2, 0.2, 0.2)
	bar_bg.custom_minimum_size = Vector2(150, 15)
	row.add_child(bar_bg)
	
	var bar_fill = ColorRect.new()
	bar_fill.color = Color(0.3, 0.7, 0.3)
	bar_fill.custom_minimum_size = Vector2(0, 15)
	bar_fill.size.x = clamp(value * 10, 0, 150)  # Scale to fit
	bar_bg.add_child(bar_fill)
	
	var value_label = Label.new()
	value_label.text = str(value)
	row.add_child(value_label)

# New helper function for weapon affinity display
func add_weapon_affinity(container, weapon_name, affinity_value):
	var weapon_affinity = VBoxContainer.new()
	weapon_affinity.size_flags_horizontal = Control.SIZE_FILL | Control.SIZE_EXPAND
	container.add_child(weapon_affinity)
	
	# Weapon name
	var name_label = Label.new()
	name_label.text = weapon_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weapon_affinity.add_child(name_label)
	
	# Affinity bar background
	var bar_bg = ColorRect.new()
	bar_bg.color = Color(0.2, 0.2, 0.2)
	bar_bg.custom_minimum_size = Vector2(60, 15)
	weapon_affinity.add_child(bar_bg)
	
	# Affinity bar fill
	var bar_fill = ColorRect.new()
	# Calculate color: green for high affinity, red for low
	var color_value = clamp(affinity_value, 0.0, 1.5) / 1.5
	bar_fill.color = Color(1.0 - color_value, color_value, 0.2)
	bar_fill.custom_minimum_size = Vector2(0, 15)
	
	# Scale the bar width based on affinity (1.0 = 60 pixels, max of 90 for 1.5 affinity)
	bar_fill.size.x = clamp(affinity_value * 40, 0, 60)
	bar_bg.add_child(bar_fill)
	
	# Affinity value
	var value_label = Label.new()
	value_label.text = str(affinity_value) + "x"
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weapon_affinity.add_child(value_label)

func _process(delta):
	# Handle keyboard/controller input
	if !player1_ready:
		if Input.is_action_just_pressed("ui_left"):
			_on_left_button_pressed(1)
		elif Input.is_action_just_pressed("ui_right"):
			_on_right_button_pressed(1)
		elif Input.is_action_just_pressed("ui_accept"):
			_on_confirm_button_pressed(1)
	
	if !player2_ready:
		if Input.is_action_just_pressed("p2_left"):
			_on_left_button_pressed(2)
		elif Input.is_action_just_pressed("p2_right"):
			_on_right_button_pressed(2)
		elif Input.is_action_just_pressed("p2_accept"):
			_on_confirm_button_pressed(2)
	
	# Start battle if both ready and battle button pressed
	if player1_ready and player2_ready:
		if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("p2_accept"):
			_on_battle_button_pressed()

func _on_left_button_pressed(player_num):
	if player_num == 1 and !player1_ready:
		player1_selection = (player1_selection - 1) % character_list.size()
		if player1_selection < 0:
			player1_selection = character_list.size() - 1
		update_character_display(1)
	elif player_num == 2 and !player2_ready:
		player2_selection = (player2_selection - 1) % character_list.size()
		if player2_selection < 0:
			player2_selection = character_list.size() - 1
		update_character_display(2)

func _on_right_button_pressed(player_num):
	if player_num == 1 and !player1_ready:
		player1_selection = (player1_selection + 1) % character_list.size()
		update_character_display(1)
	elif player_num == 2 and !player2_ready:
		player2_selection = (player2_selection + 1) % character_list.size()
		update_character_display(2)

func _on_confirm_button_pressed(player_num):
	if player_num == 1:
		player1_ready = true
		var ready_label = Label.new()
		ready_label.text = "READY!"
		ready_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ready_label.add_theme_font_size_override("font_size", 32)
		ready_label.modulate = Color(0.2, 1.0, 0.2)  # Green
		player1_panel.add_child(ready_label)
		
		# Disable navigation buttons using direct references
		if player1_left_button:
			player1_left_button.disabled = true
		
		if player1_right_button:
			player1_right_button.disabled = true
		
		if player1_confirm_button:
			player1_confirm_button.disabled = true
		
		# If player 2 is also ready, enable battle button
		if player2_ready and battle_button:
			battle_button.disabled = false
			# Only try to focus if the button exists and is enabled
			if battle_button and !battle_button.disabled:
				battle_button.grab_focus()
		else:
			# Focus on player 2's right button if it exists
			if player2_right_button and !player2_right_button.disabled:
				player2_right_button.grab_focus()
	
	elif player_num == 2:
		player2_ready = true
		var ready_label = Label.new()
		ready_label.text = "READY!"
		ready_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ready_label.add_theme_font_size_override("font_size", 32)
		ready_label.modulate = Color(0.2, 1.0, 0.2)  # Green
		player2_panel.add_child(ready_label)
		
		# Disable navigation buttons using direct references
		if player2_left_button:
			player2_left_button.disabled = true
		
		if player2_right_button:
			player2_right_button.disabled = true
		
		if player2_confirm_button:
			player2_confirm_button.disabled = true
		
		# If player 1 is also ready, enable battle button
		if player1_ready and battle_button:
			battle_button.disabled = false
			# Only try to focus if the button exists and is enabled
			if battle_button and !battle_button.disabled:
				battle_button.grab_focus()
		else:
			# Focus on player 1's right button if it exists
			if player1_right_button and !player1_right_button.disabled:
				player1_right_button.grab_focus()

func _on_battle_button_pressed():
	# Make sure we have characters to select
	if character_list.size() == 0:
		print("Error: No characters loaded")
		return
		
	# Get selected character classes
	var p1_class_id = character_list[player1_selection]
	var p2_class_id = character_list[player2_selection]
	
	print("Starting battle: Player 1 as " + p1_class_id + " vs Player 2 as " + p2_class_id)
	
	# Store the selections in GameManager
	GameManager.player1_character = p1_class_id
	GameManager.player2_character = p2_class_id
	
	# Change to the battle scene
	get_tree().change_scene_to_file(battle_arena_path)
