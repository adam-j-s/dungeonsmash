# death_state.gd
extends State
class_name DeathState

@export var death_animation_duration: float = 1.0
@export var corpse_persistence_time: float = 5.0  # How long to keep corpse before removal

var death_timer: float = 0.0
var fade_started: bool = false

func enter():
	var owner_entity = state_machine.owner_entity
	
	# Disable collision
	for child in owner_entity.get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.set_deferred("disabled", true)
	
	# Zero out velocity
	owner_entity.velocity = Vector2.ZERO
	owner_entity.target_velocity = Vector2.ZERO
	
	# Play death animation if available
	if owner_entity.has_node("AnimatedSprite2D"):
		var sprite = owner_entity.get_node("AnimatedSprite2D")
		if sprite.sprite_frames.has_animation("death"):
			sprite.play("death")
	
	# If there's an animation player with death animation, play it
	if owner_entity.has_node("AnimationPlayer"):
		var anim_player = owner_entity.get_node("AnimationPlayer")
		if anim_player.has_animation("death"):
			anim_player.play("death")

func process(delta):
	death_timer += delta
	
	# Start fade out when animation finishes
	if death_timer >= death_animation_duration and !fade_started:
		start_fade_out()
		fade_started = true
	
	# Remove entity when done
	if death_timer >= death_animation_duration + corpse_persistence_time:
		state_machine.owner_entity.queue_free()

func start_fade_out():
	var owner_entity = state_machine.owner_entity
	
	# Create fade out tween
	if owner_entity.has_node("AnimatedSprite2D"):
		var sprite = owner_entity.get_node("AnimatedSprite2D")
		var tween = sprite.create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, corpse_persistence_time)
	
	# You could also add particles, sound effects, etc.
	# For example, add a simple particle effect
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.8
	particles.amount = 20
	particles.lifetime = 1.0
	particles.direction = Vector2(0, -1)
	particles.spread = 180
	particles.gravity = Vector2(0, 98)
	particles.initial_velocity_min = 30
	particles.initial_velocity_max = 50
	
	# Add particles to the owner
	owner_entity.add_child(particles)

func check_transitions():
	# No transitions out of death state
	pass

func handle_event(event_name: String, data = null) -> Variant:
	# No event handling in death state
	return null
