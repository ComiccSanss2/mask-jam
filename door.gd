extends StaticBody2D

# --- PARAMÈTRES ---
var generators_fixed_count : int = 0
var total_generators_needed : int = 4 
var is_open : bool = false
var current_player_ref = null 

# --- VARIABLES ANIMATION ---
var time_passed : float = 0.0
var label_base_y : float = 0.0

# --- RÉFÉRENCES ---
@onready var sprite_closed = $SpriteClosed
@onready var sprite_open = $SpriteOpen
@onready var collision = $CollisionShape2D
@onready var label = $Label 

func _ready():
	close_door()
	if label: 
		label.visible = false
		label_base_y = label.position.y
	
	var area = $InteractionArea
	if area:
		if not area.body_entered.is_connected(_on_interaction_area_body_entered):
			area.body_entered.connect(_on_interaction_area_body_entered)
		if not area.body_exited.is_connected(_on_interaction_area_body_exited):
			area.body_exited.connect(_on_interaction_area_body_exited)

func _process(delta):
	# --- GESTION INTELLIGENTE DU LABEL ---
	if label:
		var should_be_visible = false
		
		# Condition 1: Joueur présent ET Porte fermée
		if current_player_ref != null and not is_open:
			should_be_visible = true
			
			# Condition 2 (NOUVEAU): Si le joueur lit un dialogue -> On cache
			if current_player_ref.is_reading_dialogue:
				should_be_visible = false
		
		label.visible = should_be_visible
		
		# Animation
		if label.visible:
			time_passed += delta
			label.position.y = label_base_y + (sin(time_passed * 5.0) * 2.0)

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		if current_player_ref != null:
			check_door_status()

func check_door_status():
	if is_open: return

	if generators_fixed_count < total_generators_needed:
		var remaining = total_generators_needed - generators_fixed_count
		if remaining > 1:
			current_player_ref.show_dialogue("NEED " + str(remaining) + " MORE POWER SUPPLY.")
		else:
			current_player_ref.show_dialogue("NEED 1 MORE POWER SUPPLY.")

func fix_generator():
	generators_fixed_count += 1
	if generators_fixed_count >= total_generators_needed:
		open_door()

func open_door():
	is_open = true
	sprite_closed.visible = false
	sprite_open.visible = false 
	# Pas besoin de cacher le label ici, le _process s'en charge (is_open == true)
	collision.set_deferred("disabled", true)
	if current_player_ref:
		current_player_ref.show_dialogue("DOOR OPENED.")

func close_door():
	is_open = false
	sprite_closed.visible = true
	sprite_open.visible = false
	collision.set_deferred("disabled", false)

func _on_interaction_area_body_entered(body):
	if body.name == "Player": current_player_ref = body
func _on_interaction_area_body_exited(body):
	if body.name == "Player": current_player_ref = null
