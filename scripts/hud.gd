extends CanvasLayer

@onready var score_label = %ScoreLabel
@onready var lines_label = %LinesLabel
@onready var level_label = %LevelLabel
@onready var game_over_label = %GameOverLabel

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	game_over_label.visible = false
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func update_score(p_score: int) -> void:
	score_label.text = str(p_score)

func update_lines(p_lines: int) -> void:
	lines_label.text = str(p_lines)

func update_level(p_level: int) -> void:
	level_label.text = str(p_level)

func display_game_over() -> void:
	game_over_label.visible = true
