extends Control

# ─────────────────────────────────────────────
#  WinScreen.gd
# ─────────────────────────────────────────────

const MENU_SCENE := "res://scenes/MainMenu.tscn"
const GAME_SCENE := "res://scenes/Game.tscn"

@onready var lbl_winner:       Label         = $VBoxContainer/lbl_winner
@onready var scores_container: VBoxContainer = $VBoxContainer/scores_container
@onready var btn_menu:         Button        = $VBoxContainer/HFlowContainer/btn_menu
@onready var btn_replay:       Button        = $VBoxContainer/HFlowContainer/btn_replay

# ─────────────────────────────────────────────
func _ready() -> void:
	btn_menu.pressed.connect(func():  get_tree().change_scene_to_file(MENU_SCENE))
	btn_replay.pressed.connect(_on_replay)

	_display_results()

# ─────────────────────────────────────────────
func _display_results() -> void:
	# ── Titre gagnant ────────────────────────
	if GameData.winner_index >= 0:
		var winner := GameData.players[GameData.winner_index]
		lbl_winner.text = "🏆  %s gagne !" % winner["name"]
	else:
		lbl_winner.text = "Partie terminée"

	# ── Tableau des scores ───────────────────
	for child in scores_container.get_children():
		child.queue_free()

	# Trier les joueurs selon le mode
	var sorted_players := GameData.players.duplicate()
	match GameData.game_mode:
		GameData.GameMode.MODE_301, GameData.GameMode.MODE_501:
			sorted_players.sort_custom(func(a, b): return a["score"] < b["score"])
		GameData.GameMode.CRICKET:
			sorted_players.sort_custom(func(a, b): return a["cricket_score"] > b["cricket_score"])
		GameData.GameMode.FREE_SCORE:
			sorted_players.sort_custom(func(a, b): return a["free_score"] > b["free_score"])

	for i in sorted_players.size():
		var p: Dictionary = sorted_players[i]
		var is_winner := (p["name"] == GameData.players[GameData.winner_index]["name"])

		var card := PanelContainer.new()
		card.theme_type_variation = &"ActivePanel" if is_winner else &"PanelContainer"
		var card_col := VBoxContainer.new()
		card.add_child(card_col)

		var row := HBoxContainer.new()
		card_col.add_child(row)

		# Rang
		var rank_lbl := Label.new()
		rank_lbl.text                 = "%d. " % (i + 1)
		rank_lbl.theme_type_variation = &"MutedLabel"
		rank_lbl.custom_minimum_size  = Vector2(30, 0)
		row.add_child(rank_lbl)

		# Nom
		var name_lbl := Label.new()
		name_lbl.text                  = p["name"]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if is_winner:
			name_lbl.theme_type_variation = &"AccentLabel"
		row.add_child(name_lbl)

		# Score
		var score_lbl := Label.new()
		score_lbl.theme_type_variation = &"ScoreLabel"
		score_lbl.add_theme_font_size_override("font_size", 16)
		match GameData.game_mode:
			GameData.GameMode.MODE_301, GameData.GameMode.MODE_501:
				score_lbl.text = "%d pts restants" % p["score"]
			GameData.GameMode.CRICKET:
				score_lbl.text = "%d pts" % p["cricket_score"]
			GameData.GameMode.FREE_SCORE:
				score_lbl.text = "%d pts" % p["free_score"]
		row.add_child(score_lbl)

		scores_container.add_child(card)

		# Ligne marques Cricket (sous la ligne principale)
		if GameData.game_mode == GameData.GameMode.CRICKET:
			var marks_lbl := Label.new()
			var str_parts: Array[String] = []
			for n in GameData.CRICKET_NUMBERS:
				str_parts.append("%d:%s" % [n, _marks_icon(p["cricket_marks"][n])])
			marks_lbl.text                 = "  ".join(str_parts)
			marks_lbl.theme_type_variation = &"MutedLabel"
			card_col.add_child(marks_lbl)

		# Stats : tours joués, moyenne par tour
		var history := p["history"] as Array
		if history.size() > 0:
			var total_pts := 0
			for turn in history:
				var turn_darts := turn.get("darts", []) as Array
				for d in turn_darts:
					total_pts += d["number"] * d["multiplier"]
			var avg_str := "%.1f pts/tour" % (float(total_pts) / history.size())
			var stat_lbl := Label.new()
			stat_lbl.text                 = "%s · %d tours" % [avg_str, history.size()]
			stat_lbl.theme_type_variation = &"MutedLabel"
			card_col.add_child(stat_lbl)

# ─────────────────────────────────────────────
func _marks_icon(marks: int) -> String:
	match clamp(marks, 0, 3):
		0: return "·"
		1: return "/"
		2: return "✕"
		3: return "●"
	return "·"

# ─────────────────────────────────────────────
func _on_replay() -> void:
	GameData.replay()
	get_tree().change_scene_to_file(GAME_SCENE)
