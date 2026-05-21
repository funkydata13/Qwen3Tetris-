extends Node2D

@onready var board = $Board
@onready var piece = $Piece
@onready var hud = $HUD

var game_over: bool = false
var fall_timer: Timer
var score: int = 0
var lines_cleared_total: int = 0
var level: int = 1
var base_fall_time: float = 0.5

# Configuration du DAS (Delayed Auto-Shift)
const DAS_DELAY = 0.6
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
@onready var next_piece_display = %NextPieceDisplay # Notre nouveau layer de preview
var next_piece_type: String = "" # Stocke le type de la PROCHAINE pièce
var next_piece_layer_position: Vector2

# Signaux personnalisés pour l'UI
signal score_changed(new_score: int)
signal level_changed(new_level: int)
signal lines_changed(new_lines: int)
signal game_over_triggered

func _ready() -> void:
	# Initialisation du timer de chute
	fall_timer = Timer.new()
	fall_timer.autostart = true
	fall_timer.wait_time = base_fall_time
	fall_timer.timeout.connect(_on_fall_timer_timeout)
	add_child(fall_timer)
	fall_timer.start()
	
	# Connexion des signaux à l'HUD
	score_changed.connect(hud.update_score)
	level_changed.connect(hud.update_level)
	lines_changed.connect(hud.update_lines)
	game_over_triggered.connect(hud.display_game_over)

	next_piece_layer_position = %NextPieceDisplay.position
	
	start_new_game()

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
	if game_over:
		return
	
	# Gestion de la rotation - ne doit se déclencher qu'une seule fois par appui
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_up"):
		try_rotate(true)

func _process(delta: float) -> void:
	if game_over:
		return
	
	for action in das_timers.keys():
		if Input.is_action_just_pressed(action):
			# Appui initial : mouvement immédiat
			move_action(action)
			das_timers[action] = 0.0
			
			# Si on appuie sur BAS, on reset le timer de chute pour éviter le télescopage
			if action == "ui_down":
				fall_timer.start()
				
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
						fall_timer.start()
			else:
				# DAS actif : mouvement régulier selon l'intervalle
				if das_timers[action] >= DAS_INTERVAL:
					das_timers[action] -= DAS_INTERVAL
					move_action(action)
					
					# Reset à chaque pas de répétition en restant appuyé sur BAS
					if action == "ui_down":
						fall_timer.start()
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
	fall_timer.wait_time = base_fall_time
	
	# Émission des signaux pour l'UI
	score_changed.emit(score)
	level_changed.emit(level)
	lines_changed.emit(lines_cleared_total)
	
	# On pioche la TOUTE PREMIÈRE pièce suivante en avance
	var tetrominos_keys = piece.TETROMINOS.keys()
	next_piece_type = tetrominos_keys[randi() % tetrominos_keys.size()]

	spawn_piece()

func spawn_piece() -> void:
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
		fall_timer.stop()
		print("GAME OVER")
		game_over_triggered.emit()
		return
	
	# 3. On fait apparaître la pièce active sur le plateau
	piece.initialize(type_actuel, position_depart)
	draw_piece(true)
	
	# 4. On pioche la NOUVELLE pièce suivante pour le coup d'après
	var tetrominos_keys = piece.TETROMINOS.keys()
	next_piece_type = tetrominos_keys[randi() % tetrominos_keys.size()]
	
	# 5. On met à jour l'affichage de la preview
	update_next_piece_preview()

func update_next_piece_preview() -> void:
	next_piece_display.clear()
	
	var blocs_suivants = piece.TETROMINOS[next_piece_type]
	var preview_id = piece.TETROMINO_TILE_IDS[next_piece_type]
	
	var min_x = 999
	var min_y = 999
	var max_x = -999
	var max_y = -999
	
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
			next_piece_display.position = next_piece_layer_position
		_:
			# "T", "S", "Z", "J", "L" reçoivent le décalage de 8 pixels en X
			next_piece_display.position = next_piece_layer_position + Vector2(-8, 0)
	
	# Dessin final de la forme intacte
	for bloc in blocs_suivants:
		var pos_finale = bloc + offset_global
		next_piece_display.set_cell(pos_finale, 0, Vector2i(0, 0), preview_id)

func draw_piece(is_active: bool) -> void:
	for bloc in piece.blocs:
		var absolute_pos = piece.position_grille + bloc
		if is_active:
			board.set_cell_status(absolute_pos.x, absolute_pos.y, piece.alternative_id)
		else:
			board.set_cell_status(absolute_pos.x, absolute_pos.y, -1)

func _on_fall_timer_timeout() -> void:
	if game_over:
		return
	
	if not move_piece(Vector2i(0, 1)):
		lock_piece()

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
	
	var lines_cleared = await board.check_and_clear_lines()
	
	if lines_cleared > 0:
		# Ajouter les lignes au total
		lines_cleared_total += lines_cleared
		
		# Calculer le score selon le barème classique de Tetris multiplié par le niveau
		var points: int
		match lines_cleared:
			1:
				points = 100 * level
			2:
				points = 300 * level
			3:
				points = 500 * level
			4:
				points = 800 * level
			_:
				points = 0
		
		score += points
		
		# Calculer le niveau actuel
		var new_level = lines_cleared_total / 10 + 1
		if new_level > level:
			level = int(new_level)
			
			# Ajuster dynamiquement la vitesse du jeu
			fall_timer.wait_time = max(0.05, base_fall_time - (level - 1) * 0.05)
		
		print("Score: ", score, " | Lignes: ", lines_cleared_total, " | Niveau: ", level)
		
		# Émission des signaux pour l'UI
		score_changed.emit(score)
		level_changed.emit(level)
		lines_changed.emit(lines_cleared_total)
	
	spawn_piece()
