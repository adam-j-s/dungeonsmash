# state_machines/states/telegraph_state.gd
extends State
class_name TelegraphState

# Internal timer node to manage telegraph duration
var timer: Timer

# Local variables to store configuration values for this state instance
var duration: float = 1.0          # Default value if not in config
var movement_type: String = "none" # Default value if not in config ("none", "default", "custom")

# --- Godot Lifecycle Methods ---

func _ready():
	timer = Timer.new()
	timer.one_shot = true
	timer.timeout.connect(_on_timer_timeout)
	add_child(timer)

# --- State Machine Lifecycle Methods ---

func enter():
	# Attempt to load configuration from the specific TelegraphStateConfig resource
	var loaded_config = false
	if is_instance_valid(enemy) and is_instance_valid(enemy.config) and is_instance_valid(enemy.config.telegraph_config):
		var cfg: TelegraphStateConfig = enemy.config.telegraph_config # Assign the specific resource

		# Load values from the config resource's properties
		self.duration = cfg.telegraph_duration
		self.movement_type = cfg.telegraph_movement_type
		loaded_config = true

		if state_machine.debug_mode:
			print("%s: TelegraphState loaded config: duration=%.2f, movement='%s'" % [enemy.name, duration, movement_type])

	if not loaded_config:
		# Log error or warning if config resource is missing or invalid
		printerr("%s: TelegraphState could not find valid telegraph_config resource. Using default values." % get_path())
		# Defaults are already set above

	# Start the telegraph timer using the configured duration
	timer.wait_time = self.duration # Use state's loaded value
	timer.start()

	# Activate the visual telegraph effect
	if enemy.has_method("_show_telegraph_visual"):
		enemy._show_telegraph_visual(true, self.duration) # Pass loaded duration


func exit():
	# Ensure the timer is stopped cleanly when exiting the state
	# Use is_stopped() which IS a valid Timer method
	if not timer.is_stopped(): # <<< CORRECTED CHECK: Check if NOT stopped (i.e., running)
		timer.stop()

	# Deactivate the visual telegraph effect
	if enemy.has_method("_show_telegraph_visual"):
		enemy._show_telegraph_visual(false)

	if state_machine and state_machine.debug_mode:
		print("%s: Exiting TelegraphState." % enemy.name) # Optional exit print


func physics_process(delta):
	# Use the loaded movement_type config value
	match self.movement_type:
		"none":
			if "target_velocity" in enemy: enemy.target_velocity.x = 0
		"default":
			if enemy.has_method("_execute_default_movement"):
				enemy._execute_default_movement(delta)
			else:
				printerr("%s: TelegraphState movement_type is 'default' but enemy lacks _execute_default_movement(delta) method." % enemy.name)
				if "target_velocity" in enemy: enemy.target_velocity.x = 0 # Fallback
		"custom":
			_execute_custom_telegraph_movement(delta)
		_:
			printerr("%s: Unknown telegraph_movement_type: '%s'. Defaulting to 'none'." % [enemy.name, self.movement_type])
			if "target_velocity" in enemy: enemy.target_velocity.x = 0


# --- Signal Handlers ---

func _on_timer_timeout():
	if state_machine.debug_mode: print("%s: Telegraph timer finished. Transitioning to AttackState." % enemy.name)
	state_machine.change_state("AttackState")


# --- Virtual Methods for Extension ---

func _execute_custom_telegraph_movement(_delta):
	# Base implementation does nothing.
	pass
