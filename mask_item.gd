extends Area2D

# --- PARAMÈTRES FLOTTEMENT ---
@export var hover_speed : float = 4.0
@export var hover_height : float = 5.0
@export var shadow_offset_strength : float = 10.0

# --- RÉFÉRENCES ---
@onready var visual_sprite = $VisualSprite
@onready var shadow_sprite = $ShadowSprite
@onready var label = $Label # Le texte "Press E"

# --- VARIABLES LOGIQUES ---
var time_passed : float = 0.0
var player_ref = null        # Le joueur (pour l'ombre)
var player_in_zone = null    # Le joueur (pour le ramassage)

func _ready():
	# 1. On cherche le joueur pour l'ombre (Global)
	player_ref = get_tree().get_first_node_in_group("player")
	if player_ref == null:
		player_ref = get_node_or_null("/root/Level/Player")

	# 2. On s'assure que le label est caché au début
	if label: label.visible = false

	# 3. Connexions des signaux
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

func _process(delta):
	# --- VISUEL (Flottement + Ombre) ---
	time_passed += delta
	visual_sprite.position.y = -10 + (sin(time_passed * hover_speed) * hover_height)
	
	if player_ref:
		var light_direction = global_position - player_ref.global_position
		var shadow_move = light_direction.normalized() * shadow_offset_strength
		shadow_sprite.position = shadow_move

func _input(event):
	# --- INTERACTION ---
	# Si on appuie sur E et qu'on est DANS la zone
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		if player_in_zone != null:
			pick_up_mask()

func pick_up_mask():
	if player_in_zone.has_method("add_mask"):
		player_in_zone.add_mask()
		
		# Optionnel : Petit son de ramassage ici
		
		queue_free() # On détruit l'objet

# --- DÉTECTION DE ZONE ---
func _on_body_entered(body):
	if body.name == "Player":
		player_in_zone = body
		if label: label.visible = true # Affiche "Press E"

func _on_body_exited(body):
	if body.name == "Player":
		player_in_zone = null
		if label: label.visible = false # Cache "Press E"
