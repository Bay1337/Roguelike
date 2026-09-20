extends CharacterBody2D

@export_group("Heart HUD Settings")
@export var max_health: float = 3.0       
@export var iframe_duration: float = 0.6  
@export var flash_duration: float = 0.15 

@export_group("Movement & Combat")
@export var speed: float = 100.0
@export var attack_damage: float = 25.0
@export var knockback_force: float = 200.0 

@onready var sprite = $AnimatedSprite2D
@onready var attack_hitbox_collision = $AttackPivot/PlayerHitbox/CollisionShape2D
@onready var attack_pivot = $AttackPivot

var is_dead: bool = false
var current_health: float
var is_attacking: bool = false
var is_invincible: bool = false 


func _ready() -> void:
	current_health = max_health
	if attack_hitbox_collision:
		attack_hitbox_collision.disabled = true
	add_to_group("player")
	
	# Handle fading back into clarity on startup
	await get_tree().physics_frame
	sync_hud_ui()
	execute_fade_in_effect()


func _physics_process(_delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

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
	if is_dead: return
	is_attacking = true
	sprite.play("attack")
	
	if attack_hitbox_collision:
		attack_hitbox_collision.set_deferred("disabled", false)
		
	await sprite.animation_finished
	
	if attack_hitbox_collision:
		attack_hitbox_collision.set_deferred("disabled", true)
		
	is_attacking = false


func take_damage(amount: float) -> void:
	if is_invincible or is_dead or current_health <= 0:
		return
		
	is_invincible = true
	current_health -= amount
	print("Player hit! Hearts remaining: ", current_health)
	
	sync_hud_ui()
	
	if current_health <= 0:
		die()
	else:
		play_hurt_iframe_loop()


func play_hurt_iframe_loop() -> void:
	if is_dead: return
	sprite.self_modulate = Color(5.0, 5.0, 5.0, 1.0)
	await get_tree().create_timer(flash_duration).timeout
	sprite.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
	
	for i in range(4):
		if is_dead: break 
		sprite.modulate.a = 0.2
		await get_tree().create_timer(0.05).timeout
		sprite.modulate.a = 1.0
		await get_tree().create_timer(0.05).timeout
		
	is_invincible = false


func sync_hud_ui() -> void:
	get_tree().call_group("hud", "update_hearts", current_health, max_health)


func die() -> void:
	print("Player has died!")
	is_dead = true
	velocity = Vector2.ZERO
	
	$CollisionShape2D.set_deferred("disabled", true) if has_node("CollisionShape2D") else null
	if has_node("Hurtbox/CollisionShape2D"):
		$Hurtbox/CollisionShape2D.set_deferred("disabled", true)
	
	sprite.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
	sprite.modulate.a = 1.0
	
	if sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
		await sprite.animation_finished
		sprite.pause() 
	
	# Give the player a quick second to register their death frame visually
	await get_tree().create_timer(0.5).timeout
	
	# Begin the fade out and scene reset logic sequence
	execute_fade_out_and_restart()


func execute_fade_out_and_restart() -> void:
	var fade_nodes = get_tree().get_nodes_in_group("fade_screen")
	if fade_nodes.size() > 0:
		var target_rect = fade_nodes[0] as ColorRect
		
		# Create an interpolation tween animation timeline step to fade out smoothly over 1.0 second
		var tween = create_tween()
		tween.tween_property(target_rect, "modulate:a", 1.0, 1.0)
		await tween.finished
		
	# Completely reload the current scene layout smoothly from scratch
	get_tree().reload_current_scene()


func execute_fade_in_effect() -> void:
	var fade_nodes = get_tree().get_nodes_in_group("fade_screen")
	if fade_nodes.size() > 0:
		var target_rect = fade_nodes[0] as ColorRect
		
		# Set to completely solid black instantly on map layer generation
		target_rect.modulate.a = 1.0
		
		# Transition from black back to clear visibility over 1.0 second
		var tween = create_tween()
		tween.tween_property(target_rect, "modulate:a", 0.0, 1.0)


func update_animation(direction: Vector2) -> void:
	if is_dead: return

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
	if is_dead: return
	if body.has_method("take_damage") and body != self:
		var knockback_direction = (body.global_position - global_position).normalized()
		var total_knockback = knockback_direction * knockback_force
		
		body.take_damage(attack_damage, total_knockback)
