# virtual_joystick.gd
extends Control

@export_group("Input Actions")
@export var action_left: String = "move_left"
@export var action_right: String = "move_right"
@export var action_up: String = "move_up"
@export var action_down: String = "move_down"

@export_group("Settings")
@export var clamp_zone: float = 60.0
@export var deadzone: float = 0.1

var base_pos: Vector2 = Vector2.ZERO
var tip_pos: Vector2 = Vector2.ZERO
var touch_index: int = -1
var output_vector: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Set a default size if not already set
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(150, 150)
	base_pos = size / 2.0
	tip_pos = base_pos

func _draw() -> void:
	# Draw outer base ring
	draw_circle(base_pos, clamp_zone, Color(0.2, 0.2, 0.2, 0.5))
	# Draw inner tip handle
	draw_circle(tip_pos, clamp_zone * 0.4, Color(0.8, 0.8, 0.8, 0.8))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.is_pressed() and touch_index == -1:
			touch_index = event.index if event is InputEventScreenTouch else 0
			_update_joystick(event.position)
		elif not event.is_pressed() and (event.index == touch_index if event is InputEventScreenTouch else touch_index == 0):
			_reset_joystick()

	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		var current_index = event.index if event is InputEventScreenDrag else 0
		if current_index == touch_index:
			_update_joystick(event.position)

func _update_joystick(touch_pos: Vector2) -> void:
	var vector = touch_pos - base_pos
	
	if vector.length() > clamp_zone:
		vector = vector.normalized() * clamp_zone
		
	tip_pos = base_pos + vector
	queue_redraw()
	
	var raw_output = vector / clamp_zone
	if raw_output.length() < deadzone:
		output_vector = Vector2.ZERO
	else:
		output_vector = raw_output

	_update_input_actions()

func _reset_joystick() -> void:
	touch_index = -1
	tip_pos = base_pos
	queue_redraw()
	output_vector = Vector2.ZERO
	_update_input_actions()

func _update_input_actions() -> void:
	if output_vector.x > 0:
		Input.action_press(action_right, output_vector.x)
		Input.action_release(action_left)
	elif output_vector.x < 0:
		Input.action_press(action_left, -output_vector.x)
		Input.action_release(action_right)
	else:
		Input.action_release(action_left)
		Input.action_release(action_right)

	if output_vector.y > 0:
		Input.action_press(action_down, output_vector.y)
		Input.action_release(action_up)
	elif output_vector.y < 0:
		Input.action_press(action_up, -output_vector.y)
		Input.action_release(action_down)
	else:
		Input.action_release(action_up)
		Input.action_release(action_down)
