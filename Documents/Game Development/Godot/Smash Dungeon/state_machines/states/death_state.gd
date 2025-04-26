# state_machines/states/death_state.gd
class_name DeathState
extends State

func enter():
	# Play death effects
	enemy.play_death_effects()
	
	# Stop movement
	enemy.target_velocity = Vector2.ZERO
	enemy.velocity = Vector2.ZERO

func physics_process(_delta):
	# Keep the enemy from moving during death
	enemy.target_velocity = Vector2.ZERO
