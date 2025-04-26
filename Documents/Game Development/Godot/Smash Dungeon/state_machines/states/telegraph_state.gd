# state_machines/states/telegraph_state.gd
extends State
class_name TelegraphState

# Internal timer node to manage telegraph duration
var timer: Timer

# Configuration parameters cache (loaded from enemy.config on enter)
var duration: float = 1.0
var movement_type: String = "default" # Valid types: "none", "default", "custom"

# --- Godot Lifecycle Methods ---

func _ready():
	# Create and configure the internal timer node
	timer = Timer.new()
	timer.one_shot = true
	# Connect the timeout signal to a local method within this state
	timer.timeout.connect(_on_timer_timeout)
	add_child(timer) # Add the timer as a child of this TelegraphState node

# --- State Machine Lifecycle Methods ---

func enter():
	# Load configuration specific to this state from the enemy's config resource
	if enemy and enemy.config and enemy.config.states_config.has("TelegraphState"):
		var telegraph_config = enemy.config.states_config["TelegraphState"]
		duration = telegraph_config.get("telegraph_duration", 1.0)
		movement_type = telegraph_config.get("telegraph_movement_type", "default")
		if state_machine.debug_mode:
			print("%s: Telegraph Config loaded: duration=%.2f, movement='%s'" % [enemy.name, duration, movement_type])
	else:
		# Log an error if the configuration is missing for this state
		printerr("%s: TelegraphState could not find its configuration in enemy.config.states_config. Using default values." % enemy.name)
		# Note: Default values for 'duration' and 'movement_type' are already set above

	# Start the telegraph timer using the configured duration
	timer.wait_time = duration
	timer.start()

	# Activate the visual telegraph effect by calling a method on the enemy instance
	# It's the enemy script's responsibility to implement this visual logic
	if enemy.has_method("_show_telegraph_visual"):
		enemy._show_telegraph_visual(true, duration)

func exit():
	# Ensure the timer is stopped cleanly when exiting the state
	# This prevents the timer from firing after the state has already changed (e.g., if stunned)
	if timer.is_running():
		timer.stop()

	# Deactivate the visual telegraph effect by calling the corresponding enemy method
	if enemy.has_method("_show_telegraph_visual"):
		enemy._show_telegraph_visual(false)

func physics_process(delta):
	# Determine and apply the configured movement behavior during the telegraph phase
	# This sets the enemy's *intended* velocity; the actual movement is handled by BaseEnemySM
	match movement_type:
		"none":
			# Intend to stand still horizontally
			enemy.target_velocity.x = 0
		"default":
			# Delegate movement logic to a standardized method on the enemy instance
			if enemy.has_method("_execute_default_movement"):
				enemy._execute_default_movement(delta)
			else:
				# Log an error if the required method is missing for 'default' movement
				printerr("%s: TelegraphState movement_type is 'default' but enemy lacks _execute_default_movement(delta) method." % enemy.name)
				enemy.target_velocity.x = 0 # Fallback to standing still horizontally
		"custom":
			# Call the virtual function intended for enemy-specific or derived state logic
			_execute_custom_telegraph_movement(delta)
		_:
			# Handle unexpected movement_type values
			printerr("%s: Unknown telegraph_movement_type: '%s'. Defaulting to 'none'." % [enemy.name, movement_type])
			enemy.target_velocity.x = 0

# --- Signal Handlers ---

# Called by the internal Timer node when its time is up
func _on_timer_timeout():
	# The telegraph duration has completed, proceed to the attack execution phase
	if state_machine.debug_mode: print("%s: Telegraph timer finished. Transitioning to AttackState." % enemy.name)
	state_machine.change_state("AttackState")

# --- Virtual Methods for Extension ---

# This method is designed to be overridden by derived TelegraphState scripts
# or potentially implemented directly if using the "custom" movement type without derivation.
func _execute_custom_telegraph_movement(_delta):
	# Base implementation does nothing.
	pass
