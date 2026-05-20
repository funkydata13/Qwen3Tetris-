extends Node2D

const TETROMINOS = {
	"I": [Vector2i(-1,0), Vector2i(0,0), Vector2i(1,0), Vector2i(2,0)],
	"O": [Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(1,1)],
	"T": [Vector2i(-1,0), Vector2i(0,0), Vector2i(1,0), Vector2i(0,1)],
	"S": [Vector2i(0,0), Vector2i(1,0), Vector2i(-1,1), Vector2i(0,1)],
	"Z": [Vector2i(-1,0), Vector2i(0,0), Vector2i(0,1), Vector2i(1,1)],
	"J": [Vector2i(-1,0), Vector2i(0,0), Vector2i(1,0), Vector2i(1,1)],
	"L": [Vector2i(-1,0), Vector2i(0,0), Vector2i(1,0), Vector2i(-1,1)]
}

const TETROMINO_TILE_IDS = {
	"I": 1,
	"O": 2,
	"T": 3,
	"S": 4,
	"Z": 5,
	"J": 6,
	"L": 7
}

var type: String
var position_grille: Vector2i
var blocs: Array[Vector2i]
var alternative_id: int

func initialize(p_type: String, start_pos: Vector2i) -> void:
	type = p_type
	position_grille = start_pos
	blocs = []
	blocs.assign(TETROMINOS[p_type])
	alternative_id = TETROMINO_TILE_IDS[p_type]

func move(direction: Vector2i) -> void:
	position_grille += direction

func rotate_piece(clockwise: bool) -> void:
	var new_blocs: Array[Vector2i] = []
	
	for bloc in blocs:
		if clockwise:
			new_blocs.append(Vector2i(-bloc.y, bloc.x))
		else:
			new_blocs.append(Vector2i(bloc.y, -bloc.x))
	
	blocs = new_blocs

func get_next_move_positions(direction: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	
	for bloc in blocs:
		result.append(position_grille + direction + bloc)
	
	return result

func get_next_rotated_positions(clockwise: bool) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	
	for bloc in blocs:
		var rotated_bloc: Vector2i
		if clockwise:
			rotated_bloc = Vector2i(-bloc.y, bloc.x)
		else:
			rotated_bloc = Vector2i(bloc.y, -bloc.x)
		result.append(position_grille + rotated_bloc)
	
	return result
