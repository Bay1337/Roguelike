extends CharacterBody2D

@export var max_health: float = 100.0
@export var speed: float = 100.0
@export var attack_damage: float = 25.0
@export var flash_duration: float = 0.15 
@export var knockback_force: float = 200.0 

@onready var sprite = $AnimatedSprite2D
@onready var attack_hitbox_collision = $AttackPivot/PlayerHitbox/CollisionShape2D
@onready var attack_pivot = $AttackPivot

var current_health: float
var is_attacking: bool = false


func _ready() -> void:
	current_health = max_health
	if attack_hitbox_collision:
		attack_hitbox_collision.disabled = true
	add_to_group("player")


func _physics_process(_delta: float) -> void:
	var input_direction = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)

	if Input.is_action_just_pressed("attack") and not is_attacking:
		attack()

	velocity = input_direction * speed
	move_and_slide()

	update_animation(input_direction)


func attack() -> void:
	is_attacking = true
	sprite.play("attack")
	
	if attack_hitbox_collision:
		attack_hitbox_collision.set_deferred("disabled", false)
		
	await sprite.animation_finished
	
	if attack_hitbox_collision:
		attack_hitbox_collision.set_deferred("disabled", true)
		
	is_attacking = false


func take_damage(amount: float) -> void:
	current_health -= amount
	print("Player hit! Health remaining: ", current_health)
	
	if current_health <= 0:
		die()
	else:
		play_flash_effect()


func play_flash_effect() -> void:
	sprite.self_modulate = Color(5.0, 5.0, 5.0, 1.0)
	await get_tree().create_timer(flash_duration).timeout
	sprite.self_modulate = Color(1.0, 1.0, 1.0, 1.0)


func die() -> void:
	print("Player has died!")
	set_physics_process(false)


func update_animation(direction: Vector2) -> void:
	if direction.x > 0:
		sprite.flip_h = false
		attack_pivot.scale.x = 1
	elif direction.x < 0:
		sprite.flip_h = true
		attack_pivot.scale.x = -1

	if is_attacking:
		return 

	if direction == Vector2.ZERO:
		sprite.play("idle")
	else:
		sprite.play("walk")


func _on_player_hitbox_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage") and body != self:
		var knockback_direction = (body.global_position - global_position).normalized()
		var total_knockback = knockback_direction * knockback_force
		
		body.take_damage(attack_damage, total_knockback)
