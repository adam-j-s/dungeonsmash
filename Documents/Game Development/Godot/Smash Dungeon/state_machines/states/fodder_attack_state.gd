# fodder_attack_state.gd - Place in state_machines/states/ folder
extends AttackState
class_name FodderAttackState

var is_telegraphing: bool = false
var telegraph_timer: float = 0.0
const DEBUG = true  # Debug flag

func enter():
	super.enter()
	
	# Reset telegraph state
	is_telegraphing = false
	telegraph_timer = 0.0
	
	if DEBUG:
		print("FodderAttackState entered")
		
	# Start the attack sequence immediately
	start_telegraph_attack()

func physics_process(delta):
	# Update telegraph timer
	if is_telegraphing:
		telegraph_timer += delta
		
		# Only try to show telegraph if it exists
		if enemy.has_node("TelegraphEffect"):
			var telegraph = enemy.get_node("TelegraphEffect")
			if telegraph:
				telegraph.visible = true
		
		# After telegraph time expires, perform the attack
		if telegraph_timer >= enemy.attack_telegraph_time:
			if DEBUG:
				print("Telegraph complete, performing attack")
			is_telegraphing = false
			telegraph_timer = 0
			
			# Hide telegraph
			if enemy.has_node("TelegraphEffect"):
				enemy.get_node("TelegraphEffect").visible = false
				
			# Execute attack
			perform_attack()
			return
			
	# If not telegraphing, use normal attack state behavior
	if not is_telegraphing:
		super.physics_process(delta)

func start_telegraph_attack():
	if DEBUG:
		print("Starting telegraph attack")
		
	# Make sure we can attack
	if !enemy.can_attack:
		if DEBUG:
			print("Cannot start telegraph - enemy not ready to attack")
		change_state("ChaseState")
		return
		
	# Make sure target is valid
	if !is_instance_valid(enemy._target_node):
		if DEBUG:
			print("Cannot start telegraph - no valid target")
		change_state("IdleState")
		return
		
	is_telegraphing = true
	telegraph_timer = 0
	
	# Try to show telegraph effect if it exists
	if enemy.has_node("TelegraphEffect"):
		var telegraph = enemy.get_node("TelegraphEffect")
		if telegraph:
			# Configure telegraph
			telegraph.visible = true
			telegraph.size = Vector2(16, 16)
			telegraph.position = Vector2(-8, -8)  # Center it
			telegraph.color = Color(1, 0, 0, 0.3)  # Semi-transparent red
			
			if DEBUG:
				print("Telegraph effect shown")

func perform_attack():
	if DEBUG:
		print("FodderAttackState attempting to perform attack")
	
	# Hide telegraph
	if enemy.has_node("TelegraphEffect"):
		enemy.get_node("TelegraphEffect").visible = false
	
	# Debug weapon system
	if DEBUG:
		if enemy.weapon_system:
			print("- Weapon system exists")
			print("- Can attack (enemy): " + str(enemy.can_attack))
			print("- Can attack (weapon): " + str(enemy.weapon_system.can_attack()))
		else:
			print("- No weapon system available")
	
	# Make sure we're positioned optimally for attack
	if is_instance_valid(enemy._target_node):
		var attack_vector = (enemy._target_node.global_position - enemy.global_position).normalized()
		enemy.global_position += attack_vector * 5
	
	# Force sync states before attacking
	if enemy.weapon_system and enemy.weapon_system.weapon:
		if enemy.can_attack != enemy.weapon_system.weapon.can_attack:
			# Set both to true
			enemy.can_attack = true
			enemy.weapon_system.weapon.can_attack = true
			if DEBUG:
				print("- Forced state synchronization before attack")
	
	# Use weapon system to attack
	var attack_success = false
	if enemy.weapon_system:
		if enemy.weapon_system.has_method("perform_attack"):
			if DEBUG:
				print("- Calling perform_attack on weapon system")
			
			attack_success = enemy.weapon_system.perform_attack()
			
			if DEBUG:
				print("- Attack result: " + str(attack_success))
			
			if attack_success:
				enemy.can_attack = false
		else:
			if DEBUG:
				print("- Weapon system missing perform_attack method")
	
	# Handle post-attack behavior
	handle_post_attack_decision()
