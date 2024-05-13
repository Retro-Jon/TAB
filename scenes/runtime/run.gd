extends Control
class_name RunTime

@onready var background_tint : ColorRect = $BackgroundTint
@onready var background_image : TextureRect = $BackgroundImage
@onready var input : LineEdit = $View/Interface/Input
@onready var output : RichTextLabel = $View/Interface/Output
@onready var information : VBoxContainer = $View/ScrollContainter/Information
@onready var progress_bar : ProgressBar = $Progress

const single_item = preload("res://scenes/items/single_item.tscn")
const list_item = preload("res://scenes/items/list_item.tscn")
const inventory_item = preload("res://scenes/items/inventory_item.tscn")

signal change_section

var section_data := {}

var blocks := {}
var sections := {}

var current_section := "start"

var ignore_actions := []

# code
var local_autos := []
var global_autos := []

# action argument : code
var local_actions := {}
var global_actions := {}

# event condition : code
var local_events := {}
var global_events := {}

# dialogue name : code
var local_dialogs := {}
var global_dialogs := {}

var active_color := Color.WHITE

var input_history : PackedStringArray = []
var input_history_pointer : int = 0

var responses := {}
var response := ""

var thread := Thread.new()

var user_input := ""
var in_dialog := false

func _ready() -> void:
	ScriptParser.connect("ParseComplete", _start_adventure)
	ScriptParser.connect("UpdateProgress", _update_parsing_progress)
	
	connect("change_section", _execute)
	
	_load_defaults()
	randomize()
	await get_tree().create_timer(2).timeout
	_start()

func _start() -> void:
	var game_file = Global.game_directory + "/scripts/start"
	print(game_file)
	
	if FileAccess.file_exists(game_file + ".tab"):
		var file := FileAccess.open(game_file + ".tab", FileAccess.READ)
		var content := file.get_as_text()
		
		_parse_code(content)
	else:
		_print_message("File not found: " + game_file.get_file())

func _parse_code(content : String) -> void:
	if thread.is_started():
		thread.wait_to_finish()
	
	thread.start(ScriptParser._parse.bind(content))

func _start_adventure(new_sections : Dictionary, new_blocks : Dictionary) -> void:
	if thread.is_started():
		thread.wait_to_finish()
	
	sections = new_sections
	blocks = new_blocks
	
	input.grab_focus()
	
	_execute()

func _update_parsing_progress(progress : float) -> void:
	progress_bar.show()
	progress_bar.value = progress
	progress_bar.get_node("parsing").show()
	
	if progress_bar.value >= progress_bar.max_value:
		progress_bar.hide()
		progress_bar.get_node("parsing").hide()

func _load_defaults() -> void:
	background_tint.color = Global.settings["BackgroundColor"]
	output.add_theme_color_override("default_color", Global.settings["DefaultTextColor"])
	active_color = output.get_theme_color("default_color")
	input.add_theme_color_override("font_color", Global.settings["InputTextColor"])

func _input(event) -> void:
	if input_history.size() > 0:
		if event.is_action_pressed("InputBufferUp"):
			input_history_pointer -= 1
		elif event.is_action_pressed("InputBufferDown"):
			input_history_pointer += 1
		
		if input_history_pointer > input_history.size() - 1:
			input_history_pointer = 0
		elif input_history_pointer < 0:
			input_history_pointer = input_history.size() - 1
		
		if event.is_action_pressed("InputBufferUp") or event.is_action_pressed("InputBufferDown"):
			input.text = input_history[input_history_pointer]

func _on_input_text_changed(_new_text):
	input_history_pointer = input_history.size()

func _multi_split(text : String, delimiters : PackedStringArray) -> PackedStringArray:
	var result : PackedStringArray = []
	
	if delimiters.is_empty():
		return [text]
	
	for i in text.split(delimiters[0], false):
		var new_delimiters : PackedStringArray = delimiters.duplicate()
		new_delimiters.remove_at(0)
		result.append_array(_multi_split(i, new_delimiters))
	
	Array(result).erase("")
	
	return result

func _divide_input_string(text : String) -> PackedStringArray:
	var result : PackedStringArray = []
	
	for i in _multi_split(text.to_lower(), ["but then"]):
		var temp : PackedStringArray = _multi_split(i.split(" but ", false)[-1], ["and", "before", "then"])
		for a in temp:
			if "after" in a:
				var val : PackedStringArray = a.split("after", false)
				val.reverse()
				result.append_array(val)
			else:
				result.append(a)
	
	return result

