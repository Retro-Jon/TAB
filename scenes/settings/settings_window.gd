extends Control

@onready var SettingValue : VBoxContainer = $ScrollContainer/HBoxContainer/Value

func _ready() -> void:
	hide()

func _on_cancel_pressed() -> void:
	hide()

func _on_save_pressed() -> void:
	for i in SettingValue.get_children():
		if i is ColorPickerButton:
			Global.settings[i.name] = i.color
		elif i is CheckButton:
			Global.settings[i.name] = i.button_pressed
	
	Global._save_settings_file()
	hide()

func _open() -> void:
	show()
	for i in SettingValue.get_children():
		if i is ColorPickerButton:
			i.color = Global.settings[i.name]
		elif i is CheckButton:
			i.button_pressed = Global.settings[i.name]
