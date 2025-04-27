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

# In EnemyWeaponSystem.gd

func initialize(parent_enemy: BaseEnemy, weapon_type_override: String = ""):
	enemy = parent_enemy
	if not is_instance_valid(enemy):
		printerr("EnemyWeaponSystem: Invalid parent_enemy provided during initialization.")
		return

	# Set debug mode based on enemy/config if possible
	if is_instance_valid(enemy.config) and "debug_mode" in enemy.config:
		debug_mode = enemy.config.debug_mode
	elif "debug_mode" in enemy:
		debug_mode = enemy.debug_mode

	# Try to find a weapon mount point
	mount_point = enemy.get_node_or_null("WeaponMount")
	if not is_instance_valid(mount_point):
		# Create one if needed, use call_deferred for safety when called from _ready
		print("EnemyWeaponSystem: Creating WeaponMount for %s" % enemy.name)
		mount_point = Node2D.new()
		mount_point.name = "WeaponMount"
		enemy.call_deferred("add_child", mount_point)
		# We might need to wait a frame for mount_point to be ready if created here.
		# Alternatively, ensure mount_point is always present in enemy scenes.


	# --- Determine Weapon ID to Equip ---
	var id_to_equip: String = ""

	# 1. Prioritize explicit override argument
	if weapon_type_override != "":
		id_to_equip = weapon_type_override
		if debug_mode: print("EnemyWeaponSystem: Using weapon_id from override argument: '%s'" % id_to_equip)
	# 2. Read directly from enemy's loaded config resource
	elif is_instance_valid(enemy.config) and "weapon_id" in enemy.config and enemy.config.weapon_id != "":
		id_to_equip = enemy.config.weapon_id
		if debug_mode: print("EnemyWeaponSystem: Using weapon_id from enemy.config: '%s'" % id_to_equip)
	# 3. Fallback to the enemy's direct property (less ideal, for compatibility)
	elif "weapon_id" in enemy and enemy.weapon_id != "":
		id_to_equip = enemy.weapon_id
		push_warning("EnemyWeaponSystem: Using weapon_id from enemy property (fallback): '%s'" % id_to_equip)
	# ------------------------------------

	# Equip the weapon if an ID was determined
	if id_to_equip != "":
		# Need to ensure mount_point is ready if just created deferred
		if mount_point.get_parent() != enemy:
			await enemy.child_entered_tree # Wait a frame if mount point was deferred
		if is_instance_valid(mount_point): # Check again after potential wait
			equip_weapon(id_to_equip)
		else:
			printerr("EnemyWeaponSystem: Mount point still invalid after potential wait for deferred add_child.")
	else:
		print("EnemyWeaponSystem: No weapon_id found for %s. No weapon equipped." % enemy.name)

	if debug_mode:
		print("EnemyWeaponSystem initialized for: " % enemy.name) # Already printed ID source
		
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

# In EnemyWeaponSystem.gd

func can_attack() -> bool:
	# First check if we have a weapon
	if not is_instance_valid(weapon): # Use is_instance_valid for safety
		if debug_mode: print("--- EnemyWeaponSystem.can_attack: FAILED (no valid weapon instance)")
		return false

	# Check if weapon instance actually has the property
	if not "can_attack" in weapon:
		if debug_mode: print("--- EnemyWeaponSystem.can_attack: FAILED (weapon instance lacks 'can_attack' property)")
		return false

	# Get the value from the weapon instance
	var ready = weapon.can_attack

	# Print the value *read directly from the weapon instance*
	if debug_mode:
		print("--- EnemyWeaponSystem.can_attack: Reading weapon.can_attack = %s" % ready) # <<< MORE SPECIFIC PRINT
		# Print cooldown timer info if available
		if "cooldown_timer" in weapon and is_instance_valid(weapon.cooldown_timer) and not weapon.cooldown_timer.is_stopped():
			print("    Weapon cooldown remaining: %.3f" % weapon.cooldown_timer.time_left)
		elif "cooldown_timer" in weapon and is_instance_valid(weapon.cooldown_timer) and weapon.cooldown_timer.is_stopped():
			print("    Weapon cooldown timer is stopped.")
		else:
			print("    Weapon cooldown timer info not available.")

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
