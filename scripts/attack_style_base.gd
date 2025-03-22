# attack_style_base.gd (in res://scripts/)
class_name AttackStyle
extends Resource

var weapon = null
var wielder = null
const DEBUG = true

func initialize(weapon_ref):
	weapon = weapon_ref
	if weapon:
		wielder = weapon.wielder
	_init_style()

func _init_style():
	# Override in derived styles
	pass

func get_style_name() -> String:
	return "BaseAttackStyle"

func execute_attack():
	print("Base attack style - override in derived classes")

func get_param(param_name, default_value):
	if weapon and weapon.weapon_data.has(param_name):
		return weapon.weapon_data[param_name]
	return default_value