func _on_input_text_submitted(new_text : String) -> void:
	input.clear()
	
	if new_text.is_empty():
		return
	
	_user_input(new_text)
	
	if in_dialog == true:
		return
	
	for segment in _divide_input_string(new_text):
		var end := false
		for key in local_actions.keys():
			var skip := false
			for i in ignore_actions:
				if i in key:
					skip = true
			
			if skip:
				continue
			
			for option in key.split(":", false):
				if option.length() == 1 and segment.length() != 1:
					continue
				
				var pretest := true
				for word in str(option).split(",", false):
					if !word in segment.to_lower():
						pretest = false
						break
				
				if pretest or option in segment.to_lower():
					await _execute_block(local_actions[key])
					end = true
					break
			if end:
				break
		
		if !end:
			for key in global_actions:
				for option in key.split(":", false):
					if option.length() == 1 and segment.length() != 1:
						continue
					if option in segment.to_lower():
						await _execute_block(global_actions[key])
						end = true
						break
				if end:
					break

func _user_input(text) -> void:
	user_input = text
	output.push_color(input.get_theme_color("font_color"))
	output.add_text("> " + text + "\n")
	input_history.append(text)
	
	for i in local_events.keys():
		if _expression(_subsitute_values(str(i).split(":", false))) == "true":
			_execute_block(local_events[i])
	
	for i in global_events.keys():
		if _expression(_subsitute_values(str(i).split(":", false))) == "true":
			_execute_block(global_events[i])

func _print_message(text : String, color : Color = active_color) -> void:
	if Global.settings["AllowTextColorOverride"] == true:
		output.push_color(color)
	else:
		output.push_color(Global.settings["DefaultTextColor"])
	
	if Global.settings["EnableTTS"] == true and !DisplayServer.tts_get_voices().is_empty():
		DisplayServer.tts_speak(text, DisplayServer.tts_get_voices_for_language("en")[0])
	
	output.add_text(text + "\n")

func _exit_tree() -> void:
	if DisplayServer.tts_is_speaking():
		DisplayServer.tts_stop()

func _execute() -> void:
	local_actions.clear()
	local_autos.clear()
	local_dialogs.clear()
	local_events.clear()
	section_data.clear()
	_run_script(sections[current_section])

func _subsitute_values(text : PackedStringArray) -> PackedStringArray:
	var final_text : PackedStringArray = []
	for s in text.size():
		var segment := text[s]
		for i in information.get_children():
			if i is SingleItem:
				segment = segment.replace("$" + i.name, i.get_value())
			elif i is ListItem:
				for item in i.Value.keys():
					segment = segment.replace("$" + i.name + ":" + item, i.get_value([item]))
				segment = segment.replace("$" + i.name, i.get_value())
			elif i is InventoryItem:
				for item in i.Value.keys():
					segment = segment.replace("$" + i.name + ":" + item, str(i.get_quantity(item)))
				segment = segment.replace("$" + i.name, i.get_value_string())
		
		for i in section_data.keys():
			segment = segment.replace("@" + i, section_data[i])
		
		final_text.push_back(segment)
	
	return final_text

func _execute_block(block : Array) -> void:
	if block.is_empty():
		return
	
	for current_statement in block:
		var statement : PackedStringArray = current_statement.duplicate()
		var commands := []
		var current_command : PackedStringArray = []
		
		while !statement.is_empty():
			if statement[0] == "|":
				commands.push_back(current_command.duplicate())
				current_command.clear()
			else:
				current_command.push_back(statement[0])
			
			statement.remove_at(0)
		
		if !current_command.is_empty():
			commands.push_back(current_command.duplicate())
			current_command.clear()
		
		for command in commands:
			if command.is_empty():
				continue
			
			if await _run_command(_subsitute_values(command)) == false:
				break

