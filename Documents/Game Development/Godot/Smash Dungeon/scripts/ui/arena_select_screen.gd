# arena_select_screen.gd
# Script attached to the root Control node of arena_select_screen.tscn
extends Control

# References to essential UI elements (ensure paths match your scene tree)
@onready var arena_list_container = $MarginContainer/MainLayout/ArenaScrollContainer/ArenaListContainer
@onready var start_battle_button = $MarginContainer/MainLayout/StartBattleButton

# State variables
var currently_selected_arena_id: String = ""
var arena_button_nodes: Array[Button] = [] # To store references to created buttons

#-----------------------------------------------------------------------------
# Initialization
#-----------------------------------------------------------------------------

func _ready():
	# Ensure start button is disabled and not focusable initially
	if not start_battle_button:
		printerr("Arena Select Error: StartBattleButton node not found! Check @onready path.")
		return
	start_battle_button.focus_mode = Control.FOCUS_NONE
	start_battle_button.disabled = true

	# Connect the start button's signal AFTER ensuring it exists
	start_battle_button.pressed.connect(_on_start_battle_button_pressed)

	# Populate the list of arenas (this will also set up initial focus)
	populate_arena_list()

	# Set initial focus AFTER buttons and neighbors are configured by populate_arena_list
	if arena_button_nodes.size() > 0:
		arena_button_nodes[0].grab_focus()
		print("Arena Select: Initial focus set on first arena button.")
	else:
		# If no arenas, nothing is focusable initially
		print("Arena Select: No arenas available to focus.")

#-----------------------------------------------------------------------------
# Populating the UI
#-----------------------------------------------------------------------------

func populate_arena_list():
	# Ensure containers exist before proceeding
	if not arena_list_container:
		printerr("Arena Select Error: ArenaListContainer node not found! Check @onready path.")
		return

	# Clear previous buttons AND the node array
	for child in arena_list_container.get_children():
		child.queue_free()
	arena_button_nodes.clear()

	# Check if ArenaDatabase exists
	if ArenaDatabase == null:
		printerr("Arena Select Error: ArenaDatabase singleton not found!")
		# Optionally display an error message to the player here
		# e.g., add_child(Label.new()).text = "Error: Cannot load arenas!"
		return

	# Get available arenas
	var available_ids = ArenaDatabase.get_all_arena_ids()
	# Example using multiplayer filter:
	# var available_ids = ArenaDatabase.get_multiplayer_arenas()

	if available_ids.is_empty():
		print("Arena Select: No arenas found in database.")
		# Optionally display a message like "No Arenas Available"
		# e.g., add_child(Label.new()).text = "No arenas available."
		return

	print("Arena Select: Populating list with IDs: ", available_ids)

	# Create a button for each arena ID
	for arena_id in available_ids:
		var arena_data = ArenaDatabase.get_arena(arena_id)
		if arena_data: # Check if data was retrieved successfully
			var button = Button.new()
			button.text = arena_data.name if arena_data.name else arena_id # Use name, fallback to ID
			button.custom_minimum_size = Vector2(0, 30) # Give buttons some height
			button.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_FILL
			button.focus_mode = Control.FOCUS_ALL # Ensure list buttons are focusable
			# Connect the button's pressed signal. Pass the arena_id using bind.
			button.pressed.connect(_on_arena_button_pressed.bind(arena_id))
			arena_list_container.add_child(button)
			arena_button_nodes.append(button) # Store button reference
		else:
			printerr("Arena Select Error: Could not get data for arena ID: ", arena_id)

	# --- Setup Initial Focus Neighbors (List Wrap ONLY) ---
	# Run this AFTER all buttons have been added
	setup_focus_neighbors_list_only()


#-----------------------------------------------------------------------------
# Focus Management
#-----------------------------------------------------------------------------

func setup_focus_neighbors_list_only():
	# --- Links buttons ONLY within the list initially ---
	var button_count = arena_button_nodes.size()
	if button_count == 0: return

	print("Arena Select: Setting up initial list-only focus neighbors for ", button_count, " buttons.")
	for i in range(button_count):
		var current_button = arena_button_nodes[i]
		if not is_instance_valid(current_button): continue # Safety check

		# Get paths safely
		var top_neighbor_path = arena_button_nodes[ (i - 1 + button_count) % button_count ].get_path()
		var bottom_neighbor_path = arena_button_nodes[ (i + 1) % button_count ].get_path()

		current_button.focus_neighbor_top = top_neighbor_path
		current_button.focus_neighbor_bottom = bottom_neighbor_path
		# Clear horizontal neighbors unless you have a grid layout
		current_button.focus_neighbor_left = NodePath()
		current_button.focus_neighbor_right = NodePath()

	# --- Ensure Start Button is unlinked initially ---
	# It should already be FOCUS_NONE from _ready
	if is_instance_valid(start_battle_button):
		start_battle_button.focus_neighbor_top = NodePath()
		start_battle_button.focus_neighbor_bottom = NodePath()
	print("Arena Select: Initial focus neighbors configured (List Wrap Only).")


