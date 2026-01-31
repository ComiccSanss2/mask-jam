extends StaticBody2D

# GLISSE TA PORTE ICI DANS L'INSPECTEUR !
@export var target_door : Node2D 

var is_fixed : bool = false
var current_player_ref = null

@onready var sprite_off = $SpriteOff
@onready var sprite_on = $SpriteOn

func _ready():
	# --- VISUEL DE BASE ---
	sprite_off.visible = true 
	sprite_on.visible = false  
	
	# Connexions Zone
	var area = $InteractionArea
	if area:
		if not area.body_entered.is_connected(_on_interaction_area_body_entered):
			area.body_entered.connect(_on_interaction_area_body_entered)
		if not area.body_exited.is_connected(_on_interaction_area_body_exited):
			area.body_exited.connect(_on_interaction_area_body_exited)

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_F:
		if current_player_ref != null:
			try_fix_generator()

func try_fix_generator():
	# 1. Si déjà réparé, on affiche un autre message
	if is_fixed:
		current_player_ref.show_dialogue("Already running.")
		return

	# --- ON ACTIVE ---
	is_fixed = true
	
	# --- CHANGEMENT VISUEL ---
	sprite_off.visible = false
	sprite_on.visible = true
	
	# --- LE MESSAGE QUE TU VOULAIS ---
	current_player_ref.show_dialogue("Power supply repaired")
	
	# On prévient la porte (si elle est connectée)
	if target_door and target_door.has_method("fix_generator"):
		target_door.fix_generator()
	else:
		print("ERREUR : Oubli de connecter la porte dans l'inspecteur !")

# --- DÉTECTION ---
func _on_interaction_area_body_entered(body):
	if body.name == "Player":
		current_player_ref = body

func _on_interaction_area_body_exited(body):
	if body.name == "Player":
		current_player_ref = null
