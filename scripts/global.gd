extends Node

var game_directory := ""

var settings := {
	"BackgroundColor" : Color("#00000080"),
	"DefaultTextColor" : Color("#ffffff"),
	"AllowTextColorOverride" : true,
	"InputTextColor" : Color("#00ff00"),
	"EnableTTS" : false,
	"EnableSoundFX" : true,
	"EnableMusic" : true
}

const settings_file_path := "user://settings.json"

func _ready() -> void:
	DisplayServer.window_set_min_size(Vector2i(640, 360))

func _load_settings_file() -> void:
	if FileAccess.file_exists(settings_file_path):
		var file = FileAccess.open(settings_file_path, FileAccess.READ)
		var content := file.get_as_text()
		var data : Dictionary = JSON.parse_string(content)
		
		var missing_keys := false
		for i in settings.keys():
			if !data.keys().has(i):
				missing_keys = true
				continue
			
			if settings[i] is Color:
				if str(data[i]).is_valid_html_color():
					settings[i] = Color(data[i])
			elif settings[i] is bool:
				settings[i] = bool(data[i])
		
		for i in data.keys():
			if !settings.keys().has(i):
				missing_keys = true
				break
		
		if missing_keys:
			_save_settings_file()
	else:
		_save_settings_file()

func _save_settings_file() -> void:
	var file := FileAccess.open(settings_file_path, FileAccess.WRITE)
	var data := settings.duplicate()
	
	for i in data.keys():
		if data[i] is Color:
			data[i] = Color(data[i]).to_html(true)
	
	var content := JSON.stringify(data, "    ")
	file.store_string(content)

func _load_adventures() -> PackedStringArray:
	var path := "user://Adventures"
	var dir := DirAccess.open("user://")
	
	if dir.dir_exists(path):
		var result := []
		for i in DirAccess.get_directories_at(path):
			result.append(i)
		
		return result
	
	dir.make_dir(path)
	return []
