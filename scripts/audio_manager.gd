# scripts/audio_manager.gd
extends Node

# --- Configuration ---
# On utilise des dictionnaires pour mapper des noms simples à des fichiers
# Tu n'auras qu'à remplir ces chemins une fois tes sons téléchargés
# scripts/audio_manager.gd
var sfx_library: Dictionary = {
	"rotate": {
		"stream": preload("res://assets/sfx_rotate.wav"),
		"volume": 0.6 # 70% du volume max
	},
	"move": {
		"stream": preload("res://assets/sfx_move.wav"),
		"volume": 0.4 # Très discret
	},
	"drop": {
		"stream": preload("res://assets/sfx_drop.wav"),
		"volume": 0.4
	},
	"bank": {
		"stream": preload("res://assets/sfx_bank.wav"),
		"volume": 0.8
	},
	"line_clear": {
		"stream": preload("res://assets/sfx_line_clear.wav"),
		"volume": 0.9 # Volume max pour la satisfaction
	},
	"tetris": {
		"stream": preload("res://assets/sfx_tetris.wav"),
		"volume": 0.9
	},
	"game_over": {
		"stream": preload("res://assets/sfx_gameover.wav"),
		"volume": 0.8
	}
}

var bgm_library: Dictionary = {
	"main_theme": preload("res://assets/tetris_theme.wav")
}

# --- Nœuds internes ---
var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var max_sfx_players: int = 8

func _ready() -> void:
	# Initialisation du lecteur de musique
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	music_player.bus = "Music" # Assure-toi d'avoir un bus "Music" dans ton Audio Mixer
	
	# Initialisation d'un pool de lecteurs SFX pour permettre le mixage
	for i in range(max_sfx_players):
		var p = AudioStreamPlayer.new()
		add_child(p)
		p.bus = "SFX" # Assure-toi d'avoir un bus "SFX" dans ton Audio Mixer
		sfx_players.append(p)

# --- API PUBLIQUE ---

# 🎵 Gestion de la Musique
func play_music(music_name: String, fade_duration: float = 1.0) -> void:
	if not bgm_library.has(music_name):
		push_error("AudioManager: Music '" + music_name + "' non trouvée.")
		return
		
	if music_player.stream == bgm_library[music_name] and music_player.playing:
		return # Déjà en train de jouer
		
	music_player.stream = bgm_library[music_name]
	music_player.play()
	# Note: Pour un vrai fondu (fade), il faudrait utiliser un Tween.

func stop_music(fade_duration: float = 1.0) -> void:
	music_player.stop()

func pause_music() -> void:
	music_player.stream_paused = true

func resume_music() -> void:
	music_player.stream_paused = false

# 💥 Gestion des Effets Sonores
func play_sfx(sfx_name: String) -> void:
	if not sfx_library.has(sfx_name):
		push_error("AudioManager: SFX '" + sfx_name + "' non trouvée.")
		return
	
	var sfx_data = sfx_library[sfx_name]
	var stream_to_play = sfx_data["stream"]
	var volume_factor = sfx_data.get("volume", 1.0) # Utilise 1.0 par défaut si la clé manque

	# Trouver le premier lecteur disponible
	for p in sfx_players:
		if not p.playing:
			_setup_and_play(p, stream_to_play, volume_factor)
			return
	
	# Si tous sont occupés, on force le premier
	_setup_and_play(sfx_players[0], stream_to_play, volume_factor)

# Petite fonction helper pour éviter la répétition de code
func _setup_and_play(player: AudioStreamPlayer, stream: AudioStream, volume: float) -> void:
	player.stream = stream
	# On applique le volume factor. 
	# Note: volume est ici un multiplicateur (0.0 à 1.0)
	# On le convertit en dB pour le player.
	player.volume_db = linear_to_db(volume)
	player.play()

# --- Contrôles Globaux ---
func set_music_volume(value: float) -> void:
	# value de 0.0 à 1.0
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(value))

func set_sfx_volume(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(value))