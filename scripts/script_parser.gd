extends Node

signal ParseComplete(sections : Dictionary, blocks : Dictionary)
signal UpdateProgress(progress : float)

func _parse(code : String) -> void:
	if code.is_empty():
		call_deferred("emit_signal", "ParseComplete", {})
	
	var sections : Dictionary = {}
	var blocks : Dictionary = {}
	var in_section : bool = true # false if in block
	
	var current : String = ""
	var command : PackedStringArray = []
	var tokens : PackedStringArray = []
	var temp : PackedStringArray = code.split("\n")
	var progress : float = 0
	
	for i in temp:
		tokens.append_array(i.split(" "))
		tokens.append("\n")
		progress += 1000.0 / temp.size()
		call_deferred("emit_signal", "UpdateProgress", progress)
	
	var index : int = 0
	progress = 0
	while !tokens.is_empty() and index < tokens.size():
		if tokens[index].replace(" ", "").replace("\t", "").is_empty():
			tokens.remove_at(index)
			continue
		
		index += 1
	
	var in_comment : bool = false
	
	for i in tokens.size():
		var t : String = tokens[i]
		t = t.replace("\t", "")
		
		if t.begins_with("#"):
			in_comment = true
		elif in_comment:
			if t.ends_with("\n"):
				in_comment = false
			else:
				continue
		
		if t.begins_with(".section"):
			in_section = true
			current = ""
		elif t.begins_with(".block"):
			in_section = false
			current = ""
		elif current.is_empty():
			current = t
			if in_section:
				sections[current] = []
			else:
				blocks[current] = []
		elif t.begins_with("("):
			command = [t.replace("(", "").replace(")", "").replace("\"", "").replace("\n", "")]
			
			var in_string : bool = false
			t = ""
			
			while !tokens[i].ends_with(")") and i < tokens.size() - 1:
				i += 1
				t += tokens[i].replace(")", "").replace("\t", "")
				
				if t.begins_with("\"") and !t.begins_with("\\\""):
					in_string = true
				if t.ends_with("\"") and !t.ends_with("\\\""):
					in_string = false
				
				if !in_string:
					if command.size() == 1 and t == "\n":
						t = ""
						continue
					
					if t.is_empty():
						continue
					
					if t.begins_with("\""):
						t = t.right(t.length() - 1)
					
					if t.ends_with("\"") and !t.ends_with("\\\""):
						t = t.left(t.length() - 1)
					
					command.append(t.replace("\\\"", "\""))
					
					t = ""
				elif !t.is_empty() and !t.ends_with("\n"):
					t += " "
			
			if !command.is_empty():
				if in_section:
					sections[current].append(command.duplicate())
				else:
					blocks[current].append(command.duplicate())
			
			command.clear()
		
		if i > 0:
			progress = 1000 - (1000.0 / i)
		else:
			progress = 0
		
		call_deferred("emit_signal", "UpdateProgress", progress)
	
	progress = 1000
	call_deferred("emit_signal", "UpdateProgress", progress)
	call_deferred("emit_signal", "ParseComplete", sections, blocks)
