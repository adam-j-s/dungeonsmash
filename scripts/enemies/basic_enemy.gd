# basic_enemy.gd - Example of a specific enemy type
extends BaseEnemy

@export var detection_range: float = 300.0
@export var attack_range: float = 50.0

func _ready():
	super._ready()  # Call the parent _ready function

func initialize():
	# Set specific properties for this enemy type
	max_health = 80
	move_speed = 120
	
	# Initialize any specific components
	$AnimatedSprite2D.play("idle")
	
func perform_ai_logic(delta):
	if not _target_node or _is_defeated:
		return
		
	var distance = get_distance_to_target()
	
	if distance < detection_range:
		# Target is in detection range
		if distance > attack_range:
			# Move toward target if outside attack range
			var direction = (_target_node.global_position - global_position).normalized()
			velocity.x = direction.x * move_speed
			
			# Update animation direction
			$AnimatedSprite2D.flip_h = direction.x < 0
			$AnimatedSprite2D.play("run")
		else:
			# Target in attack range - attack!
			velocity.x = 0
			$AnimatedSprite2D.play("attack")
			
			# Logic to actually perform the attack would go here
			# Could call a attack() function that handles damage and timing
	else:
		# Target out of range, idle behavior
		velocity.x = 0
		$AnimatedSprite2D.play("idle")

# Override the take_damage method to handle the additional parameters
func take_damage(amount, hit_direction = Vector2.ZERO, knockback_strength = 0):
	# Call the parent class's take_damage method with just the amount
	super.take_damage(amount)
	
	# Handle knockback if provided
	if knockback_strength > 0 and hit_direction != Vector2.ZERO:
		# Apply knockback force
		velocity = hit_direction.normalized() * knockback_strength
