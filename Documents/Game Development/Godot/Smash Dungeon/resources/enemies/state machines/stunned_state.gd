# stunned_state.gd
extends State
class_name StunnedState

@export var stun_duration: float = 1.0
@export var knockback_recovery_speed: float = 5.0

var stun_timer: float = 0.0

func enter():
	stun_timer = stun_duration
	
	# Play stun animation if available
	var owner_entity = state_machine.owner_entity
	if owner_entity.has_node("AnimatedSprite2D"):
		var sprite = owner_entity.get_node("AnimatedSprite2D")
		if sprite.sprite_frames.has_animation("stunned"):
			sprite.play("stunned")

func process(delta):
	var owner_entity = state_machine.owner_entity
	
	# Slow down movement
	owner_entity.target_velocity = Vector2.ZERO
	owner_entity.velocity = owner_entity.velocity.move_toward(Vector2.ZERO, knockback_recovery_speed * delta)
	
	# Update timer
	stun_timer -= delta

func check_transitions():
	# Return to chase when stun ends
	if stun_timer <= 0:
		if is_instance_valid(state_machine.owner_entity._target_node):
			change_state("Chase")
		else:
			change_state("Idle")

func handle_event(event_name: String, data = null) -> Variant:
	if event_name == "hit":
		# Reset stun timer when hit again
		stun_timer = stun_duration
		
		# Apply additional knockback if provided
		if data and "direction" in data and "amount" in data:
			var knockback_force = min(data.amount * 10, 200)  # Scale with damage
			state_machine.owner_entity.velocity += data.direction * knockback_force
	return null
