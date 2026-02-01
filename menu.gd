extends Control

# --- RÉFÉRENCES ---
@onready var warning_screen = $WarningScreen
@onready var menu_container = $MenuContainer
@onready var play_button = $MenuContainer/PlayButton
@onready var quit_button = $MenuContainer/QuitButton

# Mets ici le chemin vers ta scène de jeu principale !
var level_scene_path = "res://caca.tscn" 

func _ready():
	# 1. ÉTAT INITIAL
	# On affiche l'avertissement, on cache le menu (ou on le met derrière)
	warning_screen.visible = true
	warning_screen.modulate.a = 1.0 # Opacité à 100%
	
	# On cache le menu pour éviter les clics accidentels
	menu_container.visible = false 
	
	# Connexion des boutons
	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# 2. SÉQUENCE D'INTRO
	start_intro_sequence()

func start_intro_sequence():
	# On attend 3 secondes pour que le joueur lise
	await get_tree().create_timer(4.0).timeout
	
	# On fait disparaître l'avertissement en fondu (Tween)
	var tween = create_tween()
	tween.tween_property(warning_screen, "modulate:a", 0.0, 2.0) # Disparait en 2 sec
	
	# Quand le fondu est fini...
	await tween.finished
	
	warning_screen.visible = false # On le désactive complètement
	menu_container.visible = true  # On affiche le menu
	
	# Optionnel : Petite animation d'apparition du menu
	menu_container.modulate.a = 0.0
	var tween_menu = create_tween()
	tween_menu.tween_property(menu_container, "modulate:a", 1.0, 1.0)

# --- BOUTONS ---

func _on_play_pressed():
	# Charge la scène du jeu
	get_tree().change_scene_to_file(level_scene_path)

func _on_quit_pressed():
	# Quitte le jeu
	get_tree().quit()
