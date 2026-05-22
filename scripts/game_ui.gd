extends CanvasLayer

# --- HUD logic ---
@onready var score_label = %ScoreLabel
@onready var lines_label = %LinesLabel
@onready var level_label = %LevelLabel

func update_score(p_score: int) -> void:
	score_label.text = str(p_score)

func update_lines(p_lines: int) -> void:
	lines_label.text = str(p_lines)

func update_level(p_level: int) -> void:
	level_label.text = str(p_level)

# --- Leaderboard & GameOver logic ---

# TES IDENTIFIANTS SILENTWOLF (À REMPLIR)
const SUPABASE_URL = "https://sjcvgtglrmntoocjlxif.supabase.co" # Ta vraie URL ici
const SUPABASE_KEY = "sb_publishable_3aC74szqX1058Nzqs5xuYg_njZ_1DhV"       # Ta vraie clé ici

# Référence à ton unique gros label de texte
@onready var lb_list: Label = %"LB List"
@onready var name_input: LineEdit = %NameInput
@onready var game_over_control: Control = $GameOverControl
@onready var pause_overlay: Control = $PauseOverlay

# On crée dynamiquement le nœud HTTP pour éviter d'avoir à le glisser dans l'éditeur
var http_scores: HTTPRequest

# Variable pour savoir si on attend une réponse de lecture (GET) ou d'écriture (POST)
var is_writing: bool = false
var local_scores: Array = []
var current_player_score:int = 0

func _ready() -> void:
	# HUD init
	# (Previously game_over_label.visible = false but we use the complex GameOverControl)
	
	# Leaderboard init
	# Initialisation propre du nœud HTTP par le code
	http_scores = HTTPRequest.new()
	add_child(http_scores)
	http_scores.request_completed.connect(_on_request_completed)
	
	# Récupération automatique du Top 10 au chargement de l'UI
	get_scores_from_cloud()
	
	game_over_control.hide()
	pause_overlay.hide()
	
	# Permettre à l'UI de réagir même quand le jeu est en pause
	process_mode = Node.PROCESS_MODE_ALWAYS

func show_pause(is_paused: bool) -> void:
	pause_overlay.visible = is_paused

# 📥 1. Récupérer le Top 10 mondial
func get_scores_from_cloud() -> void:
	is_writing = false
	lb_list.text = "Connexion..."
	
	# Route Supabase : on sélectionne le nom et le score, trié par score décroissant, limité à 10 entrées
	var url = SUPABASE_URL + "/rest/v1/leaderboard-tetris-ia?select=player_name,player_score&order=player_score.desc&limit=10"
	var headers = [
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + SUPABASE_KEY
	]
	
	var error = http_scores.request(url, headers, HTTPClient.METHOD_GET)
	if error != OK:
		lb_list.text = "Erreur réseau\n(GET)"

# 📤 2. Envoyer un nouveau score au Game Over (Version RPC Sécurisée)
func upload_new_score(player_name: String, new_score: int) -> void:
	is_writing = true
	lb_list.text = "Envoi du score..."
	
	# 1. On vise l'endpoint RPC
	var url = SUPABASE_URL + "/rest/v1/rpc/submit_score"
	
	var headers = [
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + SUPABASE_KEY,
		"Content-Type: application/json",
		"Prefer: params=single-object" # 2. On ajoute cette option pour le format JSON
	]
	
	# 3. On utilise p_name et p_score (les arguments de la fonction SQL)
	var data = {
		"p_name": player_name.left(3).to_upper(),
		"p_score": new_score
	}
	var query = JSON.stringify(data)
	
	var error = http_scores.request(url, headers, HTTPClient.METHOD_POST, query)
	if error != OK:
		lb_list.text = "Erreur réseau\n(POST)"

