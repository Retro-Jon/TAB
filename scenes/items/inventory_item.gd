extends VBoxContainer
class_name InventoryItem

# item : number
var Value : Dictionary = {}

func put(item : String, count : int = 1) -> void:
	if Value.has(item):
		Value[item] += count
	else:
		Value[item] = count
	_update()

func equal(item : String, count : int = 1) -> void:
	Value[item] = count
	_update()

func drop(item : String, count : int = 1) -> void:
	if Value.has(item):
		Value[item] -= count
		_update()

func drop_all(item : String) -> void:
	Value.erase(item)
	_update()

func clear() -> void:
	Value.clear()
	_update()

func get_value_string(keys : PackedStringArray = [], divider : String = ", ") -> String:
	var result : String = ""
	
	if keys.is_empty():
		for i in Value:
			result += str(i) + divider
		result = result.left(result.length() - divider.length())
	else:
		for i in keys:
			if Value.has(i):
				result += str(Value[i]) + divider
		result = result.left(result.length() - divider.length())
	
	return result

func get_quantity(key : String) -> int:
	if Value.has(key):
		return Value[key]
	
	return 0

func _update() -> void:
	$Label.text = name
	var Key : ItemList = $Data/Key
	var Quantity : ItemList = $Data/Quantity
	
	Key.clear()
	Quantity.clear()
	
	for item in Value.keys():
		if Value[item] <= 0:
			Value.erase(item)
			continue
		
		Key.add_item(str(item), null, false)
		Quantity.add_item(str(Value[item]), null, false)
