extends Control

# CHANGE THESE paths to match your actual scene file paths
@export var gameplay_scene_path: String = "res://scenes/test_room.tscn"
@export var selection_scene_path: String = "res://scenes/char_select.tscn"

func _ready() -> void:
	# Replace the commas with periods right here:
	$VBoxContainer/StartButton.pressed.connect(_on_start_pressed)
	$VBoxContainer/CharacterButton.pressed.connect(_on_character_pressed)


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(gameplay_scene_path)

func _on_character_pressed() -> void:
	get_tree().change_scene_to_file(selection_scene_path)
