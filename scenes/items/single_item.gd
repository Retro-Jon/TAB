extends HBoxContainer
class_name SingleItem

var Value : String = ""

func _ready() -> void:
	_update()

func set_value(item : String) -> void:
	Value = item
	_update()

func get_value() -> String:
	return Value

func _update() -> void:
	$Label.text = name
	$Value.text = Value
