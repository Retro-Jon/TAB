extends VBoxContainer
class_name ListItem

# item : number
var Value : Dictionary = {}

func append(item : String, count : int = 1) -> void:
	if Value.has(item):
		Value[item] += count
	else:
		Value[item] = count
	_update()

func remove(item : String, count : int = 1) -> void:
	if Value.has(item):
		Value[item] -= count
		_update()

func equal(item : String, count : int = 1) -> void:
	Value[item] = count
	_update()

func clear(item : String) -> void:
	Value.erase(item)
	_update()

func clear_all() -> void:
	Value.clear()
	_update()

func get_value(keys : PackedStringArray = []) -> String:
	var result : String = ""
	
	if keys.is_empty():
		for i in Value:
			result += str(i) + ", "
		result = result.left(result.length() - 2)
	else:
		for i in keys:
			if Value.has(i):
				result += str(Value[i]) + ", "
			else:
				result += "0, "
		result = result.left(result.length() - 2)
	
	return result

func _update() -> void:
	$Label.text = name
	var Key : ItemList = $Data/Key
	var Quantity : ItemList = $Data/Quantity
	
	Key.clear()
	Quantity.clear()
	
	for item in Value.keys():
		Key.add_item(str(item), null, false)
		Quantity.add_item(str(Value[item]), null, false)
