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

	start_new_game()

func start_new_game() -> void:
	board.clear_grid()
	game_over = false
	score = 0
	lines_cleared_total = 0
	level = 1
	fall_timer.wait_time = base_fall_time
	
	# Émission des signaux pour l'UI
	emit_signal("score_changed", score)
	emit_signal("level_changed", level)
	emit_signal("lines_changed", lines_cleared_total)
	
	spawn_piece()

func spawn_piece() -> void:
	var tetrominos_keys = piece.TETROMINOS.keys()
	var type_aleatoire = tetrominos_keys[randi() % tetrominos_keys.size()]
	var position_depart = Vector2i(4, 0)
	
	# Vérifier si les positions de départ sont libres en utilisant directement les blocs
	var positions_libres = true
	
	for bloc in piece.TETROMINOS[type_aleatoire]:
		var absolute_pos = position_depart + bloc
		if not board.is_cell_empty(absolute_pos.x, absolute_pos.y):
			positions_libres = false
			break
	
	if not positions_libres:
		game_over = true
		fall_timer.stop()
		print("GAME OVER")
		emit_signal("game_over_triggered")
		return
	
	piece.initialize(type_aleatoire, position_depart)
	draw_piece(true)
	
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

	var lines_cleared = board.check_and_clear_lines()
	
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
		emit_signal("score_changed", score)
		emit_signal("level_changed", level)
		emit_signal("lines_changed", lines_cleared_total)
	
	spawn_piece()

func _input(event: InputEvent) -> void:
	if game_over:
		return
	
	if Input.is_action_just_pressed("ui_left"):
		move_piece(Vector2i(-1, 0))
	
	elif Input.is_action_just_pressed("ui_right"):
		move_piece(Vector2i(1, 0))
	
	elif Input.is_action_just_pressed("ui_down"):
		if not move_piece(Vector2i(0, 1)):
			lock_piece()
	
	elif Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_up"):
		# Gérer la rotation
		var future_positions = piece.get_next_rotated_positions(true)
		
		# Vérifier si toutes les cellules futures sont vides
		var positions_libres = true
		for pos in future_positions:
			# Ignorer les cellules qui appartiennent à la pièce elle-même pour éviter l'auto-collision
			var is_piece_cell = false
			for bloc in piece.blocs:
				if bloc + piece.position_grille == pos:
					is_piece_cell = true
					break
			
			if not is_piece_cell and not board.is_cell_empty(pos.x, pos.y):
				positions_libres = false
				break
		
		if positions_libres:
			draw_piece(false)
			piece.rotate_piece(true)
			draw_piece(true)
