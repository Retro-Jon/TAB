extends Control

var run_time = preload("res://scenes/runtime/run.tscn")
var code_window = preload("res://scenes/editor/code_window.tscn")
var run_time_instance : RunTime = null

@onready var views : TabContainer = $VBoxContainer/Views
@onready var code_view : TabContainer = $VBoxContainer/Views/CodeView
@onready var code_view_button : Button = $VBoxContainer/Options/CodeView
@onready var run : Button = $VBoxContainer/Options/Run
@onready var stop : Button = $VBoxContainer/Options/Stop

@onready var open_file : FileDialog = $Open
@onready var new_file : FileDialog = $NewFile
@onready var project_button : MenuButton = $VBoxContainer/Options/Project

func _input(event) -> void:
	if event.is_action_pressed("Run"):
		_on_run_pressed()
	elif event.is_action_pressed("Open"):
		open_file.show()
	elif event.is_action_pressed("New"):
		new_file.show()

func _ready() -> void:
	project_button.get_popup().connect("id_pressed", _project_button_pressed)

func _on_run_pressed() -> void:
	if code_view.get_child_count() == 0:
		return
	
	Global.game_directory = str(code_view.get_child(code_view.current_tab).file_path).get_base_dir()
	Global.game_directory = Global.game_directory.replace("\\", "/").split("/scripts")[0]
	
	if Global.game_directory.is_empty():
		run.button_pressed = false
		return
	
	stop.show()
	code_view_button.show()
	run.hide()
	
	if run_time_instance == null:
		run_time_instance = run_time.instantiate()
		views.add_child(run_time_instance)
	
	views.current_tab = views.get_child_count() - 1

func _on_stop_pressed() -> void:
	if run_time_instance != null:
		run_time_instance.queue_free()
	
	stop.hide()
	code_view_button.hide();
	run.show()

func _on_open_files_selected(paths) -> void:
	for i in paths:
		if !code_view.has_node(str(i).get_file().replace(".", "_")):
			var new_code_tab : CodeWindow = code_window.instantiate()
			new_code_tab.file_path = i
			code_view.add_child(new_code_tab)
		else:
			code_view.current_tab = code_view.get_node(str(i).get_file().replace(".", "_")).get_index()
	
	run.show()

func _on_open_file_selected(path) -> void:
	_on_open_files_selected([path])

func _on_new_file_file_selected(path) -> void:
	_on_open_files_selected([path])

func _on_code_view_pressed() -> void:
	views.current_tab = 0
	run.show()

func _encryption_finished(content : String) -> void:
	var file_path : String = code_view.get_current_tab_control().file_path
	file_path = file_path.replace(".tab", ".tabe")
	print(file_path)
	var file : FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	file.store_string(content)

func _on_exit_confirmed() -> void:
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")

func _project_button_pressed(id : int) -> void:
	print(id)
	match id:
		0: # Open
			open_file.show()
		1: # Close
			var count = code_view.get_child_count()
			if count > 0:
				code_view.get_current_tab_control().queue_free()
				if count == 1:
					run.hide()
		2: # Save
			get_tree().call_group("code_window", "_save_file")
		3: # New File
			new_file.show()
			print("NewFile")
		_:
			pass
