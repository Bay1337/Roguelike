extends CharacterBody2D

@export_group("Heart HUD Settings")
@export var max_health: float = 3.0       
@export var iframe_duration: float = 0.6  
@export var flash_duration: float = 0.15 

@export_group("Movement & Combat")
@export var speed: float = 100.0
@export var attack_damage: float = 25.0
@export var knockback_force: float = 200.0 
@export var combo_reset_time: float = 2.0 
@export var third_hit_multiplier: float = 1.75  # Deals 75% extra damage on the final hit!

@onready var sprite = $AnimatedSprite2D
@onready var attack_hitbox_collision = $AttackPivot/PlayerHitbox/CollisionShape2D
@onready var attack_pivot = $AttackPivot

var is_dead: bool = false
var current_health: float
var is_attacking: bool = false
var is_invincible: bool = false 

# --- COMBO SYSTEM VARIABLES ---
var combo_step: int = 1         # Tracks if we are on attack, attack2, or attack3
var last_attack_time: float = 0.0


func _ready() -> void:
	add_to_group("player") # <--- Keep this right at the top!
	
	if GlobalManager.selected_sprite_frames != null:
		sprite.sprite_frames = GlobalManager.selected_sprite_frames

	current_health = max_health
	if attack_hitbox_collision:
		attack_hitbox_collision.disabled = true

	await get_tree().physics_frame
	sync_hud_ui()
	execute_fade_in_effect()


func _physics_process(_delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Check if the combo timer expired and reset back to the first attack string step
	var current_time = Time.get_ticks_msec() / 1000.0
	if combo_step > 1 and (current_time - last_attack_time) > combo_reset_time:
		combo_step = 1

	if Input.is_action_just_pressed("attack") and not is_attacking:
		attack()

	# --- MODIFIED: Prevent normal movement code from running while swinging ---
	if not is_attacking:
		var input_direction = Vector2(
			Input.get_axis("move_left", "move_right"),
			Input.get_axis("move_up", "move_down")
		)
		velocity = input_direction * speed
		move_and_slide()
		update_animation(input_direction)
	else:
		# If we are dashing in attack3, keep sliding forward using the dash velocity!
		if sprite.animation == "attack3":
			move_and_slide()



func attack() -> void:
	if is_dead: return
	is_attacking = true
	
	# Determine which animation string to play based on current sequence step
	var anim_name = "attack"
	if combo_step == 2:
		anim_name = "attack2"
	elif combo_step == 3:
		anim_name = "attack3"
		
	# Play the targeted action state safely
	if sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
	else:
		sprite.play("attack")
	
	# Update combo timing markers BEFORE entering the async block
	last_attack_time = Time.get_ticks_msec() / 1000.0
	
	# --- DASH FINISHER MECHANIC INJECTION ---
	if anim_name == "attack3":
		# 1. Wait a tiny fraction of a second for the wind-up frames to display
		await get_tree().create_timer(0.08).timeout
		
		# 2. Determine dash direction based on which way the sprite is currently facing
		var dash_direction = Vector2.LEFT if sprite.flip_h else Vector2.RIGHT
		
		# 3. Apply a strong sudden velocity punch forward
		var dash_force = 450.0  # Adjust this number higher or lower to change dash distance!
		velocity = dash_direction * dash_force
		move_and_slide()
	# -----------------------------------------

	# Progress string to the next step, loop back around to 1 if step 3 is finished
	if combo_step >= 3:
		combo_step = 1
	else:
		combo_step += 1

	if attack_hitbox_collision:
		attack_hitbox_collision.set_deferred("disabled", false)
		
	# HALT right here and let the full sprite sheet frames play out completely!
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
	if is_dead: return

	# ⚠️ MUST BE AT THE TOP: If we are swinging, completely freeze any movement animation updates
	if is_attacking:
		return 

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



func _on_player_hitbox_body_entered(body: Node2D) -> void:
	if is_dead: return
	if body.has_method("take_damage") and body != self:
		var knockback_direction = (body.global_position - global_position).normalized()
		
		# Define our base damage and knockback values
		var calculated_damage = attack_damage
		var calculated_knockback_force = knockback_force
		
		# NOTE: Because combo_step increments AT THE END of the attack() function,
		# while an attack is actively running, step 1 is active_game_instance = 2, step 2 is 3, and step 3 loops to 1.
		# Alternatively, we check what animation name is currently playing on the sprite!
		if sprite.animation == "attack3":
			calculated_damage = attack_damage * third_hit_multiplier
			calculated_knockback_force = knockback_force * 1.5 # Optional: send them flying further!
			print("CRITICAL COMBO FINISHER! Damage dealt: ", calculated_damage)
		
		var total_knockback = knockback_direction * calculated_knockback_force
		body.take_damage(calculated_damage, total_knockback)
