# state_machine.gd
extends Node
class_name StateMachine

signal state_changed(previous, new)

# Current active state
var current_state: State = null
var previous_state: State = null
var states = {}

# Owner reference for states to access
@onready var owner_entity = get_parent()

func _ready():
	# Register all child state nodes
	for child in get_children():
		if child is State:
			states[child.name] = child
			child.state_machine = self
	
	# Start with first state if available
	if get_child_count() > 0 and get_child(0) is State:
		change_state(get_child(0).name)

func _physics_process(delta):
	if current_state:
		current_state.process(delta)
		current_state.check_transitions()

func change_state(state_name: String):
	var new_state = states.get(state_name)
	if not new_state:
		push_error("Invalid state: " + state_name)
		return
	
	# Exit current state
	if current_state:
		current_state.exit()
	
	# Update state references
	previous_state = current_state
	current_state = new_state
	
	# Enter new state
	current_state.enter()
	
	# Emit signal for other systems
	emit_signal("state_changed", previous_state.name if previous_state else "", current_state.name)

func handle_event(event_name: String, data = null):
	if current_state and current_state.has_method("handle_event"):
		current_state.handle_event(event_name, data)