func _run_script(script : Array) -> bool:
	var in_block := false
	var is_local := true
	var block_type := ""
	var block_key := ""
	
	for l in script.size() - 1:
		var statement : PackedStringArray = script[l]
		
		if statement.is_empty():
			continue
		
		if statement[0] == "begin":
			in_block = true
			
			if statement[1] == "local":
				is_local = true
			elif statement[1] == "global":
				is_local = false
			else:
				_print_message("Invalid scope: " + str(statement[1]), Color.RED)
				return false
			
			if statement[2] in ["auto", "action", "dialogue", "event"]:
				block_type = statement[2]
			else:
				_print_message("Invalid block type: " + str(statement[2]), Color.RED)
				return false
			
			if block_type != "auto":
				statement.remove_at(0)
				statement.remove_at(0)
				statement.remove_at(0)
				
				if block_type != "dialogue":
					for i in statement:
						block_key += i + ":"
					
					block_key.left(block_key.length() - 1)
				else:
					block_key = statement[0]
				
				if is_local:
					if block_type == "action":
						local_actions[block_key] = []
					elif block_type == "dialogue":
						local_dialogs[block_key] = []
					elif block_type == "event":
						local_events[block_key] = []
				else:
					if block_type == "action":
						global_actions[block_key] = []
					elif block_type == "dialogue":
						global_dialogs[block_key] = []
					elif block_type == "event":
						global_events[block_key] = []
		elif statement[0] == "end":
			in_block = false
			block_key = ""
			block_type = ""
		elif in_block:
			if is_local:
				if block_type == "auto":
					local_autos.append(statement)
				elif block_type == "action":
					local_actions[block_key].append(statement)
				elif block_type == "dialogue":
					local_dialogs[block_key].append(statement)
				elif block_type == "event":
					local_events[block_key].append(statement)
			else:
				if block_type == "auto":
					global_autos.append(statement)
				elif block_type == "action":
					global_actions[block_key].append(statement)
				elif block_type == "dialogue":
					global_dialogs[block_key].append(statement)
				elif block_type == "event":
					global_events[block_key].append(statement)
	
	await _execute_block(local_autos)
	await _execute_block(global_autos)
	
	return true

func _run_dialog(block : Array) -> void:
	while in_dialog == true:
		await input.text_submitted
		_execute_block(block)

const order := ["*", "/", "+", "-", "<", "<=", ">", ">=", "==", "!=", "in", "not in", "and", "or", "="]

func _sort_operators(expression : PackedStringArray) -> PackedStringArray:
	var result := []
	var stack := []
	var new_expression := []
	
	var x := 0
	while x < expression.size():
		if expression[x] == "not" and expression[x + 1] == "in":
			new_expression.append("not in")
			x += 2
			continue
		else:
			new_expression.append(expression[x])
		
		x += 1
	
	for i in new_expression:
		if i == "":
			stack.push_back(i)
			continue
		
		if i in order:
			while !stack.is_empty():
				var token : String = stack.back()
				stack.pop_back()
				
				if token in order and order.find(token) > order.find(i):
					stack.push_back(token)
					break
				
				result.push_back(token)
				
			stack.push_back(i)
		else:
			stack.push_back(i)
	
	while !stack.is_empty():
		result.push_back(stack.back())
		stack.pop_back()
	
	return result

func _expression(expression : PackedStringArray) -> String:
	var stack := []
	var b := "0"
	var a := "0"
	
	var sorted_expression : PackedStringArray = _sort_operators(expression)
	
	for i in sorted_expression:
		if i in order:
			b = stack.back()
			stack.pop_back()
			a = stack.back()
			stack.pop_back()
		
		match i:
			"+":
				stack.push_back(str(float(a) + float(b)))
			"-":
				stack.push_back(str(float(a) - float(b)))
			"*":
				stack.push_back(str(float(a) * float(b)))
			"/":
				if float(b) == 0:
					stack.push_back("0")
				else:
					stack.push_back(str(float(a) / float(b)))
			"<":
				if float(a) < float(b):
					stack.push_back("true")
				else:
					stack.push_back("false")
			"<=":
				if float(a) <= float(b):
					stack.push_back("true")
				else:
					stack.push_back("false")
			">":
				if float(a) > float(b):
					stack.push_back("true")
				else:
					stack.push_back("false")
			">=":
				if float(a) >= float(b):
					stack.push_back("true")
				else:
					stack.push_back("false")
			"==":
				if a == b:
					stack.push_back("true")
				else:
					stack.push_back("false")
			"!=":
				if a != b:
					stack.push_back("true")
				else:
					stack.push_back("false")
			"and":
				if a == "true" and b == "true":
					stack.push_back("true")
				else:
					stack.push_back("false")
			"or":
				if a == "true" or b == "true":
					stack.push_back("true")
				else:
					stack.push_back("false")
			"=":
				var a_name := str(a).split(":")[0]
				
				if information.has_node(a_name):
					if information.get_node(a_name) is SingleItem:
						information.get_node(a_name).set_value(b)
					elif information.get_node(a_name) is ListItem or information.get_node(a_name) is InventoryItem:
						information.get_node(a_name).equal(a.split(":")[-1], int(b))
				elif section_data.has(a_name):
					section_data[a_name] = b
			"in", "not in":
				if information.has_node(b):
					if information.get_node(b) is ListItem or information.get_node(b) is InventoryItem:
						if a in information.get_node(b).Value.keys():
							stack.push_back("true")
						else:
							stack.push_back("false")
					else:
						stack.push_back("false")
				else:
					stack.push_back("false")
				
				if i == "not in":
					if stack.back() == "true":
						stack.pop_back()
						stack.push_back("false")
					else:
						stack.pop_back()
						stack.push_back("true")
			_:
				stack.push_back(i)
	
	if stack.is_empty():
		return ""
	
	return stack.back()

