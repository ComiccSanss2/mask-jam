extends StaticBody2D

# --- PARAMÈTRES ---
var generators_fixed_count : int = 0
var total_generators_needed : int = 3 # <--- ON PASSE À 3 ICI
var is_open : bool = false
var current_player_ref = null 

# --- RÉFÉRENCES ---
@onready var sprite_closed = $SpriteClosed
@onready var sprite_open = $SpriteOpen
@onready var collision = $CollisionShape2D

func _ready():
	close_door()
	# Connexions zone
	var area = $InteractionArea
	if area:
		if not area.body_entered.is_connected(_on_interaction_area_body_entered):
			area.body_entered.connect(_on_interaction_area_body_entered)
		if not area.body_exited.is_connected(_on_interaction_area_body_exited):
			area.body_exited.connect(_on_interaction_area_body_exited)

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_F:
		if current_player_ref != null:
			check_door_status()

func check_door_status():
	if is_open: return

	if generators_fixed_count < total_generators_needed:
		# Calcul pour dire combien il en reste
		var remaining = total_generators_needed - generators_fixed_count
		current_player_ref.show_dialogue("NEED " + str(remaining) + " MORE POWER SUPPLIES.")

# --- LOGIQUE ---
func fix_generator():
	generators_fixed_count += 1
	print("Générateurs activés : ", generators_fixed_count, "/", total_generators_needed)
	
	if generators_fixed_count >= total_generators_needed:
		open_door()

func open_door():
	is_open = true
	
	# --- LA PORTE DISPARAÎT ---
	sprite_closed.visible = false
	sprite_open.visible = false # On cache tout
	
	# On enlève le mur physique
	collision.set_deferred("disabled", true)
	
	if current_player_ref:
		current_player_ref.show_dialogue("DOOR OPENED !")

func close_door():
	is_open = false
	sprite_closed.visible = true
	sprite_open.visible = false
	collision.set_deferred("disabled", false)

# --- DÉTECTION ---
func _on_interaction_area_body_entered(body):
	if body.name == "Player":
		current_player_ref = body

func _on_interaction_area_body_exited(body):
	if body.name == "Player":
		current_player_ref = null
