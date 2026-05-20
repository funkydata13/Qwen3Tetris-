extends CanvasLayer

@onready var score_label = $MarginContainer/VBoxContainer/ScoreLabel
@onready var lines_label = $MarginContainer/VBoxContainer/LinesLabel
@onready var level_label = $MarginContainer/VBoxContainer/LevelLabel
@onready var game_over_label = $MarginContainer/VBoxContainer/GameOverLabel

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	game_over_label.visible = false
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func update_score(p_score: int) -> void:
	score_label.text = "Score: " + str(p_score)

func update_lines(p_lines: int) -> void:
	lines_label.text = "Lignes: " + str(p_lines)

func update_level(p_level: int) -> void:
	level_label.text = "Niveau: " + str(p_level)

func display_game_over() -> void:
	game_over_label.visible = true
