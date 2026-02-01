extends CharacterBody2D

# --- PARAMÈTRES MOUVEMENT ---
@export var speed : float = 150.0
@export var acceleration : float = 1500.0
@export var friction : float = 1200.0

# --- PARAMÈTRES MASQUE ---
@export var mask_duration : float = 4.0 
@export var light_normal_size : float = 50.0 
@export var light_hidden_size : float = 15.0 

# --- VARIABLES ---
var masks_count : int = 0
var is_hidden : bool = false 

# NOUVELLE VARIABLE POUR BLOQUER LE MOUVEMENT
var is_repairing : bool = false 

# --- VARIABLES AUDIO (Fades) ---
var default_volume_db : float = 0.0 
var audio_tween : Tween

# --- RÉFÉRENCES ---
# Jumpscare
@onready var jumpscare_layer = $JumpscareLayer
@onready var jumpscare_anim = $JumpscareLayer/JumpscareAnim 
@onready var scream_sound = $ScreamSound

# Personnage & Lumière
@onready var light = $PointLight2D
@onready var character_anim = $CharacterAnim

# Audio
@onready var footsteps_sound = $FootstepsSound

# UI (HUD)
@onready var mask_label = $HUD/MaskLabel
@onready var help_label = $HUD/HelpLabel 
@onready var dialogue_panel = $HUD/DialoguePanel 
@onready var dialogue_label = $HUD/DialoguePanel/DialogueLabel

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if jumpscare_layer: jumpscare_layer.visible = false
	if light: light.scale = Vector2(light_normal_size, light_normal_size)
	if footsteps_sound: default_volume_db = footsteps_sound.volume_db
	
	# Affichage HUD
	if $HUD: $HUD.visible = true
	if dialogue_panel: dialogue_panel.visible = false
	
	update_mask_ui()
	ajuster_jumpscare()

func _physics_process(delta: float) -> void:
	if get_tree().paused: return

	# 1. Utilisation du Masque (Toujours autorisé ?)
	if Input.is_action_just_pressed("use_mask"):
		try_use_mask()

	# --- SYSTEME DE BLOCAGE (REPARATION) ---
	if is_repairing:
		# On arrête tout mouvement
		velocity = Vector2.ZERO
		character_anim.stop()
		
		# On coupe le son des pas proprement
		if footsteps_sound.playing and footsteps_sound.volume_db > -60.0:
			stop_footsteps_smooth()
			
		move_and_slide()
		return # <--- ON ARRÊTE LA FONCTION ICI (Pas de mouvement possible)
	# ---------------------------------------

	# 2. Mouvement Normal
	var input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if input_vector != Vector2.ZERO:
		# --- ON BOUGE ---
		velocity = velocity.move_toward(input_vector * speed, acceleration * delta)
		update_animation(input_vector)
		
		# Audio : Fade In
		if not footsteps_sound.playing or footsteps_sound.volume_db <= -60.0:
			play_footsteps_smooth()
			
	else:
		# --- ON NE BOUGE PLUS ---
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		character_anim.stop()
		
		# Audio : Fade Out
		if footsteps_sound.playing and footsteps_sound.volume_db > -60.0:
			stop_footsteps_smooth()

	move_and_slide()

# --- GESTION ANIMATION 8 DIRECTIONS ---
func update_animation(direction: Vector2):
	var anim_name = "walk"
	if direction.y < 0: anim_name += "-up"
	elif direction.y > 0: anim_name += "-down"
	if direction.x < 0: anim_name += "-left"
	elif direction.x > 0: anim_name += "-right"
	if character_anim.sprite_frames.has_animation(anim_name):
		character_anim.play(anim_name)

# --- GESTION AUDIO (FADES) ---
func play_footsteps_smooth():
	if audio_tween: audio_tween.kill()
	if not footsteps_sound.playing:
		footsteps_sound.volume_db = -80.0
		footsteps_sound.pitch_scale = randf_range(0.9, 1.1)
		footsteps_sound.play()
	audio_tween = get_tree().create_tween()
	audio_tween.tween_property(footsteps_sound, "volume_db", default_volume_db, 0.1)

func stop_footsteps_smooth():
	if audio_tween: audio_tween.kill()
	audio_tween = get_tree().create_tween()
	audio_tween.tween_property(footsteps_sound, "volume_db", -80.0, 0.25)
	audio_tween.tween_callback(footsteps_sound.stop)

# --- JUMPSCARE ---
func ajuster_jumpscare():
	var ecran_size = get_viewport_rect().size
	jumpscare_anim.position = ecran_size / 2
	var texture = jumpscare_anim.sprite_frames.get_frame_texture("default", 0)
	if texture:
		var image_size = texture.get_size()
		var final_scale = max(ecran_size.x / image_size.x, ecran_size.y / image_size.y)
		jumpscare_anim.scale = Vector2(final_scale, final_scale)

# --- SYSTEME DE MASQUE ---
func add_mask():
	masks_count += 1
	update_mask_ui()

func update_mask_ui():
	if mask_label: mask_label.text = "MASKS: " + str(masks_count)
	if help_label:
		if masks_count > 0 and not is_hidden: help_label.visible = true
		else: help_label.visible = false

func try_use_mask():
	if masks_count > 0 and not is_hidden:
		masks_count -= 1
		activate_stealth_mode()
		update_mask_ui()

func activate_stealth_mode():
	is_hidden = true
	if help_label: help_label.visible = false
	if light:
		var tween = get_tree().create_tween()
		tween.tween_property(light, "scale", Vector2(light_hidden_size, light_hidden_size), 0.5)
	await get_tree().create_timer(mask_duration).timeout
	deactivate_stealth_mode()

func deactivate_stealth_mode():
	is_hidden = false
	update_mask_ui()
	if light:
		var tween = get_tree().create_tween()
		tween.tween_property(light, "scale", Vector2(light_normal_size, light_normal_size), 0.5)

# --- DIALOGUE UNIVERSEL ---
func show_dialogue(text_to_show: String):
	if dialogue_panel and dialogue_label:
		dialogue_label.text = text_to_show
		dialogue_panel.visible = true
		await get_tree().create_timer(3.0).timeout
		if dialogue_label.text == text_to_show:
			dialogue_panel.visible = false

# --- MORT ---
func kill_player():
	if get_tree().paused: return
	print("JUMPSCARE !")
	if audio_tween: audio_tween.kill() 
	footsteps_sound.stop()
	ajuster_jumpscare()
	jumpscare_layer.visible = true
	jumpscare_anim.play("default")
	if scream_sound: scream_sound.play()
	get_tree().paused = true
	await jumpscare_anim.animation_finished
	get_tree().paused = false
	get_tree().reload_current_scene()