func link_list_and_start_button_neighbors():
	# --- Updates neighbors to link the list bottom and the start button ---
	var button_count = arena_button_nodes.size()
	# Ensure both the list buttons AND the start button are valid
	if button_count == 0 or not is_instance_valid(start_battle_button):
		print("Arena Select: Cannot link neighbors - list empty or start button invalid.")
		return

	# Ensure start button is actually focusable now
	if start_battle_button.focus_mode == Control.FOCUS_NONE:
		print("Arena Select Warning: Trying to link neighbors to non-focusable start button.")
		start_battle_button.focus_mode = Control.FOCUS_ALL # Force it just in case

	var first_button = arena_button_nodes[0]
	var last_button = arena_button_nodes[button_count - 1]

	# Validate button instances before getting paths
	if not is_instance_valid(first_button) or not is_instance_valid(last_button):
		printerr("Arena Select Error: Invalid button node found while linking neighbors.")
		return

	print("Arena Select: Linking List & Start Button neighbors...")

	# --- Link Last Button DOWN -> Start Button ---
	last_button.focus_neighbor_bottom = start_battle_button.get_path()
	print("  - Set ", last_button.name, "(",last_button.text,") neighbor_bottom to StartButton")


	# --- Link Start Button UP -> Last Button ---
	start_battle_button.focus_neighbor_top = last_button.get_path()
	print("  - Set StartButton neighbor_top to ", last_button.name, "(",last_button.text,")")

	# --- Link First Button UP -> Start Button (Wrap around) ---
	first_button.focus_neighbor_top = start_battle_button.get_path()
	print("  - Set ", first_button.name,"(",first_button.text,") neighbor_top to StartButton")


	# --- Link Start Button DOWN -> First Button (Wrap around) ---
	start_battle_button.focus_neighbor_bottom = first_button.get_path()
	print("  - Set StartButton neighbor_bottom to ", first_button.name,"(",first_button.text,")")

	print("Arena Select: Focus neighbors updated successfully.")


#-----------------------------------------------------------------------------
# Signal Handlers
#-----------------------------------------------------------------------------

func _on_arena_button_pressed(selected_id: String):
	# Validate the selected ID exists
	if not ArenaDatabase or not ArenaDatabase.arenas.has(selected_id):
		printerr("Arena Select Error: _on_arena_button_pressed called with invalid ID: ", selected_id)
		return

	currently_selected_arena_id = selected_id
	print("Arena Select: Player selected arena ID: '", currently_selected_arena_id, "'")

	# Enable Start Button and make it focusable
	if is_instance_valid(start_battle_button):
		start_battle_button.disabled = false
		start_battle_button.focus_mode = Control.FOCUS_ALL
		print("Arena Select: Start Battle button enabled and focusable.")

		# UPDATE Neighbors to include Start Button
		link_list_and_start_button_neighbors()

		# DO NOT grab focus here - let player navigate down or press accept again
	else:
		printerr("Arena Select Error: start_battle_button is invalid!")


	# Visual feedback loop - highlight selected button
	var arena_name_to_match = ArenaDatabase.get_arena(selected_id).name
	for button in arena_button_nodes:
		if is_instance_valid(button):
			# Use text match, assuming names are unique for now
			if button.text == arena_name_to_match:
				button.modulate = Color(0.8, 1.0, 0.8) # Highlight green-ish
			else:
				button.modulate = Color(1.0, 1.0, 1.0) # Reset to normal


func _on_start_battle_button_pressed():
	if currently_selected_arena_id.is_empty():
		print("Arena Select Warning: Start button pressed but no arena selected!")
		# Optionally re-focus first list button?
		if arena_button_nodes.size() > 0 and is_instance_valid(arena_button_nodes[0]):
			arena_button_nodes[0].grab_focus()
		return

	print("Arena Select: Start Battle confirmed for arena ID: '", currently_selected_arena_id, "'")

	# Store the final selection in GameManager
	if GameManager != null:
		GameManager.selected_arena_id = currently_selected_arena_id
		# Call GameManager to handle the rest of the process
		print("Arena Select: Calling GameManager.start_battle()")
		GameManager.start_battle()
	else:
		printerr("Arena Select Error: GameManager singleton not found! Cannot start battle.")


#-----------------------------------------------------------------------------
# Optional Input Handling (If needed beyond button signals)
#-----------------------------------------------------------------------------
# func _input(event):
	# Handle additional inputs if necessary, e.g., "back" button
	# if event.is_action_pressed("ui_cancel"):
		# get_tree().change_scene_to_file("res://scenes/character_select.tscn") # Example back navigation
