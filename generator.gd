extends StaticBody2D

# --- PARAMÈTRES ---
@export var target_door : Node2D 
@export var repair_time_needed : float = 3.0 

# --- VARIABLES ---
var is_fixed : bool = false
var current_player_ref = null
var current_repair_timer : float = 0.0 
var just_repaired_cooldown : bool = false 

# Animation Label
var time_passed : float = 0.0
var label_base_y : float = 0.0

# --- RÉFÉRENCES ---
@onready var sprite_off = $SpriteOff
@onready var sprite_on = $SpriteOn
@onready var buzz_sound = $BuzzSound
@onready var glow_light = $GlowLight
@onready var off_light = $OffLight
@onready var repair_bar = $RepairBar
@onready var label = $Label 

func _ready():
	# États initiaux
	sprite_off.visible = true  
	sprite_on.visible = false 
	
	if glow_light: glow_light.enabled = false 
	if off_light:
		off_light.enabled = true   
		start_off_light_blink()    
	
	if buzz_sound: buzz_sound.stop()
	
	if repair_bar:
		repair_bar.visible = false
		repair_bar.max_value = repair_time_needed
		repair_bar.value = 0
		
	if label: 
		label.visible = false
		label_base_y = label.position.y # Sauvegarde position Y initiale
	
	# Connexions Zone
	var area = $InteractionArea
	if area:
		if not area.body_entered.is_connected(_on_interaction_area_body_entered):
			area.body_entered.connect(_on_interaction_area_body_entered)
		if not area.body_exited.is_connected(_on_interaction_area_body_exited):
			area.body_exited.connect(_on_interaction_area_body_exited)

# --- CLIC UNIQUE (Message erreur) ---
func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		if current_player_ref != null and is_fixed and not just_repaired_cooldown:
			current_player_ref.show_dialogue("ALREADY RUNNING.")

# --- BOUCLE PRINCIPALE ---
func _process(delta):
	
	# 1. GESTION DU LABEL FLOTTANT
	if label:
		var should_be_visible = false
		
		# Visible si : Joueur présent ET Pas fini
		if current_player_ref != null and not is_fixed:
			should_be_visible = true
			
			# CACHÉ si : On lit un dialogue (pour la lisibilité)
			if current_player_ref.is_reading_dialogue:
				should_be_visible = false
		
		label.visible = should_be_visible
		
		# Animation
		if label.visible:
			time_passed += delta
			label.position.y = label_base_y + (sin(time_passed * 5.0) * 2.0)
	
	# 2. GESTION DE LA RÉPARATION (MAINTIEN)
	if is_fixed or current_player_ref == null:
		reset_repair_progress()
		return

	if Input.is_key_pressed(KEY_E):
		# ON BLOQUE LE JOUEUR ICI (Pendant la barre de chargement)
		current_player_ref.is_repairing = true 
		
		if label: label.visible = false
		
		repair_bar.visible = true
		current_repair_timer += delta
		repair_bar.value = current_repair_timer
		
		if current_repair_timer >= repair_time_needed:
			complete_repair()
	else:
		reset_repair_progress()

func reset_repair_progress():
	current_repair_timer = 0.0
	
	# ON LIBÈRE LE JOUEUR SI ON RELÂCHE
	if current_player_ref:
		current_player_ref.is_repairing = false
		
	if repair_bar:
		repair_bar.value = 0
		repair_bar.visible = false

func complete_repair():
	is_fixed = true
	just_repaired_cooldown = true
	
	# ON LIBÈRE LE JOUEUR IMMÉDIATEMENT (Pour qu'il puisse bouger pendant le dialogue)
	if current_player_ref:
		current_player_ref.is_repairing = false 
	
	repair_bar.visible = false 
	sprite_off.visible = false
	sprite_on.visible = true
	
	if off_light: off_light.enabled = false 
	if glow_light: start_glow_pulse() 
	if buzz_sound: buzz_sound.play()
	
	current_player_ref.show_dialogue("POWER SUPPLY REPAIRED.")
	
	if target_door and target_door.has_method("fix_generator"):
		target_door.fix_generator()
		
	await get_tree().create_timer(2.0).timeout
	just_repaired_cooldown = false

# --- ANIMATIONS LUMIÈRE ---
func start_off_light_blink():
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(off_light, "energy", 0.2, 1.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(off_light, "energy", 1.0, 1.0).set_trans(Tween.TRANS_SINE)

func start_glow_pulse():
	glow_light.enabled = true
	var tween = create_tween()
	tween.set_loops() 
	tween.tween_property(glow_light, "energy", 1.5, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(glow_light, "energy", 0.5, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# --- DÉTECTION ---
func _on_interaction_area_body_entered(body):
	if body.name == "Player":
		current_player_ref = body

func _on_interaction_area_body_exited(body):
	if body.name == "Player":
		current_player_ref = null
		reset_repair_progress()
