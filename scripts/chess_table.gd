extends Area2D

# FIX: Hardcode the resource path directly as a default value inside the script!
@export var chess_scene: PackedScene = preload("res://scenes/chess_game.tscn")

@onready var prompt_label = $Label 


var player_in_range: bool = false
var active_game_instance: Node = null


func _ready() -> void:
	# Clean slate initialization pass
	if prompt_label:
		prompt_label.visible = false



func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and active_game_instance == null:
		player_in_range = true
		if prompt_label:
			prompt_label.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		if prompt_label:
			prompt_label.visible = false


# FIX: We use _input() here combined with single-tick action filters.
# This guarantees the function code runs EXACTLY ONCE per keyboard press event!
func _input(event: InputEvent) -> void:
	if player_in_range and active_game_instance == null:
		# Check if the player pressed E or the custom input map action
		if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and event.keycode == KEY_E):
			# Stop the input event from propagating further down to other nodes like the joystick
			get_viewport().set_input_as_handled()
			open_chess_mini_game()


func open_chess_mini_game() -> void:
	player_in_range = false
	if prompt_label:
		prompt_label.visible = false
	
	# Freeze your player character node movement updates safely
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		players[0].set_physics_process(false)
	
	# Instance and overlay the chess canvas layer over your test room viewport map
	active_game_instance = chess_scene.instantiate()
	get_tree().root.add_child(active_game_instance)
	
	# FIX: Use tree_exiting so the global game tree remains safely accessible!
	active_game_instance.tree_exiting.connect(_on_chess_game_closed)



func _on_chess_game_closed() -> void:
	active_game_instance = null
	
	# Unfreeze the player character node automatically, restoring room navigation controls
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		players[0].set_physics_process(true)
