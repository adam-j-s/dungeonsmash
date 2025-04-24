extends Line2D
class_name WaveTrail

var max_points = 12

func _ready():
	# Get the meta value from this node itself
	max_points = get_meta("max_points", 12)

func _process(delta):
	# Add current position (relative to parent) to front of line
	# For a Line2D attached to a moving parent, adding Vector2.ZERO
	# effectively adds the parent's current position relative to its own origin.
	add_point(Vector2.ZERO)

	# Remove old points if too many
	while get_point_count() > max_points:
		remove_point(0)
