extends Control

@onready var adventures : ItemList = $Panel/VBoxContainer/Adventures

func _ready() -> void:
	Global._load_settings_file()
	for i in Global._load_adventures():
		adventures.add_item(i)

func _on_file_dialog_dir_selected(dir):
	var game_file = dir + "/scripts/start"
	
	if FileAccess.file_exists(game_file + ".tab") or FileAccess.file_exists(game_file + ".tabe"):
		Global.game_directory = dir
		get_tree().change_scene_to_file("res://scenes/runtime/run.tscn")

func _on_file_dialog_file_selected(path):
	if str(path).get_basename().replace(str(path).get_base_dir(), "").replace("/", "").replace("\\", "") == "start" and str(path).get_extension() in ["tab", "tabe"]:
		Global.game_directory = str(path).get_base_dir().get_base_dir()
		print(Global.game_directory)
		get_tree().change_scene_to_file("res://scenes/runtime/run.tscn")

func _on_edit_pressed():
	get_tree().change_scene_to_file("res://scenes/editor/edit.tscn")

func _on_adventures_item_activated(index):
	Global.game_directory = "user://Adventures/" + adventures.get_item_text(index)
	get_tree().change_scene_to_file("res://scenes/runtime/run.tscn")

