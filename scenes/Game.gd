extends Control

# ─────────────────────────────────────────────
#  Game.gd — CORRIGÉ
# ─────────────────────────────────────────────

const WIN_SCENE  := "res://scenes/WinScreen.tscn"
const MENU_SCENE := "res://scenes/MainMenu.tscn"

@onready var lbl_round:   Label         = $VBoxContainer/top_bar/lbl_round
@onready var lbl_player:  Label         = $VBoxContainer/top_bar/lbl_current_player
@onready var btn_menu:    Button        = $VBoxContainer/top_bar/btn_menu
@onready var score_panel                = $VBoxContainer/score_panel 
@onready var dartboard:   Control       = $VBoxContainer/dartboard
@onready var dart1:       Label         = $VBoxContainer/throw_panel/dart_row/dart1
@onready var dart2:       Label         = $VBoxContainer/throw_panel/dart_row/dart2
@onready var dart3:       Label         = $VBoxContainer/throw_panel/dart_row/dart3
@onready var lbl_bust:    Label         = $VBoxContainer/throw_panel/lbl_bust
@onready var btn_undo:    Button        = $VBoxContainer/throw_panel/HFlowContainer/btn_undo
@onready var btn_next:    Button        = $VBoxContainer/throw_panel/HFlowContainer/btn_next
@onready var btn_end_free: Button       = $VBox/ThrowPanel/BtnRow/btn_End_Free

var _darts: Array[Dictionary] = []
var _bust: bool = false

func _ready() -> void:
	if not dartboard.dart_thrown.is_connected(_on_dart_thrown):
		dartboard.dart_thrown.connect(_on_dart_thrown)
	
	btn_undo.pressed.connect(_on_undo)
	btn_next.pressed.connect(_on_next_turn)
	btn_menu.pressed.connect(func(): get_tree().change_scene_to_file(MENU_SCENE))

	if btn_end_free != null:
		btn_end_free.visible = (GameData.game_mode == GameData.GameMode.FREE_SCORE)
		if not btn_end_free.pressed.is_connected(_on_end_free):
			btn_end_free.pressed.connect(_on_end_free)

	dartboard.cricket_mode = (GameData.game_mode == GameData.GameMode.CRICKET)
	_start_turn()

func _on_dart_thrown(number: int, multiplier: int) -> void:
	if _darts.size() >= 3 or _bust:
		return

	if GameData.game_mode == GameData.GameMode.CRICKET:
		if number not in GameData.CRICKET_NUMBERS:
			_show_feedback("Hors jeu")
			return

	var label := _dart_to_label(number, multiplier)
	_darts.append({"number": number, "multiplier": multiplier, "label": label})

	if GameData.game_mode in [GameData.GameMode.MODE_301, GameData.GameMode.MODE_501]:
		var potential: int = GameData.get_current_player()["score"] - _turn_total()
		if potential < 0:
			_bust = true

	_refresh_throw_panel()
	btn_next.disabled = false

func _dart_to_label(number: int, multiplier: int) -> String:
	if number == 25:
		return "Bull" if multiplier == 2 else "25"
	match multiplier:
		2: return "D%d" % number
		3: return "T%d" % number
		_: return str(number)

func _turn_total() -> int:
	var total := 0
	for d in _darts:
		total += d["number"] * d["multiplier"]
	return total

func _on_undo() -> void:
	if _darts.is_empty():
		return
	_darts.pop_back()
	_bust = false
	_refresh_throw_panel()
	btn_next.disabled = _darts.is_empty()

func _on_next_turn() -> void:
	_apply_turn()

	if GameData.game_over:
		get_tree().change_scene_to_file(WIN_SCENE)
		return

	GameData.next_player()
	_darts.clear()
	_bust = false
	_start_turn()

func _on_end_free() -> void:
	_apply_free(GameData.get_current_player())
	GameData.game_over = true
	var best_score := -1
	for i in GameData.players.size():
		if GameData.players[i]["free_score"] > best_score:
			best_score = GameData.players[i]["free_score"]
			GameData.winner_index = i
	get_tree().change_scene_to_file(WIN_SCENE)

func _apply_turn() -> void:
	var player := GameData.get_current_player()
	match GameData.game_mode:
		GameData.GameMode.MODE_301, GameData.GameMode.MODE_501:
			_apply_301_501(player)
		GameData.GameMode.CRICKET:
			_apply_cricket(player)
		GameData.GameMode.FREE_SCORE:
			_apply_free(player)

func _apply_301_501(player: Dictionary) -> void:
	if _bust:
		player["history"].append({"darts": _darts.duplicate(), "bust": true})
		return

	var total     := _turn_total()
	var new_score: int = player["score"] - total

	if new_score < 0:
		player["history"].append({"darts": _darts.duplicate(), "bust": true})
		return

	player["score"] = new_score
	player["history"].append({"darts": _darts.duplicate(), "score_after": new_score})

	if new_score == 0:
		GameData.game_over    = true
		GameData.winner_index = GameData.current_player_index

func _apply_cricket(player: Dictionary) -> void:
	for d in _darts:
		var n: int = d["number"]
		var m: int = d["multiplier"]

		if n not in GameData.CRICKET_NUMBERS:
			continue

		var current_marks: int = player["cricket_marks"].get(n, 0)

		if current_marks >= 3:
			if not GameData.all_players_closed(n):
				player["cricket_score"] += n * m
			continue

		var to_open   := mini(m, 3 - current_marks)
		var scoring_m := m - to_open
		player["cricket_marks"][n] += to_open

		if player["cricket_marks"][n] >= 3 and scoring_m > 0:
			if not GameData.all_players_closed(n):
				player["cricket_score"] += n * scoring_m

	player["history"].append({"darts": _darts.duplicate()})

	if GameData.cricket_win(GameData.current_player_index):
		GameData.game_over    = true
		GameData.winner_index = GameData.current_player_index

func _apply_free(player: Dictionary) -> void:
	var total := _turn_total()
	player["free_score"] += total
	player["history"].append({"darts": _darts.duplicate(), "score_after": player["free_score"]})

func _start_turn() -> void:
	_refresh_throw_panel()
	_refresh_top_bar()

func _refresh_top_bar() -> void:
	lbl_round.text  = "Manche %d" % GameData.round_number
	lbl_player.text = "🎯  %s" % GameData.get_current_player()["name"]

func _refresh_throw_panel() -> void:
	var labels := [dart1, dart2, dart3]
	for i in 3:
		labels[i].text = _darts[i]["label"] if i < _darts.size() else "—"

	lbl_bust.visible  = _bust
	btn_undo.disabled = _darts.is_empty()

	if GameData.game_mode != GameData.GameMode.FREE_SCORE:
		btn_next.disabled = _darts.is_empty()

	_refresh_score_panel()

func _refresh_score_panel() -> void:
	var pending := 0
	if not _bust:
		pending = _turn_total()

	if score_panel != null and score_panel.has_method("refresh"):
		score_panel.refresh(
			GameData.players,
			GameData.current_player_index,
			GameData.game_mode,
			pending
		)

func _show_feedback(msg: String) -> void:
	lbl_bust.text    = msg
	lbl_bust.visible = true
	await get_tree().create_timer(1.2).timeout
	if is_inside_tree():
		lbl_bust.text    = "💥 BUST !"
		lbl_bust.visible = _bust
