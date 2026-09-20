extends HBoxContainer

# Load your separate png files straight into these slots via the inspector
@export var full_heart_tex: Texture2D
@export var half_heart_tex: Texture2D
@export var empty_heart_tex: Texture2D

# Adjust this if your heart graphics are larger or smaller than 16x16 pixels
const HEART_SIZE: float = 16.0 


func _ready() -> void:
	# Ensure the container expanding size properties don't collapse to 0
	custom_minimum_size = Vector2(HEART_SIZE * 5, HEART_SIZE)
	
	# Register this container globally so the player can send updates directly to it
	add_to_group("hud")


func update_hearts(current_health: float, max_health: float) -> void:
	# Wipe old heart visuals before updating current status layout
	for child in get_children():
		child.queue_free()
		
	var total_hearts = int(max_health)
	
	for i in range(total_hearts):
		var heart = TextureRect.new()
		
		# Explicit sizing instructions for Godot's UI layout systems
		heart.custom_minimum_size = Vector2(HEART_SIZE, HEART_SIZE)
		heart.size = Vector2(HEART_SIZE, HEART_SIZE)
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		# Direct visual assignment based on individual heart files
		if current_health >= i + 1.0:
			heart.texture = full_heart_tex
		elif current_health >= i + 0.5:
			heart.texture = half_heart_tex
		else:
			heart.texture = empty_heart_tex
			
		add_child(heart)
