# Basic Enemy
extends CharacterBody2D

const GRAVITY = 980 # Or use ProjectSettings.get_setting("physics/2d/default_gravity")

func _physics_process(delta):
	# Apply gravity
	velocity.y += GRAVITY * delta
	move_and_slide()
