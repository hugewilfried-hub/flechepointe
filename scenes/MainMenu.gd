extends Control

# ─────────────────────────────────────────────
#  MainMenu.gd
#  Écran de configuration avant de lancer une partie : choix du mode,
#  du nombre de joueurs et de leurs noms. Ne touche à GameData qu'au
#  moment de démarrer (_on_start) : tant qu'on est sur cet écran, tout
#  est stocké dans des variables locales (_mode, _player_count).
# ─────────────────────────────────────────────

const GAME_SCENE := "res://scenes/Game.tscn"

@onready var load_confirm:      ConfirmationDialog = $load_confirm
@onready var saves_panel:       PanelContainer = $VBoxContainer/saves_panel
@onready var saves_list:        VBoxContainer = $VBoxContainer/saves_panel/saves_col/saves_scroll/saves_list
@onready var btn_301:           Button        = $VBoxContainer/mode_box/btn_301
@onready var btn_501:           Button        = $VBoxContainer/mode_box/btn_501
@onready var btn_cricket:       Button        = $VBoxContainer/mode_box/bnt_cricket
@onready var btn_free:          Button        = $VBoxContainer/mode_box/bnt_free
@onready var double_out_row:    HFlowContainer = $VBoxContainer/double_out_row
@onready var chk_double_out:    CheckButton   = $VBoxContainer/double_out_row/chk_double_out
@onready var btn_minus:         Button        = $VBoxContainer/joueur_row/btn_minus
@onready var btn_plus:          Button        = $VBoxContainer/joueur_row/btn_plus
@onready var lbl_count:         Label         = $VBoxContainer/joueur_row/lbl_count
@onready var names_container:   VBoxContainer = $VBoxContainer/VBoxContainer
@onready var btn_start:         Button        = $VBoxContainer/btn_start

var _mode: GameData.GameMode = GameData.GameMode.MODE_501
var _player_count: int = 2
var _double_out: bool = false

# Id de la sauvegarde en attente de confirmation dans load_confirm
# (vide tant qu'aucune demande de chargement n'est en cours).
var _pending_load_id: String = ""

const MIN_PLAYERS := 2
const MAX_PLAYERS := 8

# ─────────────────────────────────────────────
func _ready() -> void:
	SafeArea.apply_bottom_spacer($VBoxContainer)

	load_confirm.get_ok_button().text     = "Charger"
	load_confirm.get_cancel_button().text = "Annuler"
	load_confirm.confirmed.connect(_on_load_confirmed)

	btn_301.pressed.connect(func(): _set_mode(GameData.GameMode.MODE_301))
	btn_501.pressed.connect(func(): _set_mode(GameData.GameMode.MODE_501))
	btn_cricket.pressed.connect(func(): _set_mode(GameData.GameMode.CRICKET))
	btn_free.pressed.connect(func(): _set_mode(GameData.GameMode.FREE_SCORE))

	btn_minus.pressed.connect(func(): _change_count(-1))
	btn_plus.pressed.connect(func():  _change_count(+1))
	btn_start.pressed.connect(_on_start)
	chk_double_out.toggled.connect(_on_double_out_toggled)

	# Pré-remplir si on revient du WinScreen (rejouer)
	if GameData.player_names.size() >= 2:
		_player_count = GameData.player_names.size()
		_mode         = GameData.game_mode
		_double_out   = GameData.double_out

	chk_double_out.button_pressed = _double_out
	_refresh_double_out_style()
	_rebuild_names()
	_refresh_mode_buttons()
	_refresh_count_label()
	_refresh_saves_list()

# ─────────────────────────────────────────────
#  Parties sauvegardées
# ─────────────────────────────────────────────
## Reconstruit la liste des parties reprenables (masquée s'il n'y en a
## aucune). Appelée à l'arrivée sur le menu, et après une suppression.
func _refresh_saves_list() -> void:
	for child in saves_list.get_children():
		child.queue_free()

	var saves: Array = SaveManager.list_saves()
	saves_panel.visible = not saves.is_empty()

	for save in saves:
		var id: String = save["id"]
		var row := HBoxContainer.new()

		var btn_load := Button.new()
		btn_load.text = save["label"]
		btn_load.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_load.pressed.connect(func(): _on_request_load(id))
		row.add_child(btn_load)

		var btn_delete := Button.new()
		btn_delete.text = "🗑"
		btn_delete.pressed.connect(func(): _on_delete_save(id))
		row.add_child(btn_delete)

		saves_list.add_child(row)

## Ouvre la boîte de dialogue de récapitulatif pour la sauvegarde `id` :
## le chargement effectif n'a lieu que si le joueur confirme (voir
## _on_load_confirmed), "Annuler" revient simplement au menu tel quel.
func _on_request_load(id: String) -> void:
	var data: Variant = SaveManager.read_save(id)
	if data == null:
		return
	_pending_load_id      = id
	load_confirm.dialog_text = _build_save_summary(data)
	load_confirm.popup_centered()

