extends Node
var ENABLE_DEBUG_FILE_LISTING := false
#func _ready():
	#list_directory_recursive("res://")
#
#func list_directory_recursive(path: String) -> void:
	#var dir := DirAccess.open(path)
	#if dir == null:
		#printerr("Could not open folder: ", path)
		#return
#
	#dir.list_dir_begin()
	#var file_name = dir.get_next()
	#while file_name != "":
		#if dir.current_is_dir():
			#if file_name != "." and file_name != "..":
				#print("Folder: ", path + "/" + file_name)
				#list_directory_recursive(path + "/" + file_name)
		#else:
			#print("File: ", path + "/" + file_name)
		#file_name = dir.get_next()
#
	#dir.list_dir_end()
