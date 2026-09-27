extends CharacterBody2D

@export_group("Heart HUD Settings")
@export var max_health: float = 3.0       
@export var iframe_duration: float = 0.6  
@export var flash_duration: float = 0.15 

@export_group("Movement & Combat")
@export var speed: float = 100.0
@export var attack_damage: float = 25.0
@export var knockback_force: float = 200.0 
@export var combo_reset_time: float = 1.0 
@export var third_hit_multiplier: float = 1.75

# --- INPUT BUFFERING ---
var attack_buffered: bool = false
var buffer_window_active: bool = false

# --- COMBO TRACKING ---
var combo_step: int = 1         
var last_attack_time: float = 0.0

@onready var sprite = $AnimatedSprite2D
@onready var attack_hitbox_collision = $AttackPivot/PlayerHitbox/CollisionShape2D
@onready var attack_pivot = $AttackPivot
@onready var health_bar = $PlayerHealthBar # <--- REFERENCE THE NEW GREEN BAR

var is_dead: bool = false
var current_health: float
var is_attacking: bool = false
var is_invincible: bool = false 


func _ready() -> void:
	add_to_group("player") 
	
	if GlobalManager.selected_sprite_frames != null:
		sprite.sprite_frames = GlobalManager.selected_sprite_frames

	current_health = max_health
	
	# Initialize the green bar to full health dynamically
	if has_node("PlayerHealthBar"):
		health_bar.max_value = max_health
		health_bar.value = current_health

	if attack_hitbox_collision:
		attack_hitbox_collision.disabled = true

	await get_tree().physics_frame
	execute_fade_in_effect()


func _physics_process(_delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var current_time = Time.get_ticks_msec() / 1000.0
	if combo_step > 1 and (current_time - last_attack_time) > combo_reset_time:
		combo_step = 1

	if Input.is_action_just_pressed("attack"):
		if not is_attacking:
			attack()
		elif buffer_window_active:
			attack_buffered = true 

	var input_direction = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)

	if not is_attacking:
		velocity = input_direction * speed
		move_and_slide()
		update_animation(input_direction)
	else:
		# ALL ATTACKS WALKING BLEED
		var attack_walk_speed_multiplier = 0.45 
		velocity = input_direction * (speed * attack_walk_speed_multiplier)
		move_and_slide()
		
		if input_direction.x > 0:
			sprite.flip_h = false
			attack_pivot.scale.x = 1
		elif input_direction.x < 0:
			sprite.flip_h = true
			attack_pivot.scale.x = -1


func attack() -> void:
	if is_dead: return
	is_attacking = true
	attack_buffered = false
	buffer_window_active = false
	
	var anim_name = "attack"
	if combo_step == 2:
		anim_name = "attack2"
	elif combo_step == 3:
		anim_name = "attack3"
		
	if sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
	else:
		sprite.play("attack")
	
	last_attack_time = Time.get_ticks_msec() / 1000.0

	if combo_step >= 3:
		combo_step = 1
	else:
		combo_step += 1

	if attack_hitbox_collision:
		attack_hitbox_collision.set_deferred("disabled", false)
		
	await get_tree().create_timer(0.15).timeout
	buffer_window_active = true 
	await sprite.animation_finished
	
	if attack_hitbox_collision:
		attack_hitbox_collision.set_deferred("disabled", true)
		
	is_attacking = false
	if attack_buffered:
		attack()


func trigger_hit_stop(duration: float) -> void:
	Engine.time_scale = 0.05 
	await get_tree().create_timer(duration * 0.05).timeout
	Engine.time_scale = 1.0 


func trigger_camera_shake(intensity: float) -> void:
	get_tree().call_group("camera", "apply_shake", intensity)


func _on_player_hitbox_body_entered(body: Node2D) -> void:
	if is_dead: return
	if body.has_method("take_damage") and body != self:
		var knockback_direction = (body.global_position - global_position).normalized()
		var calculated_damage = attack_damage
		var calculated_knockback_force = knockback_force
		
		if sprite.animation == "attack3":
			calculated_damage = attack_damage * third_hit_multiplier
			calculated_knockback_force = knockback_force * 1.8
			trigger_hit_stop(0.12)
			trigger_camera_shake(8.0)
		else:
			trigger_hit_stop(0.06)
			trigger_camera_shake(3.0)
		
		var total_knockback = knockback_direction * calculated_knockback_force
		body.take_damage(calculated_damage, total_knockback)


func take_damage(amount: float) -> void:
	if is_invincible or is_dead or current_health <= 0:
		return
		
	is_invincible = true
	current_health -= amount
	print("Player hit! Health remaining: ", current_health)
	
	# Visibly lower the green health bar value on impact damage
	if has_node("PlayerHealthBar"):
		health_bar.value = current_health
	
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


func die() -> void:
	print("Player has died!")
	is_dead = true
	velocity = Vector2.ZERO
	
	# Hide the green bar immediately when you drop dead
	if has_node("PlayerHealthBar"):
		health_bar.visible = false
	
	$CollisionShape2D.set_deferred("disabled", true) if has_node("CollisionShape2D") else null
	if has_node("Hurtbox/CollisionShape2D"):
		$Hurtbox/CollisionShape2D.set_deferred("disabled", true)
	
	sprite.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
	sprite.modulate.a = 1.0
	
	if sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
		await sprite.animation_finished
		sprite.pause() 
	
	await get_tree().create_timer(0.5).timeout
	execute_fade_out_and_restart()


func execute_fade_out_and_restart() -> void:
	var fade_nodes = get_tree().get_nodes_in_group("fade_screen")
	if fade_nodes.size() > 0:
		var target_rect = fade_nodes[0] as ColorRect
		var tween = create_tween()
		tween.tween_property(target_rect, "modulate:a", 1.0, 1.0)
		await tween.finished
		
	get_tree().reload_current_scene()


func execute_fade_in_effect() -> void:
	var fade_nodes = get_tree().get_nodes_in_group("fade_screen")
	if fade_nodes.size() > 0:
		var target_rect = fade_nodes[0] as ColorRect
		target_rect.modulate.a = 1.0
		var tween = create_tween()
		tween.tween_property(target_rect, "modulate:a", 0.0, 1.0)


func update_animation(direction: Vector2) -> void:
	if is_dead or is_attacking: return
	if direction.x > 0:
		sprite.flip_h = false
		attack_pivot.scale.x = 1
	elif direction.x < 0:
		sprite.flip_h = true
		attack_pivot.scale.x = -1

	if direction == Vector2.ZERO:
		sprite.play("idle")
	else:
		sprite.play("walk")
