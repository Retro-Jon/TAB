extends VBoxContainer
class_name CodeWindow

var file_path := ""
@onready var editor : CodeEdit = $Editor
@onready var suggestions : RichTextLabel = $Suggestions
@onready var show_suggestions : Button = $ShowSuggestions

func _input(event) -> void:
	if event.is_action_pressed("Save") and visible:
		_save_file()
	
	if event.is_action_pressed("Close") and visible:
		queue_free()

func _ready() -> void:
	_load_file()

func _load_file() -> void:
	if FileAccess.file_exists(file_path):
		var file := FileAccess.open(file_path, FileAccess.READ)
		var content := file.get_as_text()
		editor.text = content
	
	var dir := file_path
	var dir_count := 0
	
	while !dir.is_empty() and dir_count < 2:
		if dir.ends_with("/") or dir.ends_with("\\"):
			dir_count += 1
		
		dir = dir.erase(dir.length() - 1)
	
	var delim := "/" if "/" in dir else "\\"
	
	if get_tree().current_scene.name != name:
		name = str(dir + delim).get_base_dir().split(delim, false)[-1] + "_" + file_path.get_file()

func _save_file() -> void:
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	file.store_string(editor.text)

func _on_editor_caret_changed() -> void:
	suggestions.clear()
	var line_num := editor.get_caret_line()
	var line := editor.get_line(line_num)
	var index := editor.get_caret_column()
	
	for i in range(index, line.length()):
		if line[i] in "()|":
			index = i
			break
	
	line = line.erase(index, line.length() - index)
	
	while (line.begins_with("\t") or line.begins_with(" ")) and !line.is_empty():
		line = line.erase(0)
	
	if line.begins_with(".section"):
		suggestions.add_text("Section Entry\n")
		return
	
	if line.begins_with(".block"):
		suggestions.add_text("Block Entry\n")
		return
	
	# (color blue | say "Hello")
	
	while !line.begins_with("(") and line_num > 0:
		line_num -= 1
		line = editor.get_line(line_num) + " " + line
		
		while (line.begins_with("\t") or line.begins_with(" ")) and !line.is_empty():
			line = line.erase(0)
	
	if line.begins_with("("):
		line = line.split("|", false)[-1]
		var args = str(line.erase(0) + " ").replace(")", "").split(" ", false)
		if args.size() == 0:
			return
		
		var command = args[0]
		suggestions.add_text(command + "\n")
		args.remove_at(0)
		
		match command:
			"begin":
				suggestions.add_text("(begin <local|global> action <name>)\n(begin <local|global> condition <condition>)\n(begin <local|global> auto)\n(begin <local|global> dialogue <name>)")
			"end":
				suggestions.add_text("(end) End a block.")
			"item":
				suggestions.add_text("(item <name> <value>)\nYou may use anything for the value.")
			"list":
				suggestions.add_text("(list <name> <item> <value>)\nYou can use as many <item> <value> pairs as you desire.\n<value> can be ignored.")
			"inventory":
				suggestions.add_text("(inventory <name> <item> <quantity>)\nYou can use as many <item> <quantity> pairs as you desire.\n<quantity> can be ignored.")
			"insert":
				suggestions.add_text("(insert <list> <item> <value>)\nYou can use as many <item> <value> pairs as you desire.\n<value> can be ignored.")
			"drop":
				suggestions.add_text("(drop <list> <item> <quantity>)\n(drop <inventory> <item> <quantity>)\nRemove a certain quantity of an item in a list or inventory.")
			"drop-all":
				suggestions.add_text("(drop-all <list> <item>)\n(drop-all <inventory> <item>)\nRemove all of an item from a list or inventory.")
			"say":
				suggestions.add_text("(say <message>)\nPrint message.")
			"say-any":
				suggestions.add_text("(say-any <message1> <message2>)\nPrint any of the given messages.\nYou may enter as many messages as you wish.")
			"move":
				suggestions.add_text("(move <section>)\nGo to different section.")
			"delete":
				suggestions.add_text("(delete <item>)\n(delete <list>)\n(delete <inventory>)")
			"input":
				suggestions.add_text("(input <item>)\n(input <list:item>)\n(input <inventory:item>)")
			"color":
				suggestions.add_text("(color <r,g,b>)\n(color <hex>)\n(color <name>)")
			"default":
				suggestions.add_text("(default color)\nReset color to user default.")
			"disable":
				suggestions.add_text("(disable <action>)\nDisable an action.\nAll actions are enabled by default.")
			"enable":
				suggestions.add_text("(enable <action>)\nEnable an action\nAll actions are enabled by default.")
			"if":
				suggestions.add_text("(if <condition>)\nContinue executing statment if the condition is true.\nOtherwise, go to next statement.")
			"case":
				suggestions.add_text("(case <input>)\nContinue executing statement if dialogue input matches <input>.")
			"enter-dialogue":
				suggestions.add_text("(enter-dialogue <dialogue>)\nBegin executing dialogue block.")
			"leave-dialogue":
				suggestions.add_text("(leave-dialogue)\nLeave current dialogue block and return to previous block.")
			"create":
				suggestions.add_text("(create <key> <value>)\nCreate local data that's initialized to <value> and can be accessed with <key>.")
			"eval":
				suggestions.add_text("(eval <expression>)\nEvaluate the given expression.")
			"image":
				suggestions.add_text("(image <file>)\nSet the background image to the given file.")
			"sound":
				suggestions.add_text("(sound <file>)\nPlay the sound from the given file.")
			"music":
				suggestions.add_text("(music <file>)\nPlay the music from the given file on repeat.")
			"run":
				suggestions.add_text("(run <section>)\nExecute code in another section.\nThe run command cannot be used within the executed section.")
			_:
				suggestions.add_text("Unknown command: " + command)
