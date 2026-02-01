extends StaticBody2D

# --- PARAMÈTRES ---
@export var target_door : Node2D 
@export var repair_time_needed : float = 3.0 

# --- VARIABLES ---
var is_fixed : bool = false
var current_player_ref = null
var current_repair_timer : float = 0.0 

# --- RÉFÉRENCES ---
@onready var sprite_off = $SpriteOff
@onready var sprite_on = $SpriteOn
@onready var buzz_sound = $BuzzSound
@onready var glow_light = $GlowLight
@onready var repair_bar = $RepairBar

func _ready():
	# États initiaux
	sprite_off.visible = true  
	sprite_on.visible = false 
	if glow_light: glow_light.energy = 0
	if buzz_sound: buzz_sound.stop()
	
	# Config Barre
	if repair_bar:
		repair_bar.visible = false
		repair_bar.max_value = repair_time_needed
		repair_bar.value = 0
	
	# Connexions Zone
	var area = $InteractionArea
	if area:
		if not area.body_entered.is_connected(_on_interaction_area_body_entered):
			area.body_entered.connect(_on_interaction_area_body_entered)
		if not area.body_exited.is_connected(_on_interaction_area_body_exited):
			area.body_exited.connect(_on_interaction_area_body_exited)

func _process(delta):
	# Si déjà réparé ou pas de joueur, on annule tout
	if is_fixed or current_player_ref == null:
		reset_repair_progress()
		return

	# Si la touche F est MAINTENUE
	if Input.is_key_pressed(KEY_F):
		
		# 1. On bloque le joueur
		current_player_ref.is_repairing = true
		
		# 2. Gestion de la barre
		repair_bar.visible = true
		current_repair_timer += delta
		repair_bar.value = current_repair_timer
		
		# 3. Vérification de fin
		if current_repair_timer >= repair_time_needed:
			complete_repair()
			
	else:
		# Si la touche est relâchée
		reset_repair_progress()

func reset_repair_progress():
	current_repair_timer = 0.0
	
	# IMPORTANT : On libère le joueur !
	if current_player_ref:
		current_player_ref.is_repairing = false
	
	if repair_bar:
		repair_bar.value = 0
		repair_bar.visible = false

func complete_repair():
	is_fixed = true
	
	# On libère le joueur immédiatement
	if current_player_ref:
		current_player_ref.is_repairing = false
	
	# UI
	repair_bar.visible = false 
	
	# Visuels et Sons
	sprite_off.visible = false
	sprite_on.visible = true
	
	if buzz_sound: buzz_sound.play()
	if glow_light: start_light_pulse()
	
	# Dialogue et Porte
	current_player_ref.show_dialogue("POWER SUPPLY REPAIRED.")
	
	if target_door and target_door.has_method("fix_generator"):
		target_door.fix_generator()

# --- ANIMATION LUMIÈRE ---
func start_light_pulse():
	glow_light.enabled = true
	var tween = create_tween()
	tween.set_loops() 
	# Monte à 1.5, descend à 0.5
	tween.tween_property(glow_light, "energy", 1.5, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(glow_light, "energy", 0.5, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# --- DÉTECTION DU JOUEUR ---
func _on_interaction_area_body_entered(body):
	if body.name == "Player":
		current_player_ref = body

func _on_interaction_area_body_exited(body):
	if body.name == "Player":
		current_player_ref = null
		reset_repair_progress() # Sécurité si on sort en courant
