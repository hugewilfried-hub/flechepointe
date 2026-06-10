extends Control

# ─────────────────────────────────────────────
#  MainMenu.gd
# ─────────────────────────────────────────────

const GAME_SCENE := "res://scenes/Game.tscn"

@onready var btn_301:           Button        = $VBoxContainer/mode_box/btn_301
@onready var btn_501:           Button        = $VBoxContainer/mode_box/btn_501
@onready var btn_cricket:       Button        = $VBoxContainer/mode_box/bnt_cricket
@onready var btn_free:          Button        = $VBoxContainer/mode_box/bnt_free
@onready var btn_minus:         Button        = $VBoxContainer/joueur_row/btn_minus
@onready var btn_plus:          Button        = $VBoxContainer/joueur_row/btn_plus
@onready var lbl_count:         Label         = $VBoxContainer/joueur_row/lbl_count
@onready var names_container:   VBoxContainer = $VBoxContainer/VBoxContainer
@onready var btn_start:         Button        = $VBoxContainer/btn_start

var _mode: GameData.GameMode = GameData.GameMode.MODE_501
var _player_count: int = 2

const MIN_PLAYERS := 2
const MAX_PLAYERS := 8

# ─────────────────────────────────────────────
func _ready() -> void:
	btn_301.pressed.connect(func(): _set_mode(GameData.GameMode.MODE_301))
	btn_501.pressed.connect(func(): _set_mode(GameData.GameMode.MODE_501))
	btn_cricket.pressed.connect(func(): _set_mode(GameData.GameMode.CRICKET))
	btn_free.pressed.connect(func(): _set_mode(GameData.GameMode.FREE_SCORE))

	btn_minus.pressed.connect(func(): _change_count(-1))
	btn_plus.pressed.connect(func():  _change_count(+1))
	btn_start.pressed.connect(_on_start)

	# Pré-remplir si on revient du WinScreen (rejouer)
	if GameData.player_names.size() >= 2:
		_player_count = GameData.player_names.size()
		_mode         = GameData.game_mode

	_rebuild_names()
	_refresh_mode_buttons()
	_refresh_count_label()

# ─────────────────────────────────────────────
#  Mode de jeu
# ─────────────────────────────────────────────
func _set_mode(mode: GameData.GameMode) -> void:
	_mode = mode
	_refresh_mode_buttons()

func _refresh_mode_buttons() -> void:
	var selected_color := Color(0.20, 0.55, 0.90)
	var normal_color   := Color(0.22, 0.22, 0.22)
	for btn in [btn_301, btn_501, btn_cricket, btn_free]:
		btn.add_theme_color_override("normal", normal_color)

	match _mode:
		GameData.GameMode.MODE_301:     btn_301.add_theme_color_override("normal", selected_color)
		GameData.GameMode.MODE_501:     btn_501.add_theme_color_override("normal", selected_color)
		GameData.GameMode.CRICKET:      btn_cricket.add_theme_color_override("normal", selected_color)
		GameData.GameMode.FREE_SCORE:   btn_free.add_theme_color_override("normal", selected_color)

# ─────────────────────────────────────────────
#  Nombre de joueurs
# ─────────────────────────────────────────────
func _change_count(delta: int) -> void:
	_player_count = clamp(_player_count + delta, MIN_PLAYERS, MAX_PLAYERS)
	_rebuild_names()
	_refresh_count_label()

func _refresh_count_label() -> void:
	lbl_count.text = str(_player_count)
	btn_minus.disabled = (_player_count <= MIN_PLAYERS)
	btn_plus.disabled  = (_player_count >= MAX_PLAYERS)

func _rebuild_names() -> void:
	# Supprimer les anciens champs
	for child in names_container.get_children():
		child.queue_free()

	# Créer un LineEdit par joueur
	for i in _player_count:
		var row := HBoxContainer.new()

		var lbl := Label.new()
		lbl.text             = "J%d" % (i + 1)
		lbl.custom_minimum_size = Vector2(28, 0)
		row.add_child(lbl)

		var edit := LineEdit.new()
		edit.name            = "Player%d" % i
		edit.placeholder_text = "Joueur %d" % (i + 1)
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Pré-remplir si on rejoue
		if i < GameData.player_names.size():
			edit.text = GameData.player_names[i]

		row.add_child(edit)
		names_container.add_child(row)

# ─────────────────────────────────────────────
#  Démarrage
# ─────────────────────────────────────────────
func _on_start() -> void:
	var names: Array[String] = []
	for i in _player_count:
		var row  := names_container.get_child(i)
		var edit := row.get_node("Player%d" % i) as LineEdit
		var n    := edit.text.strip_edges()
		names.append(n if n != "" else "Joueur %d" % (i + 1))

	GameData.setup_game(_mode, names)
	get_tree().change_scene_to_file(GAME_SCENE)
