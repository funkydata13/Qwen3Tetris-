extends Node2D

const COLS = 10
const ROWS = 20
const TILE_SIZE = 16

var grid: Array[Variant] = []
var is_animating: bool = false

@onready var tile_map_layer = $TileMapLayer

func _ready() -> void:
	# Initialise la grille avec des valeurs nulles
	grid.resize(COLS)
	for i in range(COLS):
		grid[i] = []
		grid[i].resize(ROWS)
		for j in range(ROWS):
			grid[i][j] = null

func is_cell_empty(col: int, row: int) -> bool:
	# Vérifie si les coordonnées sont dans les limites de la grille
	if col < 0 or col >= COLS or row < 0 or row >= ROWS:
		return false
	
	# Vérifie si la cellule est vide (vaut null)
	return grid[col][row] == null

func set_cell_status(col: int, row: int, tile_id: int) -> void:
	if col < 0 or col >= COLS or row < 0 or row >= ROWS:
		return
	
	var coords = Vector2i(col, row)
	
	if tile_id != -1:
		grid[col][row] = tile_id
		tile_map_layer.set_cell(coords, 0, Vector2i(0, 0), tile_id)
	else:
		grid[col][row] = null
		tile_map_layer.set_cell(coords, -1)

func clear_grid() -> void:
	# Réinitialise toutes les valeurs de grid à null
	for i in range(COLS):
		for j in range(ROWS):
			grid[i][j] = null
	
	# Efface toutes les tuiles de la TileMapLayer
	tile_map_layer.clear()

func check_and_clear_lines() -> int:
	# Si on est déjà en train d'animer, on ne fait rien
	if is_animating:
		return 0
	
	is_animating = true # Indique que nous commençons l'animation
	
	var cleared_count: int = 0
	
	# Collecte les lignes pleines
	var full_lines = []
	for row in range(ROWS):
		var line_full = true
		for col in range(COLS):
			if grid[col][row] == null:
				line_full = false
				break
		if line_full:
			full_lines.append(row)
	
	# Si aucune ligne n'est pleine, on sort
	if full_lines.size() == 0:
		is_animating = false
		return 0

	if full_lines.size() >= 4:
		AudioManager.play_sfx("tetris")
	else:
		AudioManager.play_sfx("line_clear")
	
	# Trier les lignes pleines par ordre croissant pour le traitement
	full_lines.sort()
	
	# Appliquer l'effet de flash sur les lignes pleines
	var flash_interval = 0.06

	# Flash 1 - On passe les blocs en blanc éclatant (Alternative ID 8)
	for row in full_lines:
		for col in range(COLS):
			var coords = Vector2i(col, row)
			if grid[col][row] != null:
				tile_map_layer.set_cell(coords, 0, Vector2i(0, 0), 8)

	await get_tree().create_timer(flash_interval).timeout

	# Flash 2 - On restaure la couleur d'origine (tile_id)
	for row in full_lines:
		for col in range(COLS):
			var coords = Vector2i(col, row)
			var tile_id = grid[col][row]
			if tile_id != null:
				tile_map_layer.set_cell(coords, 0, Vector2i(0, 0), tile_id)

	await get_tree().create_timer(flash_interval).timeout

	# Flash 3 - Deuxième coup de blanc
	for row in full_lines:
		for col in range(COLS):
			var coords = Vector2i(col, row)
			if grid[col][row] != null:
				tile_map_layer.set_cell(coords, 0, Vector2i(0, 0), 8)

	await get_tree().create_timer(flash_interval).timeout

	# Flash 4 - Retour aux couleurs une fraction de seconde avant la disparition
	for row in full_lines:
		for col in range(COLS):
			var coords = Vector2i(col, row)
			var tile_id = grid[col][row]
			if tile_id != null:
				tile_map_layer.set_cell(coords, 0, Vector2i(0, 0), tile_id)
				
	await get_tree().create_timer(flash_interval).timeout
		
	# Supprimer les lignes
	for row in full_lines:
		for col in range(COLS):
			grid[col][row] = null
			tile_map_layer.set_cell(Vector2i(col, row), -1)
	
	# Algorithme de reconstruction du bas vers le haut pour éviter les "double shifts"
	var write_row = ROWS - 1
	
	# Parcourir l'ancienne grille du bas vers le haut
	for read_row in range(ROWS - 1, -1, -1):
		# Si la ligne n'est pas pleine (donc non supprimée)
		if not read_row in full_lines:
			# Copier toutes les colonnes de la ligne lue vers la ligne d'écriture
			for col in range(COLS):
				grid[col][write_row] = grid[col][read_row]
				if grid[col][write_row] != null:
					tile_map_layer.set_cell(Vector2i(col, write_row), 0, Vector2i(0, 0), grid[col][write_row])
				else:
					tile_map_layer.set_cell(Vector2i(col, write_row), -1)
			
			# Décrémenter le pointeur d'écriture
			write_row -= 1
	
	# Remplir le reste du haut avec des cases vides
	for row in range(write_row, -1, -1):
		for col in range(COLS):
			grid[col][row] = null
			tile_map_layer.set_cell(Vector2i(col, row), -1)
	
	is_animating = false # Fin de l'animation
	
	return full_lines.size()