# 🔄 3. Le central aiguillage des réponses HTTP
func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	# Supabase répond 200 pour une lecture réussie, et 201 pour une écriture réussie
	if result != HTTPRequest.RESULT_SUCCESS or (response_code != 200 and response_code != 201 and response_code != 204):
		print("Échec de la requête HTTP. Code reçu : ", response_code)
		lb_list.text = "Erreur serveur\nCode: " + str(response_code)
		return

	# Si on vient d'envoyer un score avec succès, on rafraîchit immédiatement l'affichage
	if is_writing:
		get_scores_from_cloud()
		return

	# Traitement de la lecture des scores (GET)
	var json = JSON.new()
	var error = json.parse(body.get_string_from_utf8())
	if error != OK:
		lb_list.text = "Erreur lecture\ndonnées JSON"
		return

	var datas = json.data
	if datas is Array:
		local_scores = (json.data as Array).duplicate(true)
		_format_and_display_scores()

# 🎨 4. Injection et formatage dans ton interface
func _format_and_display_scores() -> void:
	if local_scores.size() == 0:
		lb_list.text = "Aucun score\npour le moment !"
		return
		
	var display_text = ""
	
	for i in range(local_scores.size()):
		var entry = local_scores[i]
		var rank = str(i + 1).pad_zeros(2) # "1" devient "01", "10" reste "10"
		var player_name = str(entry["player_name"]).to_upper()
		var player_score = str(int(entry["player_score"]))
		
		# Reconstruction exacte de ton format initial : "01.FNK - 8200"
		var line = rank + "." + player_name + " - " + player_score
		
		# On n'ajoute pas de retour à la ligne pour la 10e entrée
		if i < local_scores.size() - 1:
			line += "\n"
			
		display_text += line
		
	lb_list.text = display_text

func insert_score_locally_and_display(formatted_name: String, score_to_add: int) -> void:
	# 1. Créer la nouvelle entrée au même format que le JSON de ta BDD
	var new_entry = {
		"player_name": formatted_name,
		"player_score": score_to_add if score_to_add is int else int(score_to_add) # Sécurité type
	}
	
	# 2. L'ajouter au tableau local
	local_scores.append(new_entry)
	
	# 3. Trier le tableau du plus grand au plus petit score
	# On utilise une fonction personnalisée (Callable) pour le tri de dictionnaires
	local_scores.sort_custom(func(a, b): return int(a["player_score"]) > int(b["player_score"]))
	
	# 4. Garder uniquement les 10 premiers scores
	if local_scores.size() > 10:
		local_scores.resize(10)
		
	# 5. Mettre à jour l'UI immédiatement !
	_format_and_display_scores()

func game_over(score: int) -> void:
	current_player_score = score
	game_over_control.show()
	
	if local_scores.size() < 10 or score > local_scores[-1]["player_score"]:
		$GameOverControl/GameOverZone/ScoreZone.show()
		$GameOverControl/GameOverZone/NoScoreLabel.hide()
		name_input.editable = true
		name_input.text = ""
		name_input.grab_focus()  # Ouvre directement le clavier pour le joueur
	else:
		$GameOverControl/GameOverZone/ScoreZone.hide()
		$GameOverControl/GameOverZone/NoScoreLabel.show()

func _on_name_input_text_changed(new_text: String) -> void:
	var caret_pos = name_input.caret_column
	name_input.text = new_text.to_upper()
	name_input.caret_column = caret_pos

func _on_name_input_text_submitted(new_text: String) -> void:
	var formatted_name = new_text.strip_edges().to_upper()
	# 2. Remplir avec des "_" si le joueur a mis moins de 3 lettres
	formatted_name = formatted_name.rpad(3, "_")

	insert_score_locally_and_display(formatted_name, current_player_score)
	upload_new_score(formatted_name, current_player_score)
	
func _on_restart_button_pressed() -> void:
	game_over_control.hide()
	# Recharge la scène courante pour relancer une partie de Tetris propre
	get_tree().reload_current_scene()
