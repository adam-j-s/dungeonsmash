# health_bar.gd
extends CanvasLayer

# Reference to the player being tracked
var player = null

# Configuration
var bar_width = 200
var bar_height = 20  # Changed to smaller height
var position_offset_value = Vector2(20, 20)  # Default top-left

# Colors
var background_color = Color(0.2, 0.2, 0.2, 0.8)  # Dark background
var fill_color = Color(1.0, 0.2, 0.2, 1.0)  # Default red

func _ready():
	# Get UI components
	var background = $Control/Background
	var fill = $Control/Fill
	
	# Configure the size directly using our variables
	if background:
		background.color = background_color
		background.size = Vector2(bar_width, bar_height)
	
	if fill:
		fill.color = fill_color
		fill.size = Vector2(bar_width, bar_height)

# Connect to player
func setup(target_player):
	player = target_player
	
	# Configure colors based on player number
	if player and "player_number" in player:
		if player.player_number == 1:
			fill_color = Color(1.0, 0.2, 0.2, 1.0)  # Red for Player 1
			position_offset_value = Vector2(20, 20)  # Top-left
		else:
			fill_color = Color(0.0, 0.5, 1.0, 1.0)  # Blue for Player 2
			position_offset_value = Vector2(900, 30)  # Top-right
			
		# Apply colors
		if $Control/Fill:
			$Control/Fill.color = fill_color
			
		# Apply position
		$Control.position = position_offset_value

func _process(delta):
	if not player or not is_instance_valid(player):
		return
	
	# Update health percentage
	update_health_display()

# Update health bar fill
func update_health_display():
	if player and "health" in player and "MAX_HEALTH" in player:
		var health_percent = float(player.health) / player.MAX_HEALTH
		var fill = $Control/Fill
		if fill:
			fill.size.x = bar_width * health_percent  # Use bar_width instead of max_width
