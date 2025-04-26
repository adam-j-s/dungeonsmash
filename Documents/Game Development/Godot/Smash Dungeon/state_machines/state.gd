# state_machines/state.gd
class_name State
extends Node
const DEBUG = false
# Reference to the state machine that owns this state
var state_machine = null

# Reference to the enemy that owns the state machine
var enemy = null

# Enter is called when the state becomes active
func enter():
	pass

# Exit is called when the state becomes inactive
func exit():
	pass

# Process is called every frame during _process
func process(delta):
	pass

# Physics_process is called every physics frame during _physics_process
func physics_process(delta):
	pass

# This method handles messages sent to the state
func handle_message(msg, data=null):
	pass

# Utility function to change to another state
func change_state(new_state_name):
	if state_machine:
		state_machine.change_state(new_state_name)
