extends CharacterBody2D

@export var speed: float = 100.0

@onready var sprite = $AnimatedSprite2D

func _physics_process(_delta: float) -> void:
	var input_direction = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)

	velocity = input_direction * speed
	move_and_slide()

	update_animation(input_direction)


func update_animation(direction: Vector2) -> void:
	if direction.x > 0:
		sprite.flip_h = false
	elif direction.x < 0:
		sprite.flip_h = true

	if direction == Vector2.ZERO:
		sprite.play("idle")
	else:
		sprite.play("walk")
