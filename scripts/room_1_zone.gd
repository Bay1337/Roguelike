extends Area2D

@export_group("Manual Room Pixel Limits")
@export var left_wall: int = 0
@export var right_wall: int = 1152
@export var top_wall: int = 0
@export var bottom_wall: int = 648


func _ready() -> void:
	# Link the entry signal
	body_entered.connect(_on_player_entered_room)


func _on_player_entered_room(body: Node2D) -> void:
	if body.is_in_group("player"):
		var cameras = get_tree().get_nodes_in_group("main_camera")
		if cameras.size() > 0:
			var cam = cameras[0] as Camera2D
			
			# Force the world camera to lock exactly onto your custom typed room walls
			cam.limit_left = left_wall
			cam.limit_right = right_wall
			cam.limit_top = top_wall
			cam.limit_bottom = bottom_wall
			
			# Slide the viewfinder directly to the exact geometric center of this room
			var center_x = (left_wall + right_wall) / 2.0
			var center_y = (top_wall + bottom_wall) / 2.0
			cam.global_position = Vector2(center_x, center_y)
