# state.gd
extends Node
class_name State

# References
var state_machine: StateMachine = null

# Virtual methods for states to implement
func enter():
	pass

func exit():
	pass

func process(delta):
	pass

func check_transitions():
	pass

func handle_event(event_name: String, data = null):
	pass

# Helper to change states
func change_state(new_state: String):
	state_machine.change_state(new_state)