## Construit le texte récapitulatif : mode, manche, et le point de
## chaque joueur (formaté comme sur ScorePanel/WinScreen selon le mode).
func _build_save_summary(data: Dictionary) -> String:
	var mode_names := {
		GameData.GameMode.MODE_301:   "301",
		GameData.GameMode.MODE_501:   "501",
		GameData.GameMode.CRICKET:    "Cricket",
		GameData.GameMode.FREE_SCORE: "Score libre",
	}
	var mode: int = int(data.get("game_mode", GameData.GameMode.MODE_501))

	var lines: Array[String] = []
	lines.append("%s — Manche %d" % [mode_names.get(mode, "?"), int(data.get("round_number", 1))])
	lines.append("")

	for raw_p in data.get("players", []) as Array:
		var p: Dictionary = raw_p
		var score_text: String
		match mode:
			GameData.GameMode.MODE_301, GameData.GameMode.MODE_501:
				score_text = "%d restant" % int(p.get("score", 0))
			GameData.GameMode.CRICKET:
				score_text = "%d pts" % int(p.get("cricket_score", 0))
			GameData.GameMode.FREE_SCORE:
				score_text = "%d pts" % int(p.get("free_score", 0))
			_:
				score_text = ""
		lines.append("%s : %s" % [p.get("name", "?"), score_text])

	return "\n".join(lines)

## Chargement confirmé (bouton "Charger" de load_confirm) : bascule
## directement sur l'écran de jeu (contourne _on_start, la partie n'est
## pas "neuve", pas besoin de repasser par la config mode/joueurs).
func _on_load_confirmed() -> void:
	print("[MainMenu] Chargement confirmé : %s" % _pending_load_id)
	if SaveManager.load_game(_pending_load_id):
		get_tree().change_scene_to_file(GAME_SCENE)

func _on_delete_save(id: String) -> void:
	print("[MainMenu] Suppression de la sauvegarde : %s" % id)
	SaveManager.delete_save(id)
	_refresh_saves_list()

# ─────────────────────────────────────────────
#  Mode de jeu
# ─────────────────────────────────────────────
func _set_mode(mode: GameData.GameMode) -> void:
	print("[MainMenu] Mode sélectionné : %s" % GameData.GameMode.keys()[mode])
	_mode = mode
	_refresh_mode_buttons()

func _refresh_mode_buttons() -> void:
	for btn in [btn_301, btn_501, btn_cricket, btn_free]:
		btn.theme_type_variation = &"SegButton"

	match _mode:
		GameData.GameMode.MODE_301:     btn_301.theme_type_variation     = &"SegButtonSelected"
		GameData.GameMode.MODE_501:     btn_501.theme_type_variation     = &"SegButtonSelected"
		GameData.GameMode.CRICKET:      btn_cricket.theme_type_variation = &"SegButtonSelected"
		GameData.GameMode.FREE_SCORE:   btn_free.theme_type_variation    = &"SegButtonSelected"

	# La sortie double n'a de sens qu'en 301/501 (compte à rebours).
	double_out_row.visible = (_mode == GameData.GameMode.MODE_301 or _mode == GameData.GameMode.MODE_501)

# ─────────────────────────────────────────────
#  Nombre de joueurs
# ─────────────────────────────────────────────
## +1/-1 joueur, borné entre MIN_PLAYERS et MAX_PLAYERS. Reconstruit
## aussitôt les champs de nom (_rebuild_names) pour ajouter/retirer une ligne.
func _change_count(delta: int) -> void:
	_player_count = clamp(_player_count + delta, MIN_PLAYERS, MAX_PLAYERS)
	print("[MainMenu] Nombre de joueurs -> %d" % _player_count)
	_rebuild_names()
	_refresh_count_label()

func _on_double_out_toggled(pressed: bool) -> void:
	print("[MainMenu] Sortie double -> %s" % pressed)
	_double_out = pressed
	_refresh_double_out_style()

## Switch basique : teinte le CheckButton natif en vert quand activé,
## en rouge quand désactivé. Le fond (StyleBox) est rendu transparent
## pour éviter le carré coloré autour de l'icône.
func _refresh_double_out_style() -> void:
	var empty_style := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		chk_double_out.add_theme_stylebox_override(state, empty_style)
	chk_double_out.modulate = Color(0.35, 0.85, 0.45) if _double_out else Color(0.9, 0.35, 0.35)

func _refresh_count_label() -> void:
	lbl_count.text = str(_player_count)
	btn_minus.disabled = (_player_count <= MIN_PLAYERS)
	btn_plus.disabled  = (_player_count >= MAX_PLAYERS)

## Reconstruit la liste de champs "Joueur X" à partir de _player_count.
## Comme pour ScorePanel, on détruit tout et on recrée : plus simple à
## maintenir que d'ajouter/retirer une ligne au bon endroit.
func _rebuild_names() -> void:
	# Supprimer les anciens champs
	for child in names_container.get_children():
		child.queue_free()

	# Créer un LineEdit par joueur
	for i in _player_count:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER

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
## Lit le texte de chaque LineEdit (nom vide -> "Joueur N" par défaut),
## initialise la partie dans GameData, puis change de scène vers Game.tscn.
## C'est le SEUL endroit où MainMenu écrit dans GameData.
func _on_start() -> void:
	var names: Array[String] = []
	for i in _player_count:
		var row  := names_container.get_child(i)
		var edit := row.get_node("Player%d" % i) as LineEdit
		var n    := edit.text.strip_edges()
		names.append(n if n != "" else "Joueur %d" % (i + 1))

	print("[MainMenu] Démarrage de la partie : mode=%s, joueurs=%s, sortie double=%s" % [GameData.GameMode.keys()[_mode], names, _double_out])
	GameData.double_out = _double_out
	GameData.setup_game(_mode, names)
	get_tree().change_scene_to_file(GAME_SCENE)
