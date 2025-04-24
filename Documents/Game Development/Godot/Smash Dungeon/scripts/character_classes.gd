# character_classes.gd
extends Node

# Dictionary of character classes with their properties
var classes = {
	"knight": {
		"name": "Knight",
		"strength": 15.0,
		"intelligence": 8.0,
		"agility": 10.0,
		"vitality": 12.0,
		"default_weapon": "sword",
		"sword_affinity": 1.5,
		"staff_affinity": 0.7
	},
	"wizard": {
		"name": "Wizard", 
		"strength": 7.0,
		"intelligence": 16.0,
		"agility": 12.0,
		"vitality": 8.0,
		"default_weapon": "staff",
		"sword_affinity": 0.7,
		"staff_affinity": 1.5
	}
	# Add more classes as needed
}

func get_character_class(class_id: String) -> Dictionary:
	if classes.has(class_id):
		return classes[class_id]
	return classes["knight"]  # Default fallback
