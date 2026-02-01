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
@onready var jumpscare_layer = $JumpscareLayer
@onready var jumpscare_anim = $JumpscareLayer/JumpscareAnim 
@onready var scream_sound = $ScreamSound
@onready var light = $PointLight2D

# NOUVELLES RÉFÉRENCES D'ANIMATION
@onready var anim_normal = $CharacterAnim
@onready var anim_masked = $AnimMasked

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
	
	if $HUD: $HUD.visible = true
	if dialogue_panel: dialogue_panel.visible = false
	
	# --- INIT VISUEL ---
	# On s'assure qu'au démarrage, seul le normal est visible
	anim_normal.visible = true
	anim_masked.visible = false
	
	update_mask_ui()
	ajuster_jumpscare()

func _physics_process(delta: float) -> void:
	if get_tree().paused: return

	if Input.is_action_just_pressed("use_mask"):
		try_use_mask()

	# --- SYSTEME DE BLOCAGE (REPARATION) ---
	if is_repairing:
		velocity = Vector2.ZERO
		# On stoppe LES DEUX animations
		anim_normal.stop()
		anim_masked.stop()
		
		if footsteps_sound.playing and footsteps_sound.volume_db > -60.0:
			stop_footsteps_smooth()
		move_and_slide()
		return 
	# ---------------------------------------

	var input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if input_vector != Vector2.ZERO:
		velocity = velocity.move_toward(input_vector * speed, acceleration * delta)
		update_animation(input_vector)
		
		if not footsteps_sound.playing or footsteps_sound.volume_db <= -60.0:
			play_footsteps_smooth()
			
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		# On stoppe LES DEUX animations
		anim_normal.stop()
		anim_masked.stop()
		
		if footsteps_sound.playing and footsteps_sound.volume_db > -60.0:
			stop_footsteps_smooth()

	move_and_slide()

# --- GESTION ANIMATION 8 DIRECTIONS (Modifiée) ---
func update_animation(direction: Vector2):
	var anim_name = "walk"
	if direction.y < 0: anim_name += "-up"
	elif direction.y > 0: anim_name += "-down"
	if direction.x < 0: anim_name += "-left"
	elif direction.x > 0: anim_name += "-right"
	
	# Astuce : On joue l'animation sur LES DEUX en même temps.
	# Comme ça, ils sont toujours synchronisés quand on change la visibilité.
	if anim_normal.sprite_frames.has_animation(anim_name):
		anim_normal.play(anim_name)
		
	if anim_masked.sprite_frames.has_animation(anim_name):
		anim_masked.play(anim_name)

# --- AUDIO FADES (Inchangé) ---
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

# --- JUMPSCARE (Inchangé) ---
func ajuster_jumpscare():
	var ecran_size = get_viewport_rect().size
	jumpscare_anim.position = ecran_size / 2
	var texture = jumpscare_anim.sprite_frames.get_frame_texture("default", 0)
	if texture:
		var image_size = texture.get_size()
		var final_scale = max(ecran_size.x / image_size.x, ecran_size.y / image_size.y)
		jumpscare_anim.scale = Vector2(final_scale, final_scale)

# --- SYSTEME DE MASQUE (Modifié) ---
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
	
	# --- CHANGEMENT VISUEL ICI ---
	anim_normal.visible = false # On cache le normal
	anim_masked.visible = true  # On affiche le masqué
	
	if light:
		var tween = get_tree().create_tween()
		tween.tween_property(light, "scale", Vector2(light_hidden_size, light_hidden_size), 0.5)
	await get_tree().create_timer(mask_duration).timeout
	deactivate_stealth_mode()

func deactivate_stealth_mode():
	is_hidden = false
	update_mask_ui()
	
	# --- RETOUR VISUEL NORMAL ICI ---
	anim_masked.visible = false # On cache le masqué
	anim_normal.visible = true  # On affiche le normal
	
	if light:
		var tween = get_tree().create_tween()
		tween.tween_property(light, "scale", Vector2(light_normal_size, light_normal_size), 0.5)

# --- DIALOGUE UNIVERSEL (Inchangé) ---
func show_dialogue(text_to_show: String):
	if dialogue_panel and dialogue_label:
		dialogue_label.text = text_to_show
		dialogue_panel.visible = true
		await get_tree().create_timer(3.0).timeout
		if dialogue_label.text == text_to_show:
			dialogue_panel.visible = false

# --- MORT (Inchangé) ---
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
