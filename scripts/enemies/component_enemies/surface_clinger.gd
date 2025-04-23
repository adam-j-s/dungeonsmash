# surface_clinger.gd
extends BaseEnemy
class_name SurfaceClinger

# Reference to config resource
@export var config_path: String = "res://resources/enemies/configs/surface_clinger_config.tres"

func _ready():
	# Load config from path
	var config_resource = load(config_path)
	if config_resource:
		config = config_resource
		
		# Set weapon ID from config
		if "weapon_id" in config:
			weapon_id = config.weapon_id
	else:
		# Fallback if config can't be loaded
		weapon_id = "cling_attack"
		push_warning("Failed to load config from: " + config_path)
	
	# Call parent ready which will process components
	super._ready()

# Override the parent's physics process
func _physics_process(delta):
	# Call super method which will process all components
	super._physics_process(delta)
	
	# Additional custom processing if needed
	# None needed currently, the components handle all behavior
	
# The component handling automatically takes care of everything else!
