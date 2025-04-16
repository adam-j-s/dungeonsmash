# splitter_enemy.gd
extends BaseEnemy

@export var split_threshold = 50  # Health where splitting occurs
@export var min_split_scale = 0.4  # Don't split if below this size

var original_max_health
var has_split = false

func _ready():
	super._ready()
	original_max_health = max_health

func take_damage(amount, hit_direction = Vector2.ZERO, knockback_strength = 0):
	# Apply damage
	super.take_damage(amount, hit_direction, knockback_strength)
	
	# Check for splitting
	if current_health <= split_threshold and not has_split and scale.x >= min_split_scale:
		split()

func split():
	has_split = true
	
	# Create two smaller copies
	for i in range(2):
		var split = duplicate()
		split.scale = scale * 0.6
		split.max_health = max_health * 0.5
		split.current_health = split.max_health
		split.has_split = true
		
		# Offset position and apply force
		var offset = 20 * (1 if i == 0 else -1)
		split.global_position.x += offset
		
		# Add to parent
		get_parent().add_child(split)
	
	# Remove original
	queue_free()
