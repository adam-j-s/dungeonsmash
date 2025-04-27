# state_machines/states/death_state.gd
class_name DeathState
extends State

func enter():
	# Play death effects (delegated to the enemy script)
	if enemy.has_method("play_death_effects"):
		enemy.play_death_effects()
	else:
		printerr("%s: Enemy missing play_death_effects() method!" % enemy.name)
		# Fallback? Maybe just queue_free after short delay?
		# get_tree().create_timer(0.5).timeout.connect(enemy.queue_free)

	# Stop movement intention and current momentum immediately
	if "target_velocity" in enemy: enemy.target_velocity = Vector2.ZERO
	if "velocity" in enemy: enemy.velocity = Vector2.ZERO # Stop current momentum

	if state_machine and state_machine.debug_mode:
		print("%s: Entering DeathState." % enemy.name)


func physics_process(_delta):
	# Ensure the enemy does not attempt to move while in the death state
	# This prevents move_and_slide from potentially reviving movement
	if "target_velocity" in enemy: enemy.target_velocity = Vector2.ZERO
