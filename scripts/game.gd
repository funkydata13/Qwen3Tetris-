extends Node2D

@onready var board = $Board
@onready var piece = $Piece
@onready var game_ui = $GameUI

var game_over: bool = false

var fall_stopwatch: float = 0.0
var fall_delay: float = 0.5 
var fall_delay_at_level_1:float = 0.5

var score: int = 0
var lines_cleared_total: int = 0
var level: int = 1
var base_fall_time: float = 0.5

# Configuration du DAS (Delayed Auto-Shift)
const DAS_DELAY = 0.3
const DAS_INTERVAL = 0.1
var das_timers = {
	"ui_left": 0.0,
	"ui_right": 0.0,
	"ui_down": 0.0
}
var is_das_active = {
	"ui_left": false,
	"ui_right": false,
	"ui_down": false
}

# Gestion de l'affichage de la pièce suivante
@onready var next_piece_display: TileMapLayer = %NextPieceDisplay # Notre nouveau layer de preview
var next_piece_type: String = "" # Stocke le type de la PROCHAINE pièce
var next_piece_layer_position: Vector2

var bank_piece_type: String = "" # Vide si pas de pièce en banque
@onready var bank_piece_display: TileMapLayer = %BankPieceDisplay
var bank_piece_layer_position: Vector2

var tetromino_types: Array = []

# Signaux personnalisés pour l'UI
signal score_changed(new_score: int)
signal level_changed(new_level: int)
signal lines_changed(new_lines: int)
signal game_over_triggered(score: int)

func _ready() -> void:	
	# Connexion des signaux à l'HUD
	score_changed.connect(game_ui.update_score)
	level_changed.connect(game_ui.update_level)
	lines_changed.connect(game_ui.update_lines)
	game_over_triggered.connect(game_ui.game_over)

	next_piece_layer_position = %NextPieceDisplay.position
	bank_piece_layer_position = %BankPieceDisplay.position
	
	tetromino_types = piece.TETROMINOS.keys()
	
	# Permettre à ce script de tourner même en pause pour intercepter la touche P
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	start_new_game()
	# Lancer la musique
	AudioManager.play_music("main_theme")

func toggle_pause() -> void:
	var new_pause_state = !get_tree().paused
	get_tree().paused = new_pause_state
	game_ui.show_pause(new_pause_state)

	if new_pause_state:
		AudioManager.pause_music()
	else:
		AudioManager.resume_music()

# Gestion de la perte de focus (fenêtre réduite ou clic ailleurs)
# func _notification(what):
#	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
#		if not game_over and not get_tree().paused:
#			toggle_pause()

func try_rotate(clockwise: bool) -> bool:
	# EXCLUSION DU CARRÉ : Si c'est la pièce O, on ne fait absolument rien
	if piece.type == "O":
		return false

	# 1. On récupère les positions théoriques tournées
	var future_positions = piece.get_next_rotated_positions(clockwise)
	
	# 2. Les seuls décalages de secours qu'on s'autorise si ça bloque
	var test_offsets = [
		Vector2i(0, 0),    # On teste d'abord la rotation normale (ton ancien code)
		Vector2i(-1, 0),   # Si ça bloque, on teste un décalage d'une case à gauche
		Vector2i(1, 0),    # Si ça bloque, on teste un décalage d'une case à droite
		Vector2i(0, -1)    # Si ça bloque, on teste un décalage d'une case vers le haut
	]
	
	# 3. On cherche le premier offset qui passe
	for offset in test_offsets:
		var positions_libres = true
		
		for pos in future_positions:
			# On applique le décalage de test à la position
			var adjusted_pos = pos + offset
			
			# Vérification des limites de la grille (murs et bas)
			if adjusted_pos.x < 0 or adjusted_pos.x >= board.COLS or adjusted_pos.y >= board.ROWS:
				positions_libres = false
				break
			
			# Ton ancienne logique exacte d'auto-collision
			var is_piece_cell = false
			for bloc in piece.blocs:
				if bloc + piece.position_grille == adjusted_pos:
					is_piece_cell = true
					break
			
			# Si ce n'est pas une cellule de la pièce elle-même, on check le board
			if not is_piece_cell and adjusted_pos.y >= 0:
				if not board.is_cell_empty(adjusted_pos.x, adjusted_pos.y):
					positions_libres = false
					break
		
		# Dès qu'un offset est valide, on applique la rotation
		if positions_libres:
			draw_piece(false)
			piece.rotate_piece(clockwise)
			# Ne faire le décalage que si ce n'est pas l'offset (0, 0)
			# if offset != Vector2i(0, 0):
			piece.position_grille += offset
			draw_piece(true)
			return true
			
	# Si aucun offset ne marche, on ne fait rien
	return false

