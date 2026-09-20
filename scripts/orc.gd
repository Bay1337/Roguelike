extends CharacterBody2D

@export_group("Combat Values")
@export var attack_damage: float = 0.5   # 0.5 = Half Heart, 1.0 = Full Heart, 2.0 = Two Hearts!
@export var attack_cooldown: float = 1.0 # Wait time between swings
@export var attack_range: float = 32.0 
@export var max_health: float = 100.0
@export var speed: float = 60.0

@onready var sprite = $AnimatedSprite2D
@onready var detection_area = $DetectionArea

# Dual-side hitbox tracking nodes
@onready var hitbox_right_collision = $HitboxRight/CollisionShape2D
@onready var hitbox_left_collision = $HitboxLeft/CollisionShape2D

enum State { IDLE, CHASE, DEAD }
var state: State = State.IDLE

var current_health: float
var player: Node2D = null
var cooldown_timer: float = 0.0
var damage_window_active: bool = false


func _ready() -> void:
	current_health = max_health
	
	hitbox_right_collision.disabled = true
	hitbox_left_collision.disabled = true
	
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
	if state == State.DEAD:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if cooldown_timer > 0.0:
		cooldown_timer -= delta

	match state:
		State.IDLE:
			velocity = Vector2.ZERO
			sprite.play("idle")

		State.CHASE:
			if player == null:
				state = State.IDLE
				return

			var to_player = player.global_position - global_position
			var direction = to_player.normalized()
			var distance = to_player.length()
			
			if distance > 12.0:
				velocity = direction * speed
			else:
				velocity = Vector2.ZERO
			
			if distance > 4.0:
				if direction.x > 0:
					sprite.flip_h = false
				elif direction.x < 0:
					sprite.flip_h = true

			if cooldown_timer <= 0.0:
				fire_weapon_swing()

	move_and_slide()


func fire_weapon_swing() -> void:
	cooldown_timer = attack_cooldown
	sprite.play("attack")
	
	damage_window_active = true
	
	var active_collision = hitbox_left_collision if sprite.flip_h else hitbox_right_collision
	active_collision.disabled = false
	
	await get_tree().create_timer(0.2).timeout
	
	damage_window_active = false
	hitbox_right_collision.disabled = true
	hitbox_left_collision.disabled = true
	
	if state == State.CHASE and sprite.animation == "attack":
		sprite.play("walk")


func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO) -> void:
	if state == State.DEAD: return
	current_health -= amount
	print("Orc hit! Health remaining: ", current_health)
	
	damage_window_active = false
	hitbox_right_collision.disabled = true
	hitbox_left_collision.disabled = true
	
	if current_health <= 0:
		die()
	else:
		play_hurt_effect()


func play_hurt_effect() -> void:
	sprite.play("hurt")
	await sprite.animation_finished
	if state == State.CHASE:
		sprite.play("walk")


func die() -> void:
	state = State.DEAD
	damage_window_active = false
	hitbox_right_collision.set_deferred("disabled", true)
	hitbox_left_collision.set_deferred("disabled", true)
	$CollisionShape2D.set_deferred("disabled", true) if has_node("CollisionShape2D") else null
	
	if sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
		await sprite.animation_finished
		sprite.pause()
	else:
		queue_free()


func _on_hitbox_right_area_entered(area: Area2D) -> void:
	_process_damage_dealing(area)


func _on_hitbox_left_area_entered(area: Area2D) -> void:
	_process_damage_dealing(area)


func _process_damage_dealing(area: Area2D) -> void:
	if state == State.DEAD or not damage_window_active: 
		return
		
	if area.is_in_group("player_hurtbox"):
		var player_node = area.get_parent()
		if player_node and player_node.has_method("take_damage"):
			player_node.take_damage(attack_damage)
			damage_window_active = false
