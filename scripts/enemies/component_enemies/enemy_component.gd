# Enemy Component
class_name EnemyComponent
extends Node2D

# Reference to the owner enemy
var enemy: BaseEnemy
const DEBUG = true

func _ready():
	# Connect to the parent enemy
	var parent = get_parent()
	while parent != null:
		if parent is BaseEnemy:
			enemy = parent
			break
		parent = parent.get_parent()
	
	# Warn if not attached to an enemy
	if enemy == null:
		push_error(name + ": Component not attached to a BaseEnemy")
	
	# Setup the component
	setup()
func setup_component(owner_enemy : BaseEnemy):
	if not is_instance_valid(owner_enemy):
		push_error("[%s] Invalid owner passed to setup_component!" % name)
		return
	enemy = owner_enemy
	if DEBUG: print("[%s] Component setup for %s" % [name, enemy.name]) # Added DEBUG check
	# Call the component-specific setup AFTER the enemy reference is set
	setup()

# Virtual function for component setup
func setup() -> void:
	pass

# Process function called by the enemy
func process(delta: float) -> void:
	pass