func _input(event: InputEvent) -> void:
	# On autorise la touche pause même si game_over est faux
	if (Input.is_key_pressed(KEY_P) or Input.is_key_pressed(KEY_ESCAPE)) and event.is_pressed() and not event.is_echo():
		if not game_over:
			toggle_pause()

	if Input.is_key_pressed(KEY_M):
		if not Input.is_key_pressed(KEY_ALT):
			AudioManager.toggle_music()
		else:
			print_debug('pass')
			AudioManager.switch_music()

	if game_over or get_tree().paused:
		return
	
	# Gestion de la rotation - ne doit se déclencher qu'une seule fois par appui
	if Input.is_action_just_pressed("ui_up"):
		if try_rotate(true):
			AudioManager.play_sfx("rotate")
	
	if event.is_action_pressed("ui_accept"): # Ou ta touche Espace
		AudioManager.play_sfx("bank")
		handle_bank_mechanic()

func _process(delta: float) -> void:
	if game_over or get_tree().paused:
		return
	
	# 1. Si le plateau est en train de clignoter, on freeze TOUT le flux du jeu
	if board.is_animating:
		return
		
	# 2. Si l'animation vient de finir et qu'aucune pièce n'est active :
	# Le spawn se déclenche IMMÉDIATEMENT à la frame près !
	if not piece.is_active:
		spawn_piece()
		return
		
	# 3. Gestion de la chute normale (si une pièce est active)
	if piece.is_active:
		fall_stopwatch -= delta
		if fall_stopwatch <= 0:
			fall_stopwatch = fall_delay # On reset le chrono
			
			# On tente de descendre la pièce
			if not move_piece(Vector2i(0, 1)):
				lock_piece()
	else:
		return
	
	for action in das_timers.keys():
		if Input.is_action_just_pressed(action):
			# Appui initial : mouvement immédiat
			das_timers[action] = 0.0
			move_action(action)
			
			# Si on appuie sur BAS, on reset le timer de chute pour éviter le télescopage
			if action == "ui_down":
				fall_stopwatch = fall_delay
				AudioManager.play_sfx("drop")
			else:
				AudioManager.play_sfx("move")
				
		elif Input.is_action_pressed(action):
			# Action maintenue
			das_timers[action] += delta
			
			if not is_das_active[action]:
				# DAS non actif : attendre le délai initial
				if das_timers[action] >= DAS_DELAY:
					is_das_active[action] = true
					das_timers[action] = 0.0
					move_action(action)
					
					# Reset aussi lors du premier déclenchement du DAS sur BAS
					if action == "ui_down":
						fall_stopwatch = fall_delay
			else:
				# DAS actif : mouvement régulier selon l'intervalle
				if das_timers[action] >= DAS_INTERVAL:
					das_timers[action] -= DAS_INTERVAL
					move_action(action)
					
					# Reset à chaque pas de répétition en restant appuyé sur BAS
					if action == "ui_down":
						fall_stopwatch = fall_delay
		else:
			# Touche relâchée
			das_timers[action] = 0.0
			is_das_active[action] = false

func move_action(action: String) -> void:
	match action:
		"ui_left":
			move_piece(Vector2i(-1, 0))
		"ui_right":
			move_piece(Vector2i(1, 0))
		"ui_down":
			if not move_piece(Vector2i(0, 1)):
				lock_piece()

