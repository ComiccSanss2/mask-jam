extends StaticBody2D

var generators_fixed_count : int = 0
var total_generators_needed : int = 2
var is_open : bool = false
var current_player_ref = null 

@onready var sprite_closed = $SpriteClosed
@onready var sprite_open = $SpriteOpen
@onready var collision = $CollisionShape2D

func _ready():
	close_door()
	var area = $InteractionArea
	if not area.body_entered.is_connected(_on_interaction_area_body_entered):
		area.body_entered.connect(_on_interaction_area_body_entered)
	if not area.body_exited.is_connected(_on_interaction_area_body_exited):
		area.body_exited.connect(_on_interaction_area_body_exited)

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_F:
		print("--- TEST TOUCHE F ---")
		if current_player_ref == null:
			print("ERREUR : J'appuie sur F, mais la porte ne voit PERSONNE.")
			print("Cause possible : Collision Mask incorrect ou Player pas entré dans la zone.")
		else:
			print("SUCCÈS : Joueur détecté ! Lancement du dialogue...")
			check_door_status()

func check_door_status():
	if is_open: return
	
	if generators_fixed_count < total_generators_needed:
		if current_player_ref.has_method("show_dialogue"):
			current_player_ref.show_dialogue("NOT ENOUGH POWER.")
		else:
			print("ERREUR CRITIQUE : Le Player détecté n'a pas la fonction 'show_dialogue' !")

# --- DÉTECTION ---
func _on_interaction_area_body_entered(body):
	print("Quelque chose est entré dans la zone : ", body.name)
	
	if body.name == "Player":
		print(">> C'est bien le Player ! Mémoire mise à jour.")
		current_player_ref = body

func _on_interaction_area_body_exited(body):
	if body.name == "Player":
		print("<< Le Player est sorti.")
		current_player_ref = null

# --- LOGIQUE ---
func fix_generator():
	generators_fixed_count += 1
	if generators_fixed_count >= total_generators_needed:
		open_door()

func open_door():
	is_open = true
	sprite_closed.visible = false
	sprite_open.visible = true
	collision.set_deferred("disabled", true)

func close_door():
	is_open = false
	sprite_closed.visible = true
	sprite_open.visible = false
	collision.set_deferred("disabled", false)
