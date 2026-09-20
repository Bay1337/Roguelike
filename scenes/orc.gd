extends CharacterBody2D

@export var speed: float = 60.0
@export var attack_range: float = 24.0
@export var attack_cooldown: float = 1.0

@onready var sprite = $AnimatedSprite2D
@onready var detection_area = $DetectionArea

enum State { IDLE, CHASE, ATTACK }
var state: State = State.IDLE

var player: Node2D = null
var can_attack: bool = true


func _ready() -> void:
	detection_area.body_entered.connect(_on_detection_area_body_entered)
	detection_area.body_exited.connect(_on_detection_area_body_exited)


func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body
		state = State.CHASE


func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == player:
		player = null
		state = State.IDLE


func _physics_process(_delta: float) -> void:
	match state:
		State.IDLE:
			velocity = Vector2.ZERO
			update_animation(Vector2.ZERO)

		State.CHASE:
			if player == null:
				state = State.IDLE
				return

			var to_player = player.global_position - global_position
			var distance = to_player.length()

			if distance <= attack_range:
				state = State.ATTACK
				velocity = Vector2.ZERO
			else:
				var direction = to_player.normalized()
				velocity = direction * speed
				update_animation(direction)

		State.ATTACK:
			velocity = Vector2.ZERO
			if player == null:
				state = State.IDLE
				return

			# Keep facing the player while attacking
			var to_player = player.global_position - global_position
			update_animation(Vector2(to_player.x, 0))

			if can_attack:
				attack()

			# If player walks back out of attack range, resume chasing
			if to_player.length() > attack_range:
				state = State.CHASE

	move_and_slide()


func attack() -> void:
	can_attack = false
	sprite.play("attack")
	
	# Wait for the attack animation to finish playing
	await sprite.animation_finished
	
	# Enforce the attack cooldown duration
	await get_tree().create_timer(attack_cooldown).timeout
	
	can_attack = true


func update_animation(direction: Vector2) -> void:
	if direction.x > 0:
		sprite.flip_h = false
	elif direction.x < 0:
		sprite.flip_h = true

	if state == State.ATTACK:
		return  # attack() handles its own animation

	if direction == Vector2.ZERO:
		sprite.play("idle")
	else:
		sprite.play("walk")


func _on_hitbox_body_entered(body: Node2D) -> void:
	pass # Replace with function body.
