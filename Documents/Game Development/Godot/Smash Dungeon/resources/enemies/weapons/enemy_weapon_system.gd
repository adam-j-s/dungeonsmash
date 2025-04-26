# enemy_weapon_system.gd
extends Node
class_name EnemyWeaponSystem

# References
var enemy: BaseEnemy = null
var weapon: Weapon = null 
var mount_point: Node2D = null

# Configuration
var weapon_id: String = ""
var attack_style: String = ""  # Single source of truth

# Signals
signal attack_performed(attack_type)
signal cooldown_complete()

# Debug
var debug_mode: bool = false

func _ready():
	# If we have an enemy parent, auto-initialize
	if get_parent() is BaseEnemy:
		initialize(get_parent())

func initialize(parent_enemy: BaseEnemy, weapon_type: String = ""):
	enemy = parent_enemy
	
	# Try to find a weapon mount point
	mount_point = enemy.get_node_or_null("WeaponMount")
	if not mount_point:
		# Create one if needed
		mount_point = Node2D.new()
		mount_point.name = "WeaponMount"
		enemy.add_child(mount_point)
	
	if weapon_type != "":
		equip_weapon(weapon_type)
	elif "weapon_id" in enemy and enemy.weapon_id != "":
		equip_weapon(enemy.weapon_id)
	
	if debug_mode:
		print("EnemyWeaponSystem initialized for: " + enemy.name)
		
func equip_weapon(id: String):
	weapon_id = id
	
	# Clean up existing weapon
	if weapon and is_instance_valid(weapon):
		weapon.queue_free()
		weapon = null
	
	# Create new weapon
	weapon = Weapon.new()
	weapon.name = "EnemyWeapon"
	
	# Add to mount point
	mount_point.add_child(weapon)
	
	# Load and initialize
	weapon.load_weapon(id)
	weapon.initialize(enemy)
	
	# Extract attack style from weapon data
	if weapon.weapon_data and "weapon_style" in weapon.weapon_data:
		attack_style = weapon.weapon_data.weapon_style
	else:
		attack_style = "melee"  # Default fallback
	
	# Connect cooldown signal
	if weapon.has_signal("cooldown_completed"):
		if weapon.is_connected("cooldown_completed", _on_cooldown_complete):
			weapon.disconnect("cooldown_completed", _on_cooldown_complete)
		weapon.cooldown_completed.connect(_on_cooldown_complete)
			
	if debug_mode:
		print("Equipped weapon %s with attack style: %s" % [id, attack_style])

func can_attack() -> bool:
	# First check if we have a weapon
	if not weapon:
		return false
	
	# Check if weapon is ready to attack
	var ready = weapon.can_attack
	
	# For better debugging
	if debug_mode:
		print("EnemyWeaponSystem.can_attack check: " + str(ready))
		if weapon.cooldown_timer and !weapon.cooldown_timer.is_stopped():
			print("Cooldown remaining: " + str(weapon.cooldown_timer.time_left))
	
	return ready

func perform_attack() -> bool:
	if not weapon:
		return false
	
	if debug_mode:
		print("EnemyWeaponSystem: Performing attack with style: " + attack_style)
	
	var success = weapon.perform_attack()
	if success:
		attack_performed.emit(attack_style)
	
	return success
	
func reset_cooldown():
	if weapon:
		print("Resetting weapon cooldown...")
		if weapon.cooldown_timer and !weapon.cooldown_timer.is_stopped():
			weapon.cooldown_timer.stop()
		
		# Ensure weapon is ready to attack
		weapon.can_attack = true
		
		# Ensure any buffered attacks are cleared
		weapon.buffered_attack = false
		
		# Emit the signal
		if weapon.has_signal("cooldown_completed"):
			weapon.cooldown_completed.emit()
		
		# Also emit our own signal
		cooldown_complete.emit()
		
func _on_cooldown_complete():
	if debug_mode:
		print("Weapon cooldown completion detected, emitting signal")
	cooldown_complete.emit()

func get_attack_range() -> float:
	if weapon and weapon.weapon_data:
		if "range" in weapon.weapon_data:
			return float(weapon.weapon_data.range.get("x", 50.0))
	return 50.0  # Default
	
func get_weapon_offset() -> Vector2:
	# Get sprite orientation from parent
	var facing_right = true
	if enemy and enemy.has_node("AnimatedSprite2D"):
		var sprite = enemy.get_node("AnimatedSprite2D")
		facing_right = !sprite.flip_h
	
	# Return appropriate offset based on facing
	return Vector2(10 if facing_right else -10, 0)
	
func update_position():
	# Update weapon mount based on enemy orientation
	mount_point.position = get_weapon_offset()
