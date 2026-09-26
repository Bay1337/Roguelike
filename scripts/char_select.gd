extends Control

# Preload the distinct SpriteFrames resource assets for your characters
# CHANGE THESE paths to match your actual .tres files or saved resource files!

	#repeat for other characters^
	#
	#
@export var knight_frames: SpriteFrames = preload("res://assets/tres files/knight_frames.tres")

@export var gameplay_scene_path: String = "res://scenes/test_room.tscn"

func _ready() -> void:
		#repeat for other characters:
		#
		#
	$HBoxContainer/KnightButton.pressed.connect(func(): _select_character(knight_frames))
	

func _select_character(frames: SpriteFrames) -> void:
	GlobalManager.selected_sprite_frames = frames
	get_tree().change_scene_to_file(gameplay_scene_path)