func start_new_game() -> void:
	board.clear_grid()
	next_piece_display.clear() # On nettoie la prévisualisation

	game_over = false
	score = 0
	lines_cleared_total = 0
	level = 1
	fall_stopwatch = fall_delay
	
	# Émission des signaux pour l'UI
	score_changed.emit(score)
	level_changed.emit(level)
	lines_changed.emit(lines_cleared_total)
	
	# On pioche la TOUTE PREMIÈRE pièce suivante en avance
	var tetrominos_keys = piece.TETROMINOS.keys()
	next_piece_type = tetrominos_keys[randi() % tetrominos_keys.size()]

	spawn_piece()

func spawn_piece() -> void:
	# Vérification si le board est en train d'animer
	if board.is_animating:
		# Si oui, on ne fait pas le spawn maintenant, on attend
		return
	
	# 1. La pièce de jeu devient celle qui était en attente
	var type_actuel = next_piece_type
	var position_depart = Vector2i(4, 0)
	
	# 2. On vérifie immédiatement si le point de départ est libre (Game Over)
	var positions_libres = true
	for bloc in piece.TETROMINOS[type_actuel]:
		var absolute_pos = position_depart + bloc
		if not board.is_cell_empty(absolute_pos.x, absolute_pos.y):
			positions_libres = false
			break
	
	if not positions_libres:
		game_over = true
		AudioManager.play_sfx("game_over")
		game_over_triggered.emit(score)
		return
	
	# 3. On fait apparaître la pièce active sur le plateau
	piece.initialize(type_actuel, position_depart)
	draw_piece(true)
	
	# 4. On pioche la NOUVELLE pièce suivante pour le coup d'après
	next_piece_type = tetromino_types[randi() % tetromino_types.size()]
	
	# 5. On met à jour l'affichage de la preview
	update_next_piece_preview()

func update_next_piece_preview() -> void:
	next_piece_display.clear()
	
	var blocs_suivants = piece.TETROMINOS[next_piece_type]
	var preview_id = piece.TETROMINO_TILE_IDS[next_piece_type]
	var offset = get_piece_offset(next_piece_type, next_piece_display, next_piece_layer_position)

	# Dessin final de la forme intacte
	for bloc in blocs_suivants:
		var pos_finale = bloc + offset
		next_piece_display.set_cell(pos_finale, 0, Vector2i(0, 0), preview_id)

func update_stored_piece_preview() -> void:
	bank_piece_display.clear()
	
	if bank_piece_type == "":
		return

	var blocs_suivants = piece.TETROMINOS[bank_piece_type]
	var preview_id = piece.TETROMINO_TILE_IDS[bank_piece_type]
	var offset = get_piece_offset(bank_piece_type, bank_piece_display, bank_piece_layer_position)
	
	for bloc in blocs_suivants:
		var pos_finale = bloc + offset
		bank_piece_display.set_cell(pos_finale, 0, Vector2i(0, 0), preview_id)

# Fonction utilitaire pour éviter la duplication de code de calcul d'offset
func get_piece_offset(type: String, tm_layer:TileMapLayer, tm_position:Vector2) -> Vector2i:
	var min_x = 999
	var min_y = 999
	var max_x = -999
	var max_y = -999
	
	var blocs_suivants = piece.TETROMINOS[type]

	for bloc in blocs_suivants:
		if bloc.x < min_x: min_x = bloc.x
		if bloc.x > max_x: max_x = bloc.x
		if bloc.y < min_y: min_y = bloc.y
		if bloc.y > max_y: max_y = bloc.y
	
	var largeur = max_x - min_x + 1
	var hauteur = max_y - min_y + 1
	
	# Positionnement de base sur la grille (0,0)
	var offset_global = Vector2i(
		-min_x - (largeur / 2),
		-min_y - (hauteur / 2)
	)
	
	# Correction de la Barre "I" pour l'axe Y que tu avais validée
	if next_piece_type == "I":
		offset_global += Vector2i(0, -1)
		
	# Gestion dynamique des offsets en PIXELS du Layer (par rapport au centre de ton conteneur)
	match next_piece_type:
		"O", "I":
			tm_layer.position = tm_position
		_:
			# "T", "S", "Z", "J", "L" reçoivent le décalage de 8 pixels en X
			tm_layer.position = tm_position + Vector2(-8, 0)

	return offset_global

