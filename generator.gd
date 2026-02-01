extends StaticBody2D

# --- PARAMÈTRES ---
@export var target_door : Node2D 
@export var repair_time_needed : float = 3.0 

# --- VARIABLES ---
var is_fixed : bool = false
var current_player_ref = null
var current_repair_timer : float = 0.0 
var just_repaired_cooldown : bool = false 

# --- RÉFÉRENCES ---
@onready var sprite_off = $SpriteOff
@onready var sprite_on = $SpriteOn
@onready var buzz_sound = $BuzzSound
@onready var glow_light = $GlowLight
@onready var off_light = $OffLight
@onready var repair_bar = $RepairBar

func _ready():
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
	
	var area = $InteractionArea
	if area:
		if not area.body_entered.is_connected(_on_interaction_area_body_entered):
			area.body_entered.connect(_on_interaction_area_body_entered)
		if not area.body_exited.is_connected(_on_interaction_area_body_exited):
			area.body_exited.connect(_on_interaction_area_body_exited)

# --- CLIC UNIQUE (MESSAGE) ---
func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_F:
		# On ajoute la condition : "et PAS en période de cooldown"
		if current_player_ref != null and is_fixed and not just_repaired_cooldown:
			current_player_ref.show_dialogue("ALREADY RUNNING.")

# --- MAINTIEN (REPARATION) ---
func _process(delta):
	if is_fixed or current_player_ref == null:
		reset_repair_progress()
		return

	if Input.is_key_pressed(KEY_F):
		current_player_ref.is_repairing = true
		repair_bar.visible = true
		current_repair_timer += delta
		repair_bar.value = current_repair_timer
		
		if current_repair_timer >= repair_time_needed:
			complete_repair()
	else:
		reset_repair_progress()

func reset_repair_progress():
	current_repair_timer = 0.0
	if current_player_ref:
		current_player_ref.is_repairing = false
	if repair_bar:
		repair_bar.value = 0
		repair_bar.visible = false

func complete_repair():
	is_fixed = true
	
	# --- ACTIVATION DU COOLDOWN ---
	just_repaired_cooldown = true
	
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
		
	# --- FIN DU COOLDOWN APRÈS 2 SECONDES ---
	# Cela empêche le message "Already Running" d'apparaître instantanément
	await get_tree().create_timer(2.0).timeout
	just_repaired_cooldown = false

# --- ANIMATIONS & ZONES (Inchangé) ---
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

func _on_interaction_area_body_entered(body):
	if body.name == "Player":
		current_player_ref = body

func _on_interaction_area_body_exited(body):
	if body.name == "Player":
		current_player_ref = null
		reset_repair_progress()
