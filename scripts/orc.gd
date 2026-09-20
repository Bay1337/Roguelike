extends CharacterBody2D

@export var max_health: float = 100.0
@export var speed: float = 60.0
@export var attack_range: float = 32.0
@export var attack_exit_buffer: float = 12.0  # extra distance required to LEAVE attack state, prevents flicker
@export var attack_cooldown: float = 1.0
@export var attack_damage: float = 15.0
@export var hitbox_offset: float = 16.0 

@onready var sprite = $AnimatedSprite2D
@onready var detection_area = $DetectionArea
@onready var hitbox = $Hitbox
@onready var hitbox_collision = $Hitbox/CollisionShape2D

enum State { IDLE, CHASE, ATTACK, DEAD }
var state: State = State.IDLE

var current_health: float
var player: Node2D = null
var can_attack: bool = true
var is_hurting: bool = false
var knockback_velocity: Vector2 = Vector2.ZERO
var attack_id: int = 0


func _ready() -> void:
	current_health = max_health
	hitbox_collision.disabled = true
	
	detection_area.body_entered.connect(_on_detection_area_body_entered)
	detection_area.body_exited.connect(_on_detection_area_body_exited)


func _on_detection_area_body_entered(body: Node2D) -> void:
	if state == State.DEAD: return
	if body.is_in_group("player"):
		player = body
		state = State.CHASE


func _on_detection_area_body_exited(body: Node2D) -> void:
	if state == State.DEAD: return
	if body == player:
		player = null
		state = State.IDLE


func _physics_process(delta: float) -> void:
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 800.0 * delta)

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
			# Stop moving and attack cleanly since collision masks are separated
			velocity = Vector2.ZERO
			if player == null:
				state = State.IDLE
				return

			var to_player = player.global_position - global_position
			update_animation(to_player)

			if can_attack and not is_hurting:
				attack()

			if to_player.length() > attack_range + attack_exit_buffer and not is_hurting:
				state = State.CHASE

		State.DEAD:
			velocity = Vector2.ZERO

	velocity += knockback_velocity
	move_and_slide()


func attack() -> void:
	if state == State.DEAD: return
	if not can_attack: return  # extra guard: never start a second attack on top of one already running
	can_attack = false

	attack_id += 1
	var this_attack_id = attack_id

	sprite.play("attack")
	hitbox_collision.set_deferred("disabled", false)

	# Wait for the ATTACK animation specifically to finish. Using the
	# animation_finished signal here is unreliable because if the orc gets
	# hurt mid-swing, play_hurt_effect() calls sprite.play("hurt"), which
	# hijacks the signal and makes it fire for "hurt" instead of "attack".
	# Polling like this ends the wait correctly whether the attack finished
	# naturally OR got interrupted by another animation.
	while sprite.animation == "attack" and sprite.is_playing():
		await get_tree().process_frame

	hitbox_collision.set_deferred("disabled", true)

	await get_tree().create_timer(attack_cooldown).timeout

	# Only re-enable attacking if THIS coroutine is still the most recent
	# attack. If the orc got hurt mid-swing and a newer attack() has since
	# started, this stale coroutine must not touch can_attack — otherwise
	# two attack cycles run at once and fight over the hitbox's disabled
	# state, which is why only the first hit used to land reliably.
	if state != State.DEAD and attack_id == this_attack_id:
		can_attack = true


func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO) -> void:
	if state == State.DEAD: return
	current_health -= amount
	print("Orc hit! Health remaining: ", current_health)
	
	hitbox_collision.set_deferred("disabled", true)
	knockback_velocity = knockback
	
	if current_health <= 0:
		die()
	else:
		if player != null:
			state = State.CHASE
		play_hurt_effect()


func play_hurt_effect() -> void:
	is_hurting = true
	sprite.play("hurt")
	await sprite.animation_finished
	is_hurting = false


func die() -> void:
	state = State.DEAD
	
	hitbox_collision.set_deferred("disabled", true)
	$CollisionShape2D.set_deferred("disabled", true) 
	
	if sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
		await sprite.animation_finished
		sprite.pause()
	else:
		queue_free()


func update_animation(direction: Vector2) -> void:
	if state == State.DEAD: return

	if direction.x > 0:
		sprite.flip_h = false
		hitbox.position.x = hitbox_offset 
	elif direction.x < 0:
		sprite.flip_h = true
		hitbox.position.x = -hitbox_offset 

	if is_hurting:
		return

	if state == State.ATTACK:
		return

	if direction == Vector2.ZERO:
		sprite.play("idle")
	else:
		sprite.play("walk")


func _on_hitbox_area_entered(area: Area2D) -> void:
	if state == State.DEAD: return
	if area.is_in_group("player_hurtbox"):
		var player_node = area.get_parent()
		if player_node.has_method("take_damage"):
			player_node.take_damage(attack_damage)
