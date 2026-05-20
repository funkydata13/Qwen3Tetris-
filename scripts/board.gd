extends Node2D

const COLS = 10
const ROWS = 20
const TILE_SIZE = 16

var grid: Array[Variant] = []

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
	# Utiliser une boucle while au lieu d'une boucle for pour gérer correctement
	# les lignes consécutives pleines
	var current_row = ROWS - 1
	var cleared_count: int = 0

	while current_row >= 0:
		# Vérifier si la ligne est pleine
		var line_full = true
		for col in range(COLS):
			if grid[col][current_row] == null:
				line_full = false
				break

		if line_full:
			# Supprimer la ligne et faire glisser les lignes au-dessus
			cleared_count += 1
			for r in range(current_row, 0, -1):
				# Copier chaque cellule de la ligne du dessus vers la ligne actuelle
				for col in range(COLS):
					grid[col][r] = grid[col][r - 1]
					if grid[col][r] != null:
						tile_map_layer.set_cell(Vector2i(col, r), 0, Vector2i(0, 0), grid[col][r])
					else:
						tile_map_layer.set_cell(Vector2i(col, r), -1)

			# Vider la ligne du haut
			for col in range(COLS):
				grid[col][0] = null
				tile_map_layer.set_cell(Vector2i(col, 0), -1)

			# Ne pas décrémenter current_row car la ligne qui vient de descendre
			# doit être réévaluée au prochain tour
		else:
			# Si la ligne n'est pas pleine, passer à la ligne au-dessus
			current_row -= 1

	return cleared_count

