func _on_pull_hit(body):
	# Get hitbox and references
	var pull_hitbox = body.get_parent()
	
	# Check metadata existence
	if !pull_hitbox.has_meta("weapon") or !pull_hitbox.has_meta("wielder"):
		print("ERROR: Missing metadata on pull hitbox")
		return
	
	# Get references
	var weapon_ref = pull_hitbox.get_meta("weapon")
	var wielder_ref = pull_hitbox.get_meta("wielder")
	
	if !weapon_ref or !wielder_ref or body == wielder_ref:
		return
	
	# Rest of the function
	print("Pull hit: ", body.name)