func handle_bank_mechanic() -> void:
	if bank_piece_type == "":
		# CAS 1 : La banque est vide -> On met la pièce suivante en banque
		bank_piece_type = next_piece_type
		
		# On "consomme" la pièce suivante pour la mettre en banque
		# On doit donc immédiatement piocher une nouvelle pièce suivante
		next_piece_type = tetromino_types[randi() % tetromino_types.size()]
		
		# Mise à jour visuelle
		update_next_piece_preview()
		update_stored_piece_preview()
	else:
		# CAS 2 : La banque est pleine -> On remplace la pièce suivante par celle en banque
		# L'ancienne "next_piece" est perdue (ou on pourrait la mettre en banque si on voulait un système de rotation, 
		# mais ta demande est de remplacer la suivante).
		
		var old_next_piece = next_piece_type
		next_piece_type = bank_piece_type
		bank_piece_type = "" # La banque est libérée
		
		# On peut décider si on garde l'ancienne pièce suivante ou si on la remplace par une nouvelle.
		# Selon ta demande : "elle remplace la pièce suivante actuelle libérant le slot de la banque"
		# Donc : La pièce de la banque devient la prochaine pièce.
		
		update_next_piece_preview()
		update_stored_piece_preview()

func draw_piece(is_active: bool) -> void:
	for bloc in piece.blocs:
		var absolute_pos = piece.position_grille + bloc
		if is_active:
			board.set_cell_status(absolute_pos.x, absolute_pos.y, piece.alternative_id)
		else:
			board.set_cell_status(absolute_pos.x, absolute_pos.y, -1)

func move_piece(direction: Vector2i) -> bool:
	var future_positions = piece.get_next_move_positions(direction)
	
	# Vérifier si toutes les cellules futures sont vides
	for pos in future_positions:
		# Ignorer les cellules qui appartiennent à la pièce elle-même pour éviter l'auto-collision
		var is_piece_cell = false
		for bloc in piece.blocs:
			if bloc + piece.position_grille == pos:
				is_piece_cell = true
				break
		
		if not is_piece_cell and not board.is_cell_empty(pos.x, pos.y):
			return false
	
	# Si toutes les vérifications passent, effectuer le mouvement
	draw_piece(false)
	piece.move(direction)
	draw_piece(true)
	
	return true

func lock_piece() -> void:
	# La pièce est immobilisée et fait partie de la grille fixe
	# Insérer chaque bloc de la pièce dans la grille
	for bloc in piece.blocs:
		var absolute_pos = piece.position_grille + bloc
		board.set_cell_status(absolute_pos.x, absolute_pos.y, piece.alternative_id)
	
	piece.is_active = false

	# Appel asynchrone mais sans attendre ici
	var lines_cleared = await board.check_and_clear_lines()
	
	if lines_cleared > 0:
		# Ajouter les lignes au total
		lines_cleared_total += lines_cleared
		
		# Calculer le score selon le barème classique de Tetris multiplié par le niveau
		var points: int
		var mult:int = level + 1

		match lines_cleared:
			1:
				points = 40 * mult
			2:
				points = 100 * mult
			3:
				points = 300 * mult
			4:
				points = 1200 * mult
			_:
				points = 0
		
		score += points
		
		# Calculer le niveau actuel
		var new_level = (lines_cleared_total / 10) + 1
		if new_level > level:
			level = int(new_level)          
			
			# Formule exponentielle : chaque niveau est ~15% plus rapide que le précédent
			# On applique un max() pour ne pas descendre en dessous d'une frame de rendu (0.016s)
			fall_delay = max(0.03, 0.8 * pow(0.85, level - 1))

		print("Score: ", score, " | Lignes: ", lines_cleared_total, " | Niveau: ", level)
		
		# Émission des signaux pour l'UI
		score_changed.emit(score)
		level_changed.emit(level)
		lines_changed.emit(lines_cleared_total)

		if not board.is_animating:
			spawn_piece()
