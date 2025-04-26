# state_machines/state_machine.gd
class_name StateMachine
extends Node

# Reference to the parent object (the enemy)
var enemy = null

# The current active state
var current_state = null
var current_state_name = ""

# Dictionary to store states by name
var states = {}

# Debug mode
@export var debug_mode: bool = false

func _ready():
	# Get reference to the parent
	enemy = get_parent()
	
	# Register all child states
	for child in get_children():
		if child is State:
			# Set up references
			child.state_machine = self
			child.enemy = enemy
			
			# Add to states dictionary
			states[child.name] = child
			
	# Set initial state if states exist
	if not states.is_empty():
		var initial_state = states.values()[0]
		change_state(initial_state.name)

func _process(delta):
	if current_state:
		current_state.process(delta)

func _physics_process(delta):
	if current_state:
		current_state.physics_process(delta)

# Change to a new state by name
func change_state(new_state_name):
	print("Changing state from " + (current_state_name if current_state else "None") + " to " + new_state_name)
	if not states.has(new_state_name):
		push_error("State '%s' not found in state machine" % new_state_name)
		return false
	
	if debug_mode:
		print("%s: Changing state from %s to %s" % [enemy.name, current_state_name, new_state_name])
	
	# Exit current state
	if current_state:
		current_state.exit()
	
	# Update current state
	current_state_name = new_state_name
	current_state = states[new_state_name]
	
	# Enter new state
	current_state.enter()
	
	return true

# Send a message to the current state
func send_message(msg, data=null):
	if current_state:
		current_state.handle_message(msg, data)