func _error(message : String) -> void:
	_print_message("ERROR: " + message, Color.RED)

var executing_block : bool = false

func _run_command(line : PackedStringArray) -> bool:
	var command := line[0]
	var args := line.duplicate()
	args.remove_at(0)
	
	match command:
		"item":
			if args.size() < 2:
				_error("Expected 2 arguments.")
				return false
			
			var item := single_item.instantiate()
			item.name = args[0]
			item.Value = args[1]
			information.add_child(item)
		"list":
			if args.size() < 1:
				_error("Expected at least 1 argument.")
				return false
			
			var list := list_item.instantiate()
			list.name = args[0]
			args.remove_at(0)
			
			var current_item := ""
			var quantity := 0
			
			while !args.is_empty():
				current_item = args[0]
				args.remove_at(0)
				
				if !args.is_empty():
					if str(args[0]).is_valid_int():
						quantity = int(args[0])
						args.remove_at(0)
					else:
						quantity = 0
				
				if !current_item.is_empty():
					list.append(current_item, quantity)
			
			information.add_child(list)
		"inventory":
			if args.size() < 1:
				_error("Expected at least 1 argument.")
				return false
			
			var list := inventory_item.instantiate()
			list.name = args[0]
			args.remove_at(0)
			
			var current_item := ""
			var quantity := 0
			
			while !args.is_empty():
				current_item = args[0]
				args.remove_at(0)
				
				if !args.is_empty():
					if str(args[0]).is_valid_int():
						quantity = int(args[0])
						args.remove_at(0)
					else:
						quantity = 0
				
				if !current_item.is_empty():
					list.put(current_item, quantity)
			
			information.add_child(list)
		"insert", "drop":
			var list_name := args[0]
			if information.has_node(list_name):
				var list := information.get_node(list_name)
				args.remove_at(0)
				
				var current_item := ""
				var quantity := 0
				while !args.is_empty():
					current_item = args[0]
					args.remove_at(0)
					
					var good := true
					
					if !args.is_empty():
						if str(args[0]).is_valid_int():
							quantity = int(args[0])
							args.remove_at(0)
						else:
							good = false
					else:
						good = false
					
					if !good:
						if list is ListItem:
							quantity = 0
						else:
							quantity = 1
					
					if !current_item.is_empty():
						if list is ListItem:
							if command == "insert":
								list.append(current_item, quantity)
							elif command == "drop":
								list.remove(current_item, quantity)
						elif list is InventoryItem:
							if command == "insert":
								list.put(current_item, quantity)
							elif command == "drop":
								list.drop(current_item, quantity)
			else:
				_error("Item not found: " + list_name)
				return false
		"drop-all":
			var list_name := args[0]
			if information.has_node(list_name):
				var list := information.get_node(list_name)
				
				if list is ListItem:
					list.clear_all()
				elif list is InventoryItem:
					list.clear()
			else:
				_error("Item not found: " + list_name)
				return false
		"say":
			if args.size() < 1:
				_error("Expected at least 1 argument.")
				return false
			
			for i in args:
				_print_message(i)
		"move":
			if args.size() < 1:
				_error("Expected 1 argument.")
				return false
			
			current_section = args[0]
			emit_signal("change_section")
		"delete":
			if args.size() < 1:
				_error("Expected 1 argument.")
				return false
			
			if information.has_node(args[0]):
				information.get_node(args[0]).queue_free()
		"input":
			if args.size() < 1:
				_error("Expected 1 argument.")
				return false
			
			await input.text_submitted
			
			var key := str(args[0]).split(":", false)
			
			if information.has_node(key[0]):
				var item = information.get_node(key[0])
				
				if item is SingleItem:
					item.set_value(user_input)
				elif item is ListItem:
					item.append(user_input)
				elif item is InventoryItem:
					item.put(key[1])
		"color":
			if args.size() < 1:
				_error("Expected 1 argument.")
				return false
			
			_print_message(args[0])
			
			if args[0].find(","):
				var color = args[0].split(",")
				if color.size() == 3:
					if !color[0].is_valid_float() or !color[1].is_valid_float() or !color[2].is_valid_float():
						_error("RGB values are invalid")
						return false
					
					var r = float(color[0])
					var g = float(color[1])
					var b = float(color[2])
					
					active_color = Color(r, g, b)
			else:
				active_color = Color(args[0])
		"default":
			if args.size() < 1:
				_error("Expected 1 argument.")
				return false
			
			match args[0]:
				"color":
					active_color = Global.settings["DefaultTextColor"]
		"disable":
			if args.size() < 1:
				_error("Expected 1 argument.")
				return false
			
			ignore_actions.append(args[0])
		"enable":
			if args.size() < 1:
				_error("Expected 1 argument.")
				return false
			
			var index := ignore_actions.find(args[0])
			
			if index >= 0:
				ignore_actions.remove_at(index)
		"if":
			if args.size() < 1:
				_error("Expected at least 1 argument.")
				return false
			
			if _expression(args) == "true":
				return true
			return false
		"case":
			if args.size() < 1:
				_error("Expected at least 1 argument.")
				return false
			
			for i in args:
				var succeed := true
				for a in i.split(",", false):
					if !a in user_input:
						succeed = false
						break
				
				if succeed:
					return true
			
			return false
		"enter-dialogue":
			if args.size() < 1:
				_error("Expected 1 argument.")
				return false
			
			if args[0] in local_dialogs.keys():
				in_dialog = true
				_run_dialog(local_dialogs[args[0]])
			elif args[0] in global_dialogs.keys():
				in_dialog = true
				_run_dialog(global_dialogs[args[0]])
			else:
				_print_message("Dialog not found", Color.RED)
				return false
		"leave-dialogue":
			if args.size() > 0:
				_error("Expected no arguments.")
				return false
			
			in_dialog = false
		"create":
			if args.size() < 1:
				_error("Expected at least 2 arguments.")
				return false
			
			var key := args[0]
			var value := args[1]
			section_data[key] = value
		"eval":
			if args.size() < 1:
				_error("Expected at least 1 argument.")
				return false
			
			_expression(args)
		"image":
			if args.size() < 1:
				_error("Expected 1 argument.")
				return false
			
			var img_name := args[0]
			img_name = Global.game_directory + "/images/" + img_name
			
			if !FileAccess.file_exists(img_name):
				_error("File not found.\n" + img_name)
				return false
			
			var image := Image.load_from_file(img_name)
			background_image.texture = ImageTexture.create_from_image(image)
		"sound", "music":
			if args.size() < 1:
				_error("Expected 1 argument.")
				return false
			
			var sound_name := args[0]
			sound_name = Global.game_directory + "/sound/" + sound_name
			
			if !FileAccess.file_exists(sound_name):
				_error("File not found.\n" + sound_name)
				return false
			
			var stream
			
			match sound_name.get_extension():
				"wav", "wave":
					var data := FileAccess.get_file_as_bytes(sound_name)
					stream = AudioStreamWAV.new()
					stream.data = data
					stream.format = AudioStreamWAV.FORMAT_16_BITS
					stream.stereo = true
				"mp3":
					var data := FileAccess.get_file_as_bytes(sound_name)
					stream = AudioStreamMP3.new()
					stream.data = data
				_:
					_error("Unsupported audio format.")
			
			var player := AudioStreamPlayer.new()
			player.stream = stream
			add_child(player)
			
			if command == "sound":
				player.connect("finished", player.queue_free)
			else:
				player.connect("finished", player.play)
			
			player.play()
		"run":
			if executing_block == true:
				_error("Cannot run a block while inside a block.")
				return false
			elif args.is_empty():
				_error("Block name not provided.")
				return false
			elif !blocks.has(args[0]):
				_error("Block " + args[0] + " not declared.")
				return false
			else:
				executing_block = true
				_execute_block(blocks[args[0]])
				executing_block = false
		_:
			_print_message("Unknown command: " + command, Color.RED)
			return false
	
	return true
